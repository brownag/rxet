context("Lazy range connection")

test_that("xet_open_stream_connection validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")
  expect_error(xet_open_stream_connection("", "hash", 1024), "handle")
  expect_error(xet_open_stream_connection("client", "", 1024), "file_hash")
  expect_error(xet_open_stream_connection("client", "hash", -1), "file_size")
  expect_error(xet_open_stream_connection("client", "hash", 1.5), "file_size")
})

test_that("a stream connection is seekable and reads bytes at the requested offsets", {
  skip_without_local_cas()
  client <- start_fixture_client()
  bytes <- make_fixture_bytes(300000L, seed = 11L)
  info <- upload_fixture(client, bytes)

  conn <- xet_open_stream_connection(client, info$hash, info$file_size)
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_s3_class(conn, "rxet_connection")
  expect_true(isOpen(conn))
  expect_true(isSeekable(conn))
  expect_identical(summary(conn)$text, "binary")

  expect_identical(readBin(conn, "raw", 100), bytes[1:100])

  expect_equal(seek(conn, 0, "end"), 100)
  expect_equal(seek(conn, 0, "current"), as.numeric(info$file_size))
  expect_equal(seek(conn, 4096, "start"), as.numeric(info$file_size))
  expect_equal(seek(conn, 0, "current"), 4096)
  expect_identical(readBin(conn, "raw", 64), bytes[4097:4160])

  # A read that starts mid-window and crosses the 64 KiB alignment boundary.
  expect_equal(seek(conn, 65000, "start"), 4160)
  expect_equal(seek(conn, 0, "current"), 65000)
  expect_identical(readBin(conn, "raw", 2000), bytes[65001:67000])

  # A read past the end returns only the bytes that exist.
  expect_equal(seek(conn, length(bytes) - 10, "start"), 67000)
  expect_equal(seek(conn, 0, "current"), length(bytes) - 10)
  expect_identical(readBin(conn, "raw", 100), bytes[(length(bytes) - 9):length(bytes)])
})

test_that("a stream connection rejects seeks outside the file", {
  skip_without_local_cas()
  client <- start_fixture_client()
  info <- upload_fixture(client, make_fixture_bytes(1024L, seed = 3L))

  conn <- xet_open_stream_connection(client, info$hash, info$file_size)
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_error(seek(conn, -1, "start"), "outside the file")
  expect_equal(seek(conn, 0, "current"), 0)
  expect_error(seek(conn, info$file_size + 1, "start"), "outside the file")
  expect_equal(seek(conn, 0, "current"), 0)
})

test_that("closing a stream connection releases its reader", {
  skip_without_local_cas()
  client <- start_fixture_client()
  info <- upload_fixture(client, make_fixture_bytes(1024L, seed = 4L))

  conn <- xet_open_stream_connection(client, info$hash, info$file_size)
  close(conn)
  # Only checks that the connection is invalid after close. Reader release is
  # covered in test-connection-offline.R.
  expect_error(readBin(conn, "raw", 10), "invalid connection")
})

test_that("read_xet_parquet reads through the lazy connection", {
  skip_without_local_cas()
  skip_if_not_installed("arrow")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.parquet")

  expected <- arrow::read_parquet(fixture_path("small.parquet"))
  expect_equal(read_xet_parquet(client, info$hash, info$file_size), expected)
  expect_equal(
    read_xet_parquet(client, info$hash, info$file_size, col_select = 1),
    expected[, 1, drop = FALSE]
  )
})
