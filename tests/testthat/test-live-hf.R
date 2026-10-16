context("Live Hugging Face reads (opt-in)")

# On-demand live suite (decision D2). Runs only when RXET_LIVE_TESTS=1 is set,
# locally or by a developer. Public CI never sets it. Read-only: this file never
# calls xet_upload_file (decision D4). A network failure with the gate set is an
# error, not a skip (hazard H8).

# Public dataset used for live reads.
LIVE_REPO <- "brownag/rxet-test-data"
# Hub tree API (GET /api/datasets/brownag/rxet-test-data/tree/main): test_data.parquet
# has oid c25ed568...28bf4 (LFS sha256) and size 2931.
LIVE_HASH <- "4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331"
LIVE_SIZE <- 2931
LIVE_SHA256 <- "c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4"
# CAS endpoint: the casUrl returned by GET /api/datasets/brownag/rxet-test-data/xet-read-token/main
# (authenticated probe, 5.3.2). The package examples still show cas-cf.huggingface.co, which does not resolve.
LIVE_ENDPOINT <- "https://cas-server.xethub.hf.co"

# Start a client with a private HF_HOME so the developer's shard cache is never
# read or written (see test-local-download.R). Cleanup is registered on the
# calling test's frame. xet_client_new rejects an empty token, so an unset
# HF_TOKEN is passed as a placeholder; the server decides whether it is accepted.
start_live_client <- function(env = parent.frame()) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  hf_home <- tempfile("hf_home_")
  Sys.setenv(HF_HOME = hf_home)
  client <- xet_client_new(LIVE_ENDPOINT, live_cas_token())
  cleanup <- function() {
    xet_client_close(client)
    unlink(hf_home, recursive = TRUE)
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }
  do.call(on.exit, list(bquote(.(cleanup)()), add = TRUE), envir = env)
  client
}

test_that("probe: a read of LIVE_HASH succeeds with the token state recorded (J2, H7)", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")

  client <- start_live_client()
  dest <- tempfile(fileext = ".parquet")
  on.exit(unlink(dest), add = TRUE)

  # Probe outcome (5.3.2): whether an unauthenticated client can read a public
  # Xet file is unknown until this runs. The result is recorded in STATE_5.md.
  # If this fails with HF_TOKEN unset, the token is required and the other live
  # tests fail too: that is a finding, not a skip.
  err <- tryCatch({
    xet_download_file(client, LIVE_HASH, LIVE_SIZE, dest)
    NULL
  }, error = function(e) conditionMessage(e))
  message(sprintf("probe: HF_TOKEN %s; download %s",
                  if (nzchar(Sys.getenv("HF_TOKEN"))) "set" else "unset",
                  if (is.null(err)) "succeeded" else paste("failed:", err)))
  expect_null(err, info = "live read of LIVE_HASH failed (see probe message)")
})

test_that("live download of LIVE_HASH is 2931 bytes with the hub LFS sha256", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("digest")

  client <- start_live_client()
  dest <- tempfile(fileext = ".parquet")
  on.exit(unlink(dest), add = TRUE)

  xet_download_file(client, LIVE_HASH, LIVE_SIZE, dest)
  expect_equal(file.size(dest), LIVE_SIZE)
  expect_identical(digest::digest(file = dest, algo = "sha256"), LIVE_SHA256)
})

test_that("live xet_stream_raw of LIVE_HASH matches the hub LFS sha256", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("digest")

  client <- start_live_client()
  got <- xet_stream_raw(client, LIVE_HASH, LIVE_SIZE)
  expect_length(got, LIVE_SIZE)
  expect_identical(digest::digest(got, algo = "sha256", serialize = FALSE), LIVE_SHA256)
})

test_that("live range reads return Parquet PAR1 magic at head and tail", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")

  client <- start_live_client()
  # Ranges are end-exclusive: [0, 4) is the head magic, [2927, 2931) the tail magic.
  expect_identical(xet_stream_range(client, LIVE_HASH, LIVE_SIZE, 0, 4), charToRaw("PAR1"))
  expect_identical(xet_stream_range(client, LIVE_HASH, LIVE_SIZE, 2927, 2931), charToRaw("PAR1"))
  expect_identical(
    xet_stream_range(client, LIVE_HASH, LIVE_SIZE, 0, LIVE_SIZE),
    xet_stream_raw(client, LIVE_HASH, LIVE_SIZE)
  )
})

test_that("live connection reads LIVE_HASH byte-identical to the raw read and closes", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")

  client <- start_live_client()
  raw_bytes <- xet_stream_raw(client, LIVE_HASH, LIVE_SIZE)
  conn <- xet_open_connection(client, LIVE_HASH, LIVE_SIZE)
  expect_identical(readBin(conn, "raw", LIVE_SIZE), raw_bytes)
  expect_no_error(xet_close_connection(conn))
})
