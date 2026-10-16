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

# Fixtures uploaded by the user to brownag/rxet-test-data at the dataset top level
# (6.0.1). Generated from seed 20261015; the sha256 values are the SHA256SUMS.txt
# entries (scratchpad, not in the repo) and the hub LFS oids.
# Multi-chunk binary: 16 MiB, uncompressed bytes.
LIVE_MULTI_HASH <- "5a32191c41e82f198b29d384ca4b5c38f3a3ce2f8d22b4f56f25d6aa4a50f6f9"
LIVE_MULTI_SIZE <- 16777216
LIVE_MULTI_SHA256 <- "f307458aa3556bf7c2c66bc36b7a3c1f3ce9e20d5b7784e4fd9df6231cdb6dbe"
# GeoTIFF: 512x512 Float32, UTM 33N, uncompressed.
LIVE_GEO_HASH <- "f8d51851e138a95dff77a8b5c944b218eed87e39c213ff4639ae75e0c472ce1a"
LIVE_GEO_SIZE <- 1051299
LIVE_GEO_SHA256 <- "f60de44e71ac663d79d4ef15a745aeb7a57a31ca42a51fa5d3173cbc4341e9e8"

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

test_that("live download of LIVE_MULTI_HASH is 16777216 bytes with the hub LFS sha256", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("digest")

  client <- start_live_client()
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)

  xet_download_file(client, LIVE_MULTI_HASH, LIVE_MULTI_SIZE, dest)
  expect_equal(file.size(dest), LIVE_MULTI_SIZE)
  expect_identical(digest::digest(file = dest, algo = "sha256"), LIVE_MULTI_SHA256)
})

test_that("live range read of LIVE_MULTI_HASH at offset 65536 matches the full download", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")

  client <- start_live_client()
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)

  xet_download_file(client, LIVE_MULTI_HASH, LIVE_MULTI_SIZE, dest)
  full <- readBin(dest, "raw", LIVE_MULTI_SIZE)
  # Ranges are end-exclusive: [65536, 69632) is R indices 65537 to 69632. The offset is
  # not the start of the file; it is not claimed to be a verified chunk boundary.
  part <- xet_stream_range(client, LIVE_MULTI_HASH, LIVE_MULTI_SIZE, 65536, 65536 + 4096)
  expect_length(part, 4096)
  expect_identical(part, full[65537:69632])
})

test_that("live download of LIVE_GEO_HASH is 1051299 bytes with the hub LFS sha256 and a TIFF magic", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("digest")

  client <- start_live_client()
  dest <- tempfile(fileext = ".tif")
  on.exit(unlink(dest), add = TRUE)

  xet_download_file(client, LIVE_GEO_HASH, LIVE_GEO_SIZE, dest)
  expect_equal(file.size(dest), LIVE_GEO_SIZE)
  expect_identical(digest::digest(file = dest, algo = "sha256"), LIVE_GEO_SHA256)
  # Little-endian "II*\0" or big-endian "MM\0*" TIFF header.
  expect_true(identical(readBin(dest, "raw", 4), as.raw(c(0x49, 0x49, 0x2a, 0x00))) ||
    identical(readBin(dest, "raw", 4), as.raw(c(0x4d, 0x4d, 0x00, 0x2a))))
})

test_that("live xet_stream_raw of LIVE_GEO_HASH matches the downloaded bytes", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")

  client <- start_live_client()
  dest <- tempfile(fileext = ".tif")
  on.exit(unlink(dest), add = TRUE)

  xet_download_file(client, LIVE_GEO_HASH, LIVE_GEO_SIZE, dest)
  expect_identical(
    xet_stream_raw(client, LIVE_GEO_HASH, LIVE_GEO_SIZE),
    readBin(dest, "raw", LIVE_GEO_SIZE)
  )
})
