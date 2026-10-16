# Token rejected on the term fetch (6.2.2). The loopback fault server answers the
# term fetch with HTTP 401 and no body. Reconstruction still succeeds, so the
# call reaches the term fetch. No real endpoint is used and no waiting for expiry.
# The server is file-local (a copy of helper-fault-cas.R with a term_status
# argument); the shared helper is not edited.

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
    writeBin(charToRaw(sprintf("HTTP/1.1 %d Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n", term_status)), con)
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

# Start the server with the given term status; same readiness and retry scheme
# as start_fault_cas(). Returns the handle shape that stop_fault_cas() and
# fault_requests() expect.
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

# Run call_fn(client) against a 401 term server with a private HF_HOME and the
# canary token. Returns the error or value, elapsed seconds, and request log.
run_token_case <- function(call_fn) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  on.exit({
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }, add = TRUE)

  h <- start_token_cas(term_status = 401L)
  on.exit(stop_fault_cas(h), add = TRUE)
  client <- make_fault_client(h$endpoint, TOKEN_CANARY)
  on.exit(xet_client_close(client), add = TRUE)

  start <- Sys.time()
  res <- tryCatch(call_fn(client), error = function(e) e)
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  list(res = res, elapsed = elapsed, reqs = fault_requests(h))
}

test_that("term fetch 401: xet_download_file errors, no dest, no .part, no token", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")

  dir <- tempfile("rxet-token-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  out <- run_token_case(function(client) {
    xet_download_file(client, FAULT_HASH, FAULT_TERM_LEN, dest)
    NULL
  })

  expect_s3_class(out$res, "error")
  msg <- conditionMessage(out$res)
  expect_match(msg, "401")
  expect_false(grepl(TOKEN_CANARY, msg, fixed = TRUE))
  expect_lt(out$elapsed, 60)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
  expect_true(any(grepl("^status 401", out$reqs)))
  expect_equal(sum(grepl("^GET /xorb/", out$reqs)), 1)
  expect_false(file.exists(dest))
  expect_length(list.files(dir, all.files = TRUE, pattern = "\\.part$"), 0)
})

test_that("term fetch 401: xet_stream_raw errors and returns no value", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")

  out <- run_token_case(function(client) xet_stream_raw(client, FAULT_HASH, FAULT_TERM_LEN))

  expect_s3_class(out$res, "error")
  msg <- conditionMessage(out$res)
  expect_false(is.raw(out$res))
  # Race in upstream xet-data (sequential_writer.rs, download_stream.rs): the stream writer can
  # report "Data sender was dropped" before the failed fetch's 401 reaches the caller. Either
  # message is accepted; the 401 request in the log below is still required.
  expect_match(msg, "401|Data sender was dropped before sending data")
  expect_false(grepl(TOKEN_CANARY, msg, fixed = TRUE))
  expect_lt(out$elapsed, 60)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
  expect_true(any(grepl("^status 401", out$reqs)))
  expect_equal(sum(grepl("^GET /xorb/", out$reqs)), 1)
})
