# Probe 5.3.1 (run in scratchpad, local_cas_server 1.7.0, --in-memory):
#   Auth: GET /v1/reconstructions/<64 zeros> and /v2/... return HTTP 416 for no
#         header, a wrong bearer token, and a valid-looking bearer token. The
#         server does not enforce tokens, so the auth test is skipped.
#   Size: 65536-byte upload, download with file_size 65537 -> R error
#         "finish error: Task error: task N panicked ... left: 65537 right: 65536"
#         (an hf-xet assertion surfaced through the wrapper). No dest, no .part.
# Assertions below pin only these observations.

# Helpers (file-local). Copy of start_upload_client() in test-local-upload.R:
# a private HF_HOME per test so the shared Xet shard cache is never reused.
start_failure_client <- function(token, env = parent.frame()) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  h <- start_local_cas()
  client <- xet_client_new(h$endpoint, token)
  cleanup <- function() {
    xet_client_close(client)
    stop_local_cas(h)
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }
  do.call(on.exit, list(bquote(.(cleanup)()), add = TRUE), envir = env)
  client
}

# Copy of the make_test_client() env seam in test-phase4-lifecycle.R: bounds
# read timeout and retries so a dead endpoint fails fast. Env vars are restored.
make_failure_client <- function(endpoint, token) {
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

test_that("invalid hash: xet_download_file errors and leaves no dest or .part", {
  skip_without_local_cas()
  client <- start_failure_client("rxet-leak-canary-7f3a")

  dir <- tempfile("rxet-fail-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  err <- tryCatch(
    {
      xet_download_file(client, strrep("0", 64), 65536, dest)
      NULL
    },
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_false(grepl("rxet-leak-canary-7f3a", conditionMessage(err), fixed = TRUE))
  expect_false(file.exists(dest))
  expect_length(list.files(dir, all.files = TRUE, pattern = "\\.part$"), 0)
})

test_that("invalid hash: xet_stream_raw errors and returns no value", {
  skip_without_local_cas()
  client <- start_failure_client("rxet-leak-canary-7f3a")

  res <- tryCatch(xet_stream_raw(client, strrep("0", 64), 65536), error = function(e) e)
  expect_s3_class(res, "error")
  expect_false(is.raw(res))
  expect_false(grepl("rxet-leak-canary-7f3a", conditionMessage(res), fixed = TRUE))
})

test_that("size mismatch: download with wrong file_size errors, never writes truncated bytes", {
  skip_without_local_cas()
  client <- start_failure_client("rxet-leak-canary-7f3a")

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)

  dir <- tempfile("rxet-size-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  err <- tryCatch(
    {
      xet_download_file(client, info$hash, info$file_size + 1, dest)
      NULL
    },
    error = function(e) e
  )
  # Observed (probe 5.3.1): an error is raised and no destination is written.
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "expected 65537 bytes, got 65536 bytes", fixed = TRUE)
  expect_false(grepl("Internal error|panic", conditionMessage(err)))
  expect_false(grepl("rxet-leak-canary-7f3a", conditionMessage(err), fixed = TRUE))
  expect_false(file.exists(dest))
  expect_length(list.files(dir, all.files = TRUE, pattern = "\\.part$"), 0)
})

test_that("auth: wrong or missing token is rejected", {
  skip("local server does not enforce tokens (probe 5.3.1)")
})

test_that("endpoint down mid-session: download errors within 60 s and leaves no dest", {
  skip_without_local_cas()
  h <- start_local_cas()
  on.exit(stop_local_cas(h), add = TRUE)

  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  on.exit(
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home),
    add = TRUE
  )

  client <- make_failure_client(h$endpoint, "rxet-leak-canary-7f3a")
  on.exit(xet_client_close(client), add = TRUE)

  stop_local_cas(h)

  dir <- tempfile("rxet-down-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  elapsed <- system.time({
    err <- tryCatch(
      {
        xet_download_file(client, strrep("a", 64), 65536, dest)
        NULL
      },
      error = function(e) e
    )
  })[["elapsed"]]

  expect_s3_class(err, "error")
  expect_lt(elapsed, 60)
  expect_false(grepl("rxet-leak-canary-7f3a", conditionMessage(err), fixed = TRUE))
  expect_false(file.exists(dest))
})

test_that("local server process is not alive after stop_local_cas", {
  skip_without_local_cas()
  skip_if_not_installed("processx")
  h <- start_local_cas()
  proc <- h$proc
  stop_local_cas(h)
  expect_false(proc$is_alive())
})
