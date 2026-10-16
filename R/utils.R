# Utility functions for result handling and HTTP requests

#' Create standardized result object
#'
#' Internal utility for creating consistent result structures across the package.
#' Provides a unified way to return success/data or success/error pairs.
#'
#' @param data Object to return on success (ignored if error is provided)
#' @param error Error message as character string (optional)
#'
#' @return List with components:
#'   - `success`: Logical; TRUE if no error, FALSE if error provided
#'   - `data`: The data object (only present if success = TRUE)
#'   - `error`: Error message (only present if success = FALSE)
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' # Success case
#' make_result(list(hash = "abc123", size = 1024))
#'
#' # Error case
#' make_result(error = "Invalid file hash")
#' }
make_result <- function(data = NULL, error = NULL) {
  if (is.null(error)) {
    list(success = TRUE, data = data)
  } else {
    list(success = FALSE, error = error)
  }
}

#' Format file action status for display
#'
#' Internal utility for formatting structured action states as human-readable strings.
#'
#' @param action List with components `type` ("DOWNLOAD", "SKIP", "UPDATE") and
#'   `reason` ("new", "hash_changed", "no_changes", "unknown_state", "check_only")
#'
#' @return Character string formatted as "TYPE (reason)"
#'
#' @keywords internal
format_action <- function(action) {
  sprintf("%s (%s)", action$type, action$reason)
}

#' Determine file action based on state
#'
#' Internal utility for determining what action to take on a file based on
#' its existence and cache state.
#'
#' @param file_exists Logical; does the file exist locally?
#' @param hash_matches Logical; does the cached hash match upstream?
#' @param cached List or NULL; cached metadata
#'
#' @return List with components:
#'   - `type`: "DOWNLOAD" or "SKIP"
#'   - `reason`: "new", "hash_changed", "no_changes", or "unknown_state"
#'
#' @keywords internal
determine_action <- function(file_exists, hash_matches, cached) {
  if (!file_exists) {
    list(type = "DOWNLOAD", reason = "new")
  } else if (!hash_matches && !is.null(cached)) {
    list(type = "UPDATE", reason = "hash_changed")
  } else if (hash_matches) {
    list(type = "SKIP", reason = "no_changes")
  } else {
    list(type = "DOWNLOAD", reason = "unknown_state")
  }
}

#' Evict old cache entries based on TTL
#'
#' Internal utility for trimming cache to remove entries older than the specified TTL.
#'
#' @param cache List of cached entries with `downloaded_at` timestamps
#' @param ttl_days Numeric; cache entries older than this many days are removed
#'
#' @return List; cache with old entries removed
#'
#' @keywords internal
evict_old_cache <- function(cache, ttl_days = 90) {
  if (length(cache) == 0) {
    return(cache)
  }

  now <- as.numeric(Sys.time())
  ttl_seconds <- ttl_days * 86400

  # Filter to keep only entries within TTL
  cache[sapply(cache, function(entry) {
    if (is.null(entry$downloaded_at)) {
      TRUE
    } else {
      age_seconds <- now - as.numeric(as.POSIXct(entry$downloaded_at))
      age_seconds < ttl_seconds
    }
  })]
}

#' Evict cache entries if exceeding size limit
#'
#' Internal utility for trimming cache to a maximum number of entries,
#' keeping the most recently accessed entries.
#'
#' @param cache List of cached entries
#' @param max_entries Numeric; maximum number of entries to keep
#'
#' @return List; cache trimmed to max_entries
#'
#' @keywords internal
evict_excess_cache <- function(cache, max_entries = 5000) {
  if (length(cache) <= max_entries) {
    return(cache)
  }

  # Sort by downloaded_at (most recent first) and keep top N
  sorted_entries <- cache[order(
    sapply(cache, function(e) {
      if (is.null(e$downloaded_at)) {
        0
      } else {
        as.numeric(as.POSIXct(e$downloaded_at))
      }
    }),
    decreasing = TRUE
  )]

  sorted_entries[1:max_entries]
}

#' Apply full cache maintenance: TTL + size limit
#'
#' Internal utility for cleaning up cache by removing old entries and
#' excess entries.
#'
#' @param cache List of cached entries
#' @param ttl_days Numeric; cache entries older than this many days are removed
#' @param max_entries Numeric; maximum number of entries to keep
#'
#' @return List; cleaned cache
#'
#' @keywords internal
maintain_cache <- function(cache, ttl_days = 90, max_entries = 5000) {
  cache |>
    evict_old_cache(ttl_days = ttl_days) |>
    evict_excess_cache(max_entries = max_entries)
}
