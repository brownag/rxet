context("Local download and read")

# Start a local server and a client for one test. Each test gets its own
# HF_HOME so the shared Xet shard cache cannot deduplicate an upload against an
# earlier run (see test-local-upload.R). Cleanup is registered on the calling
# test's frame.
start_download_client <- function(env = parent.frame()) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  h <- start_local_cas()
  client <- xet_client_new(h$endpoint, "local-test-token")
  cleanup <- function() {
    xet_client_close(client)
    stop_local_cas(h)
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }
  do.call(on.exit, list(bquote(.(cleanup)()), add = TRUE), envir = env)
  list(client = client, endpoint = h$endpoint)
}

# Fresh directory per test so .part checks see only this test's files.
fresh_dir <- function() {
  d <- tempfile("dl_")
  dir.create(d)
  d
}

test_that("64 KiB disk download is byte-identical and has the exact size", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)
  dest <- file.path(fresh_dir(), "out.bin")
  xet_download_file(client, info$hash, info$file_size, dest)

  expect_identical(readBin(dest, "raw", 65536L), bytes)
  expect_identical(file.size(dest), 65536)
})

test_that("xet_stream_raw returns the full 64 KiB byte-identical", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)
  out <- xet_stream_raw(client, info$hash, 65536)

  expect_type(out, "raw")
  expect_length(out, 65536L)
  expect_identical(out, bytes)
})

test_that("range boundaries on a 4 MiB multi-chunk fixture are byte-exact", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(4194304L)
  info <- upload_fixture(client, bytes)
  size <- info$file_size

  # Half-open [start, end): expected bytes are 1-based bytes[(start+1):end].
  cases <- list(
    c(0, 1),
    c(0, 4096),
    c(4095, 4097),           # crosses the 4 KiB boundary
    c(size - 1, size),       # last byte
    c(1000003, 1500017)      # mid-chunk, start not 4 KiB aligned
  )
  for (cs in cases) {
    start <- cs[1]
    end <- cs[2]
    got <- xet_stream_range(client, info$hash, size, start, end)
    expect_identical(got, bytes[(start + 1):end], info = sprintf("[%g, %g)", start, end))
  }
})

test_that("xet_stream_range rejects an empty range and an end past EOF", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)

  expect_error(xet_stream_range(client, info$hash, info$file_size, 100, 100))
  expect_error(xet_stream_range(client, info$hash, info$file_size, 0, info$file_size + 1))
})

test_that("xet_open_connection reads 64 KiB byte-identical and closes cleanly", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)

  conn <- xet_open_connection(client, info$hash, 65536)
  expect_identical(readBin(conn, "raw", 65536L), bytes)
  expect_no_error(xet_close_connection(conn))
})

test_that("disk download leaves no .part file beside dest", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)
  dir <- fresh_dir()
  dest <- file.path(dir, "out.bin")
  xet_download_file(client, info$hash, info$file_size, dest)

  expect_true(file.exists(dest))
  expect_length(list.files(dir, pattern = "\\.part$", all.files = TRUE), 0)
})

test_that("two downloads on the same client yield identical bytes", {
  skip_without_local_cas()
  client <- start_download_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)
  dir <- fresh_dir()
  dest1 <- file.path(dir, "first.bin")
  dest2 <- file.path(dir, "second.bin")
  xet_download_file(client, info$hash, info$file_size, dest1)
  xet_download_file(client, info$hash, info$file_size, dest2)

  expect_identical(readBin(dest1, "raw", 65536L), bytes)
  expect_identical(readBin(dest2, "raw", 65536L), bytes)
})
