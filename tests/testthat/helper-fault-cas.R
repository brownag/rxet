# Loopback fault server for mid-stream failure tests (6.2.1).
# Runs out of process: xet_download_file() and xet_stream_raw() block the R
# session, so the server must answer from a separate Rscript. Uses processx
# (Suggests). Temp files go to tempfile() only; no token is used.

FAULT_HASH <- strrep("ab", 32)
FAULT_TERM_LEN <- 65536L
FAULT_TOKEN <- "rxet-fault-canary-5d2c"

# Free loopback port (same probe as local_cas_free_port()).
fault_free_port <- function() local_cas_free_port()

# Child script. Args: port, ready-file, lifetime seconds, hash, term length.
# Routes: /v2/ -> 404 (client falls back to V1); /v1/reconstructions/ -> JSON;
# /xorb/ -> Content-Length N, first floor(N/2) bytes, then close.
fault_server_script <- function() {
  path <- tempfile("fault_server_", fileext = ".R")
  body <- c(
    'args <- commandArgs(trailingOnly = TRUE)',
    'port <- as.integer(args[1]); ready <- args[2]',
    'lifetime <- as.numeric(args[3]); hash <- args[4]',
    'n <- as.integer(args[5])',
    'srv <- tryCatch(serverSocket(port), error = function(e) NULL)',
    'if (is.null(srv)) quit(save = "no", status = 2)',
    'writeLines("ready", ready)',
    'deadline <- Sys.time() + lifetime',
    'json <- sprintf(paste0(',
    '  \'{"offset_into_first_range":0,"terms":[{"hash":"%s","unpacked_length":%d,\',',
    '  \'"range":{"start":0,"end":1}}],"fetch_info":{"%s":[{"range":{"start":0,"end":1},\',',
    '  \'"url":"http://127.0.0.1:%d/xorb/term","url_range":{"start":0,"end":%d}}]}}\'),',
    '  hash, n, hash, port, n - 1L)',
    'repeat {',
    '  if (Sys.time() > deadline) break',
    '  con <- tryCatch(socketAccept(srv, blocking = TRUE, open = "r+b", timeout = 5),',
    '                  error = function(e) NULL)',
    '  if (is.null(con)) next',
    '  req <- tryCatch(readLines(con, n = 1), error = function(e) character())',
    '  hdrs <- character()',
    '  repeat {',
    '    line <- tryCatch(readLines(con, n = 1), error = function(e) character())',
    '    if (length(line) == 0 || !nzchar(trimws(line))) break',
    '    hdrs <- c(hdrs, line)',
    '  }',
    '  if (length(req) == 0) { close(con); next }',
    '  cat(req, "\\n", file = paste0(ready, ".req"), append = TRUE)',
    '  rng <- grep("^range:", hdrs, ignore.case = TRUE, value = TRUE)',
    '  start <- if (length(rng)) as.numeric(sub("^[^=]*=([0-9]+).*$", "\\\\1", rng[1])) else 0',
    '  if (grepl("^GET /v2/", req)) {',
    '    writeBin(charToRaw("HTTP/1.1 404 Not Found\\r\\nContent-Length: 0\\r\\nConnection: close\\r\\n\\r\\n"), con)',
    '  } else if (grepl("^GET /v1/reconstructions/", req) && start >= n) {',
    '    writeBin(charToRaw("HTTP/1.1 416 Range Not Satisfiable\\r\\nContent-Length: 0\\r\\nConnection: close\\r\\n\\r\\n"), con)',
    '  } else if (grepl("^GET /v1/reconstructions/", req)) {',
    '    hdr <- sprintf("HTTP/1.1 200 OK\\r\\nContent-Type: application/json\\r\\nContent-Length: %d\\r\\nConnection: close\\r\\n\\r\\n",',
    '                   nchar(json, type = "bytes"))',
    '    writeBin(c(charToRaw(hdr), charToRaw(json)), con)',
    '  } else if (grepl("^GET /xorb/", req)) {',
    '    hdr <- sprintf("HTTP/1.1 200 OK\\r\\nContent-Length: %d\\r\\nConnection: close\\r\\n\\r\\n", n)',
    '    writeBin(charToRaw(hdr), con)',
    '    body <- rep(as.raw(0), n %/% 2L)',
    '    writeBin(body, con)',
    '    cat("sent", length(body), "of", n, "\\n", file = paste0(ready, ".req"), append = TRUE)',
    '  } else {',
    '    writeBin(charToRaw("HTTP/1.1 404 Not Found\\r\\nContent-Length: 0\\r\\nConnection: close\\r\\n\\r\\n"), con)',
    '  }',
    '  try(close(con), silent = TRUE)',
    '}',
    'close(srv)'
  )
  writeLines(body, path)
  path
}

# Start the server on a free port; retry on bind failure. Caller owns cleanup:
#   h <- start_fault_cas(); on.exit(stop_fault_cas(h), add = TRUE)
start_fault_cas <- function(lifetime = 120) {
  rscript <- file.path(R.home("bin"), paste0("Rscript", if (.Platform$OS.type == "windows") ".exe" else ""))
  script <- fault_server_script()
  for (attempt in seq_len(20)) {
    port <- fault_free_port()
    ready <- tempfile("fault_ready_", fileext = ".txt")
    out_file <- tempfile("fault_out_", fileext = ".log")
    err_file <- tempfile("fault_err_", fileext = ".log")
    proc <- processx::process$new(
      rscript,
      c(script, as.character(port), ready, as.character(lifetime),
        FAULT_HASH, as.character(FAULT_TERM_LEN)),
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
    # Bind failure or no ready marker: kill, clean up, retry on a new port.
    if (proc$is_alive()) proc$kill()
    proc$wait(timeout = 5000)
    unlink(c(ready, out_file, err_file))
  }
  unlink(script)
  stop("fault server did not start", call. = FALSE)
}

# Request lines seen by the server (one per connection), e.g. "GET /xorb/term".
fault_requests <- function(h) {
  if (!file.exists(h$req_log)) return(character())
  trimws(readLines(h$req_log, warn = FALSE))
}

stop_fault_cas <- function(h) {
  if (h$proc$is_alive()) h$proc$kill()
  h$proc$wait(timeout = 5000)
  unlink(h$files)
  invisible(NULL)
}

# Client with bounded read timeout and a single attempt. Env vars are set only
# around xet_client_new() and restored afterwards (same pattern as
# make_failure_client() in test-local-failures.R).
make_fault_client <- function(endpoint, token = FAULT_TOKEN) {
  vars <- c("HF_XET_CLIENT_READ_TIMEOUT", "HF_XET_CLIENT_RETRY_MAX_ATTEMPTS")
  old <- Sys.getenv(vars, unset = NA)
  on.exit({
    for (v in vars) {
      if (is.na(old[[v]])) {
        Sys.unsetenv(v)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old[[v]]), v))
      }
    }
  }, add = TRUE)
  Sys.setenv(HF_XET_CLIENT_READ_TIMEOUT = "2s", HF_XET_CLIENT_RETRY_MAX_ATTEMPTS = "1")
  xet_client_new(endpoint, token)
}
