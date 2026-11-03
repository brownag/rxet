# Token canary on every offline-reachable public path (9.1.1).
# Each path runs against a loopback fault server (401/403 on the term fetch, or a
# truncated term body) or against a dead loopback port for refusals that happen
# before any network call. The canary token must not appear in any error message
# or warning. Success paths are not asserted.
# The token server and its start helper are file-local copies of the
# test-fault-token.R code; helper-fault-cas.R is not edited.

TOKEN_CANARY <- "rxet-canary-token-XYZ"

# Child script. Args: port, ready-file, lifetime seconds, hash, term length, term status.
token_server_lines <- r"---(
args <- commandArgs(trailingOnly = TRUE)
port <- as.integer(args[1]); ready <- args[2]
lifetime <- as.numeric(args[3]); hash <- args[4]
n <- as.integer(args[5]); term_status <- as.integer(args[6])
srv <- tryCatch(serverSocket(port), error = function(e) NULL)
if (is.null(srv)) quit(save = "no", status = 2)
writeLines("ready", ready)
deadline <- Sys.time() + lifetime
json <- sprintf(paste0(
  '{"offset_into_first_range":0,"terms":[{"hash":"%s","unpacked_length":%d,',
  '"range":{"start":0,"end":1}}],"fetch_info":{"%s":[{"range":{"start":0,"end":1},',
  '"url":"http://127.0.0.1:%d/xorb/term","url_range":{"start":0,"end":%d}}]}}'),
  hash, n, hash, port, n - 1L)
repeat {
  if (Sys.time() > deadline) break
  con <- tryCatch(socketAccept(srv, blocking = TRUE, open = "r+b", timeout = 5),
                  error = function(e) NULL)
  if (is.null(con)) next
  req <- tryCatch(readLines(con, n = 1), error = function(e) character())
  hdrs <- character()
  repeat {
    line <- tryCatch(readLines(con, n = 1), error = function(e) character())
    if (length(line) == 0 || !nzchar(trimws(line))) break
    hdrs <- c(hdrs, line)
  }
  if (length(req) == 0) { close(con); next }
  cat(req, "\n", file = paste0(ready, ".req"), append = TRUE)
  rng <- grep("^range:", hdrs, ignore.case = TRUE, value = TRUE)
  start <- if (length(rng)) as.numeric(sub("^[^=]*=([0-9]+).*$", "\\1", rng[1])) else 0
  if (grepl("^GET /v2/", req)) {
    writeBin(charToRaw("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"), con)
  } else if (grepl("^GET /v1/reconstructions/", req) && start >= n) {
    writeBin(charToRaw("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"), con)
  } else if (grepl("^GET /v1/reconstructions/", req)) {
    hdr <- sprintf("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n",
                   nchar(json, type = "bytes"))
    writeBin(c(charToRaw(hdr), charToRaw(json)), con)
  } else if (grepl("^GET /xorb/", req) && term_status != 200L) {
    writeBin(charToRaw(sprintf("HTTP/1.1 %d Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", term_status)), con)
    cat("status", term_status, "\n", file = paste0(ready, ".req"), append = TRUE)
  } else if (grepl("^GET /xorb/", req)) {
    hdr <- sprintf("HTTP/1.1 200 OK\r\nContent-Length: %d\r\nConnection: close\r\n\r\n", n)
    writeBin(charToRaw(hdr), con)
    writeBin(rep(as.raw(0), n %/% 2L), con)
  } else {
    writeBin(charToRaw("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"), con)
  }
  try(close(con), silent = TRUE)
}
close(srv)
)---"

# Same readiness and retry scheme as start_fault_cas(). Returns the handle shape
# that stop_fault_cas() and fault_requests() expect.
start_token_cas <- function(term_status = 401L, lifetime = 120) {
  rscript <- file.path(R.home("bin"), paste0("Rscript", if (.Platform$OS.type == "windows") ".exe" else ""))
  script <- tempfile("token_server_", fileext = ".R")
  writeLines(token_server_lines, script)
  for (attempt in seq_len(20)) {
    port <- fault_free_port()
    ready <- tempfile("token_ready_", fileext = ".txt")
    out_file <- tempfile("token_out_", fileext = ".log")
    err_file <- tempfile("token_err_", fileext = ".log")
    proc <- processx::process$new(
      rscript,
      c(script, as.character(port), ready, as.character(lifetime),
        FAULT_HASH, as.character(FAULT_TERM_LEN), as.character(term_status)),
      stdout = out_file,
      stderr = err_file
    )
    deadline <- Sys.time() + 30
    repeat {
      if (file.exists(ready)) {
        return(list(
          endpoint = sprintf("http://127.0.0.1:%d", port),
          proc = proc,
          files = c(script, ready, paste0(ready, ".req"), out_file, err_file),
          req_log = paste0(ready, ".req")
        ))
      }
      if (!proc$is_alive() || Sys.time() > deadline) break
      Sys.sleep(0.05)
    }
    if (proc$is_alive()) proc$kill()
    proc$wait(timeout = 5000)
    unlink(c(ready, out_file, err_file))
  }
  unlink(script)
  stop("token fault server did not start", call. = FALSE)
}

# Run call_fn(client) against the server from start() with a private HF_HOME and
# the canary token. Captures the error (if any) and every warning message.
run_canary_case <- function(call_fn, start = function() start_token_cas(term_status = 401L)) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  on.exit({
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }, add = TRUE)

  h <- start()
  on.exit(stop_fault_cas(h), add = TRUE)
  client <- make_fault_client(h$endpoint, TOKEN_CANARY)
  on.exit(xet_client_close(client), add = TRUE)

  warns <- character()
  res <- tryCatch(
    withCallingHandlers(call_fn(client), warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    error = function(e) e
  )
  list(res = res, warns = warns, reqs = fault_requests(h))
}

# Client on a dead loopback port for paths that refuse before any network call.
run_offline_case <- function(call_fn) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  on.exit({
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }, add = TRUE)

  client <- make_fault_client(sprintf("http://127.0.0.1:%d", fault_free_port()), TOKEN_CANARY)
  on.exit(xet_client_close(client), add = TRUE)

  warns <- character()
  res <- tryCatch(
    withCallingHandlers(call_fn(client), warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    error = function(e) e
  )
  list(res = res, warns = warns)
}

# No canary in the error message or in any warning.
expect_no_canary <- function(out) {
  expect_s3_class(out$res, "error")
  expect_false(grepl(TOKEN_CANARY, conditionMessage(out$res), fixed = TRUE))
  for (w in out$warns) {
    expect_false(grepl(TOKEN_CANARY, w, fixed = TRUE))
  }
}

start_403 <- function() start_token_cas(term_status = 403L)
start_mid <- function() start_fault_cas()

# Term fetch 401 and 403 ----------------------------------------------------

test_that("term fetch 401: xet_download_file error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  dir <- tempfile("rxet-canary-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  out <- run_canary_case(function(client) {
    xet_download_file(client, FAULT_HASH, FAULT_TERM_LEN, dest)
    NULL
  })
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 403: xet_download_file error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  dir <- tempfile("rxet-canary-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  out <- run_canary_case(function(client) {
    xet_download_file(client, FAULT_HASH, FAULT_TERM_LEN, dest)
    NULL
  }, start = start_403)
  expect_no_canary(out)
  expect_true(any(grepl("^status 403", out$reqs)))
})

test_that("term fetch 401: xet_stream_raw error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) xet_stream_raw(client, FAULT_HASH, FAULT_TERM_LEN))
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 403: xet_stream_raw error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) xet_stream_raw(client, FAULT_HASH, FAULT_TERM_LEN),
                         start = start_403)
  expect_no_canary(out)
  expect_true(any(grepl("^status 403", out$reqs)))
})

test_that("term fetch 401: xet_stream_range error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) {
    xet_stream_range(client, FAULT_HASH, FAULT_TERM_LEN, 0, 1)
  })
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 403: xet_stream_range error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) {
    xet_stream_range(client, FAULT_HASH, FAULT_TERM_LEN, 0, 1)
  }, start = start_403)
  expect_no_canary(out)
  expect_true(any(grepl("^status 403", out$reqs)))
})

test_that("term fetch 401: xet_open_connection error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) xet_open_connection(client, FAULT_HASH, FAULT_TERM_LEN))
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 403: xet_open_connection error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) xet_open_connection(client, FAULT_HASH, FAULT_TERM_LEN),
                         start = start_403)
  expect_no_canary(out)
  expect_true(any(grepl("^status 403", out$reqs)))
})

test_that("term fetch 401: read_xet_parquet error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  skip_if_not_installed("arrow")
  out <- run_canary_case(function(client) read_xet_parquet(client, FAULT_HASH, FAULT_TERM_LEN))
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 401: read_xet_raster error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  skip_if_not_installed("terra")
  out <- run_canary_case(function(client) read_xet_raster(client, FAULT_HASH, FAULT_TERM_LEN))
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

test_that("term fetch 401: read_xet_vector error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  skip_if_not_installed("sf")
  out <- run_canary_case(function(client) read_xet_vector(client, FAULT_HASH, FAULT_TERM_LEN))
  expect_no_canary(out)
  expect_true(any(grepl("^status 401", out$reqs)))
})

# Mid-stream term drop ------------------------------------------------------

test_that("mid-stream drop: xet_download_file error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  dir <- tempfile("rxet-canary-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  out <- run_canary_case(function(client) {
    xet_download_file(client, FAULT_HASH, FAULT_TERM_LEN, dest)
    NULL
  }, start = start_mid)
  expect_no_canary(out)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
})

test_that("mid-stream drop: xet_stream_raw error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  out <- run_canary_case(function(client) xet_stream_raw(client, FAULT_HASH, FAULT_TERM_LEN),
                         start = start_mid)
  expect_no_canary(out)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
})

# Offline validation failures before any network call -----------------------

test_that("read_xet_vector validation error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("sf")
  out <- run_offline_case(function(client) read_xet_vector(client, FAULT_HASH, -1))
  expect_no_canary(out)
})

test_that("xet_upload_file missing source error has no canary", {
  skip_if_not(is_compiled(), "Rust extension not available")
  out <- run_offline_case(function(client) {
    xet_upload_file(client, file.path(tempdir(), "rxet-canary-missing.bin"))
  })
  expect_no_canary(out)
})

test_that("xet_upload_file network 401 path is not reachable offline", {
  skip("fault server has no upload route; upload network 401 is not reachable offline (9.1.1 Q2)")
})
