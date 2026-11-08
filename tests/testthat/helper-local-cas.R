# Local CAS server harness for tests.
# Starts the upstream local_cas_server (xet-client simulation) on loopback.
# Reads no credentials. Server data is in memory; temp files go to tempdir().

#' Check if package is compiled with Rust extension
#'
#' Attempts to call a basic Rust function to determine compilation status.
#'
#' @return Logical; TRUE if Rust extension is available
#' @keywords internal
is_compiled <- function() {
  tryCatch({
    # Try to call a safe Rust function that requires no setup
    result <- .Call("wrap__rxet_init_client", "https://test", "test", NULL, NULL, FALSE, PACKAGE = "rxet")
    # If we get here and got a handle, close it
    if (is.character(result)) {
      .Call("wrap__rxet_close_client", result, PACKAGE = "rxet")
      return(TRUE)
    }
    FALSE
  }, error = function(e) {
    FALSE
  })
}

# Path to local_cas_server, or NA when not configured or not found.
local_cas_binary <- function() {
  env <- Sys.getenv("RXET_LOCAL_CAS_SERVER", unset = "")
  if (nzchar(env)) return(env)
  found <- Sys.which("local_cas_server")
  if (nzchar(found)) return(unname(found))
  NA_character_
}

skip_without_local_cas <- function() {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")
  if (is.na(local_cas_binary())) {
    skip("local_cas_server not found: set RXET_LOCAL_CAS_SERVER (see AGENTS.md, Testing)")
  }
  invisible(NULL)
}

# Free loopback port (same probe as closed_port() in test-phase4-lifecycle.R).
local_cas_free_port <- function() {
  repeat {
    port <- sample(20000:40000, 1)
    conn <- suppressWarnings(tryCatch(
      socketConnection("127.0.0.1", port, open = "r", timeout = 1),
      error = function(e) NULL
    ))
    if (is.null(conn)) return(port)
    close(conn)
  }
}

# Poll until a TCP connect succeeds, the process exits, or 30 s pass.
local_cas_wait_ready <- function(proc, port, timeout = 30) {
  deadline <- Sys.time() + timeout
  repeat {
    if (!proc$is_alive()) return(FALSE)
    conn <- suppressWarnings(tryCatch(
      socketConnection("127.0.0.1", port, open = "r+b", timeout = 1),
      error = function(e) NULL
    ))
    if (!is.null(conn)) {
      close(conn)
      return(TRUE)
    }
    if (Sys.time() > deadline) return(FALSE)
    Sys.sleep(0.1)
  }
}

# Start the server on a free loopback port. Caller owns cleanup:
#   h <- start_local_cas(); on.exit(stop_local_cas(h), add = TRUE)
start_local_cas <- function() {
  binary <- local_cas_binary()
  if (is.na(binary)) stop("local_cas_server not found", call. = FALSE)
  for (attempt in seq_len(20)) {
    port <- local_cas_free_port()
    out_file <- tempfile("local_cas_out_", fileext = ".log")
    err_file <- tempfile("local_cas_err_", fileext = ".log")
    proc <- processx::process$new(
      binary,
      c("--in-memory", "--host", "127.0.0.1", "--port", as.character(port)),
      stdout = out_file,
      stderr = err_file
    )
    if (local_cas_wait_ready(proc, port)) {
      handle <- list(
        endpoint = sprintf("http://127.0.0.1:%d", port),
        proc = proc,
        files = c(out_file, err_file)
      )
      return(handle)
    }
    # Bind failure or no listener: kill, clean up, retry on a new port.
    if (proc$is_alive()) proc$kill()
    proc$wait(timeout = 5000)
    unlink(c(out_file, err_file))
  }
  stop("local_cas_server did not start after 20 attempts", call. = FALSE)
}

# Kill the server and wait for exit. Safe to call twice.
stop_local_cas <- function(handle) {
  if (is.null(handle) || is.null(handle$proc)) return(invisible(NULL))
  if (handle$proc$is_alive()) handle$proc$kill()
  handle$proc$wait(timeout = 5000)
  unlink(handle$files)
  invisible(NULL)
}

# Deterministic bytes for fixtures.
make_fixture_bytes <- function(n, seed = 1L) {
  set.seed(seed)
  as.raw(sample.int(256L, n, replace = TRUE) - 1L)
}

# Upload bytes via xet_upload_file. Returns list(hash, file_size, sha256).
upload_fixture <- function(client, bytes) {
  skip_if_not_installed("digest")
  path <- tempfile(fileext = ".bin")
  on.exit(unlink(path), add = TRUE)
  writeBin(bytes, path)
  info <- xet_upload_file(client, path)
  list(
    hash = info$hash,
    file_size = info$file_size,
    sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE)
  )
}

# Upload, download back, and compare bytes. Guards H11.
assert_roundtrip <- function(client, bytes) {
  info <- upload_fixture(client, bytes)
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)
  xet_download_file(client, info$hash, info$file_size, dest)
  testthat::expect_identical(readBin(dest, "raw", length(bytes)), bytes)
  invisible(TRUE)
}
