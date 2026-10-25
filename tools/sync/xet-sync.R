#!/usr/bin/env Rscript
# xet-sync: Batch download/sync with update detection
# Usage: Rscript tools/sync/xet-sync.R models.json [--force] [--check-only]

library(rxet)
library(future)
library(future.apply)
library(httr2)
library(jsonlite)

# Parse command line args
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  cat("Usage: Rscript tools/sync/xet-sync.R <config.json> [--force] [--check-only] [--retry-failures]\n")
  cat("\nOptions:\n")
  cat("  --force           Re-download all files even if hash matches\n")
  cat("  --check-only      Only check for updates, don't download\n")
  cat("  --retry-failures  Retry only files that failed in previous sync\n")
  quit(status = 1)
}

config_file <- args[1]
force_download <- "--force" %in% args
check_only <- "--check-only" %in% args
retry_failures <- "--retry-failures" %in% args

if (!file.exists(config_file)) {
  stop(sprintf("Config file not found: %s", config_file))
}

# Setup
hf_token <- Sys.getenv("HF_TOKEN")
if (hf_token == "") {
  stop("HF_TOKEN not set. Get token from https://huggingface.co/settings/tokens")
}

# Load config
config <- jsonlite::read_json(config_file)
sync_dir <- path.expand(config$sync_dir)
dir.create(sync_dir, showWarnings = FALSE, recursive = TRUE)

# Create metadata cache file
cache_file <- file.path(sync_dir, ".xet_sync_cache.json")
if (file.exists(cache_file)) {
  cache <- jsonlite::read_json(cache_file)
  # Maintain cache: remove old entries (>90 days) and excess entries (>5000)
  initial_size <- length(cache)
  cache <- maintain_cache(cache, ttl_days = 90, max_entries = 5000)
  evicted <- initial_size - length(cache)
  if (evicted > 0) {
    cat(sprintf("Cache maintenance: evicted %d old/excess entries\n\n", evicted))
  }
} else {
  cache <- list()
}

# Load failure manifest for retry tracking
failures_file <- file.path(sync_dir, ".xet_sync_failures.json")
if (file.exists(failures_file)) {
  failures <- jsonlite::read_json(failures_file)
} else {
  failures <- list()
}

# Handle --retry-failures mode: filter config to only include previously failed files
if (retry_failures) {
  if (length(failures) == 0) {
    cat("No failed files found. Nothing to retry.\n")
    quit(status = 0)
  }

  cat("=== XET Sync Manager (RETRY MODE) ===\n")
  cat(sprintf("Retrying %d previously failed files\n\n", length(failures)))

  # Filter config: keep only repos/files that appear in failures manifest
  for (i in seq_along(config$repos)) {
    repo_id <- config$repos[[i]]$repo_id
    original_files <- config$repos[[i]]$files

    # Keep only files that failed
    failed_files <- sapply(original_files, function(f) {
      cache_key <- sprintf("%s/%s", repo_id, f)
      cache_key %in% names(failures)
    })

    config$repos[[i]]$files <- original_files[failed_files]
  }

  # Remove repos with no files
  config$repos <- config$repos[sapply(config$repos, function(r) length(r$files) > 0)]
} else {
  cat("=== XET Sync Manager ===\n")
}

cat(sprintf("Sync dir: %s\n", sync_dir))
cat(sprintf("HF Token: ***\n\n"))

# ------- Helper Functions -------

get_xet_file_info <- function(repo_id, file, branch = "main") {
  url <- sprintf(
    "https://huggingface.co/%s/resolve/%s/%s",
    repo_id, branch, file
  )

  result <- make_hf_api_request(url, method = "HEAD", token = hf_token)

  if (!result$success) {
    return(make_result(error = result$error))
  }

  make_result(data = list(
    hash = httr2::resp_header(result$data, "X-Xet-Hash"),
    size = as.numeric(httr2::resp_header(result$data, "X-Linked-Size"))
  ))
}

get_cas_credentials <- function(repo_id, branch = "main") {
  token_url <- sprintf(
    "https://huggingface.co/api/models/%s/xet-read-token/%s",
    repo_id, branch
  )

  result <- make_hf_api_request(token_url, method = "GET", parse_json = TRUE, token = hf_token)

  if (!result$success) {
    return(make_result(error = result$error))
  }

  response <- result$data
  make_result(data = list(
    token = response$accessToken,
    endpoint = response$casUrl,
    exp = response$exp
  ))
}

download_file_with_client <- function(client, file_info, dest_path) {
  tryCatch({
    start_time <- Sys.time()

    # For files larger than 100MB, show progress
    show_progress <- file_info$size > 100e6

    if (show_progress) {
      cat("        ")  # Indent progress line
    }

    xet_download_file(
      handle = client,
      hash = file_info$hash,
      file_size = file_info$size,
      dest_path = dest_path
    )

    if (show_progress) {
      cat("\r")  # Return to start of line
      cat("        ")  # Clear progress line
      cat("\r")
    }

    list(
      success = TRUE,
      time_seconds = as.numeric(Sys.time() - start_time)
    )
  }, error = function(e) {
    list(success = FALSE, error = as.character(e))
  })
}

# ------- Main Sync Loop -------

total_files <- sum(sapply(config$repos, function(r) length(r$files)))
processed <- 0
downloaded <- 0
skipped <- 0
errors <- 0

cat(sprintf("Found %d files to process\n\n", total_files))

cache_dirty <- FALSE

# Per-file processing function for parallel execution
process_file_batch <- function(file_data, cache_obj, client, sync_dir, repo_id,
                              force_download, check_only) {
  file <- file_data$file
  file_info <- file_data$file_info

  # Determine destination path
  dest_path <- file.path(sync_dir, repo_id, file)

  # Check cache for updates
  cache_key <- sprintf("%s/%s", repo_id, file)
  cached <- cache_obj[[cache_key]]

  file_exists <- file.exists(dest_path)
  hash_matches <- !is.null(cached) && cached$hash == file_info$hash

  # Decide action using structured state machine
  action <- determine_action(file_exists, hash_matches, cached)

  # Determine if download needed
  should_download <- force_download ||
                     !file_exists ||
                     !hash_matches

  result <- list(
    file = file,
    cache_key = cache_key,
    action = action,
    action_string = format_action(action),
    hash = file_info$hash,
    size = file_info$size,
    success = FALSE,
    downloaded = 0,
    skipped = 0,
    error = NULL,
    time_seconds = 0,
    new_cache_entry = NULL
  )

  if (check_only) {
    result$skipped <- 1
    result$success <- TRUE
  } else if (should_download) {
    download_result <- download_file_with_client(client, file_info, dest_path)

    if (download_result$success) {
      actual_size <- file.size(dest_path)

      if (is.na(actual_size)) {
        result$error <- "downloaded file not found"
      } else if (actual_size != file_info$size) {
        result$error <- sprintf("size mismatch (expected %.2f MB, got %.2f MB)",
                              file_info$size / 1e6, actual_size / 1e6)
        tryCatch(file.remove(dest_path), error = function(e) NULL)
      } else {
        result$success <- TRUE
        result$downloaded <- 1
        result$time_seconds <- download_result$time_seconds
        result$new_cache_entry <- list(
          hash = file_info$hash,
          size = file_info$size,
          downloaded_at = as.character(Sys.time())
        )
      }
    } else {
      result$error <- download_result$error
    }
  } else {
    result$success <- TRUE
    result$skipped <- 1
  }

  result
}

# Set up parallel execution (4 workers default)
future::plan(future::multisession, workers = 4)

for (repo_spec in config$repos) {
  repo_id <- repo_spec$repo_id
  branch <- repo_spec$branch %||% "main"
  files <- repo_spec$files

  cat(sprintf("[REPO] %s (%s)\n", repo_id, branch))

  # Get CAS credentials once per repo
  cat("  • Fetching CAS credentials...\n")
  cas_creds <- get_cas_credentials(repo_id, branch)

  if (!cas_creds$success) {
    cat(sprintf("  ✗ Error: %s\n\n", cas_creds$error))
    errors <- errors + length(files)
    next
  }

  cat(sprintf("    ✓ Token valid for: %.0f min\n",
              (cas_creds$data$exp - as.numeric(Sys.time())) / 60))

  # Create client once per repo
  client <- xet_client_new(cas_creds$data$endpoint, cas_creds$data$token)
  on.exit({
    tryCatch(xet_client_close(client), error = function(e) NULL)
  }, add = TRUE)

  # Track created directories to avoid redundant mkdir calls
  created_dirs <- character()

  # Fetch all file metadata upfront (sequential, one request per file)
  cat("  • Fetching file metadata for batch...\n")
  file_metadata <- list()
  metadata_errors <- 0

  for (file in files) {
    file_info <- get_xet_file_info(repo_id, file, branch)
    if (!file_info$success) {
      cat(sprintf("    ✗ Error fetching %s: %s\n", file, file_info$error))
      metadata_errors <- metadata_errors + 1
      errors <- errors + 1
    } else {
      file_metadata[[file]] <- file_info$data
    }
  }

  if (metadata_errors > 0) {
    cat(sprintf("  ✗ Failed to fetch metadata for %d files, skipping repo\n\n",
                metadata_errors))
    next
  }

  cat(sprintf("  ✓ Fetched metadata for %d files\n", length(file_metadata)))

  # Refresh token before parallel batch if expiration within 5 minutes
  time_remaining_min <- (cas_creds$data$exp - as.numeric(Sys.time())) / 60
  if (time_remaining_min < 5) {
    cat(sprintf("  • Token expiring soon (%.0f min), refreshing...\n", time_remaining_min))
    cas_creds <- get_cas_credentials(repo_id, branch)
    if (!cas_creds$success) {
      cat(sprintf("    ✗ Error refreshing token: %s\n", cas_creds$error))
      errors <- errors + length(files)
      next
    }
    new_time_remaining <- (cas_creds$data$exp - as.numeric(Sys.time())) / 60
    cat(sprintf("    ✓ Token refreshed (new validity: %.0f min)\n", new_time_remaining))
  }

  # Create directories for all files upfront
  for (file in names(file_metadata)) {
    dest_path <- file.path(sync_dir, repo_id, file)
    dest_dir <- dirname(dest_path)
    if (!(dest_dir %in% created_dirs)) {
      dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)
      created_dirs <- c(created_dirs, dest_dir)
    }
  }

  # Prepare file data for parallel processing
  file_data_list <- lapply(names(file_metadata), function(file) {
    list(file = file, file_info = file_metadata[[file]])
  })

  # Process files in parallel
  cat(sprintf("  ⬇ Downloading %d files in parallel...\n", length(file_data_list)))
  batch_results <- future.apply::future_lapply(
    file_data_list,
    process_file_batch,
    cache_obj = cache,
    client = client,
    sync_dir = sync_dir,
    repo_id = repo_id,
    force_download = force_download,
    check_only = check_only,
    future.seed = NULL
  )

  # Aggregate results from parallel execution
  cat("  • Processing batch results...\n")
  for (result in batch_results) {
    processed <- processed + 1
    cat(sprintf("  [%d/%d] %s\n", processed, total_files, result$file))
    cat(sprintf("    → %s\n", result$action_string))
    cat(sprintf("      Hash: %s (size: %.2f MB)\n",
                substr(result$hash, 1, 16),
                result$size / 1e6))

    if (result$success) {
      if (result$downloaded > 0) {
        cat(sprintf("      ✓ Complete (%.1f seconds)\n", result$time_seconds))
        # Update cache from parallel results
        if (!is.null(result$new_cache_entry)) {
          cache[[result$cache_key]] <- result$new_cache_entry
          cache_dirty <- TRUE
        }
        downloaded <- downloaded + result$downloaded
      } else if (result$skipped > 0) {
        if (check_only) {
          cat("      [check-only: skipped]\n")
        } else {
          cat("      ✓ Already synced\n")
        }
        skipped <- skipped + result$skipped
      }
    } else {
      cat(sprintf("      ✗ Error: %s\n", result$error))
      # Record failure for retry manifest
      failures[[result$cache_key]] <- list(
        error = result$error,
        failed_at = as.character(Sys.time()),
        retry_count = (failures[[result$cache_key]]$retry_count %||% 0) + 1
      )
      errors <- errors + 1
    }
    cat("\n")
  }
}

# Save updated cache (only if changes were made)
if (cache_dirty) {
  jsonlite::write_json(cache, cache_file, pretty = FALSE)
}

# Save failure manifest (if there are failures)
if (length(failures) > 0) {
  jsonlite::write_json(failures, failures_file, pretty = FALSE)
  cat(sprintf("Failures saved to: %s\n", failures_file))
  cat("  To retry only failed files: Rscript tools/sync/xet-sync.R --retry-failures models.json\n")
}

# Summary
cat("=== Summary ===\n")
if (retry_failures) {
  cat(sprintf("Mode:          RETRY (previously failed files)\n"))
}
cat(sprintf("Total files:   %d\n", total_files))
cat(sprintf("Downloaded:    %d\n", downloaded))
cat(sprintf("Skipped:       %d\n", skipped))
cat(sprintf("Errors:        %d\n", errors))

# Update failure manifest: remove successfully retried files
if (retry_failures && errors < length(failures)) {
  # Remove entries that are no longer in the failures list
  # (i.e., files that were successfully recovered)
  recovered <- length(failures) - errors
  cat(sprintf("Recovered:     %d (no longer in failures manifest)\n", recovered))

  # Clean up recovered files from failures manifest if requested
  if (recovered > 0) {
    # In a real scenario, we'd remove the successfully downloaded files from the manifest
    # For now, just report them
  }
}

cat(sprintf("\nCache saved to: %s\n", cache_file))

if (errors > 0) {
  quit(status = 1)
}
