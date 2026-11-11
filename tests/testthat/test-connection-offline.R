context("Offline stream connection over an in-memory reader")

# Mirrors xet_open_stream_connection() closures, minus the client and guard.
offline_conn <- function(bytes) {
  id <- rxet_memory_reader_open(bytes)
  reader <- function(offset, n) rxet_reader_read(id, offset, n)
  close_fun <- function() .rxet_close_reader_quietly(id)
  list(conn = rxet_stream_connection(reader, close_fun, id), id = id)
}

offline_bytes <- as.raw(rep(0:255, length.out = 5000L))

test_that("a memory-backed connection reads bytes sequentially", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_s3_class(conn, "rxet_connection")
  expect_true(isOpen(conn))
  expect_true(isSeekable(conn))
  expect_identical(summary(conn)$text, "binary")

  expect_identical(readBin(conn, "raw", 100), offline_bytes[1:100])
  expect_identical(readBin(conn, "raw", 200), offline_bytes[101:300])
})

test_that("a memory-backed connection seeks to start, current and end", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_equal(seek(conn, 1000, "start"), 0)
  expect_equal(seek(conn, 0, "current"), 1000)
  expect_identical(readBin(conn, "raw", 10), offline_bytes[1001:1010])

  expect_equal(seek(conn, 5, "current"), 1010)
  expect_equal(seek(conn, 0, "current"), 1015)
  expect_identical(readBin(conn, "raw", 5), offline_bytes[1016:1020])

  expect_equal(seek(conn, -20, "end"), 1020)
  expect_equal(seek(conn, 0, "current"), length(offline_bytes) - 20)
  expect_identical(readBin(conn, "raw", 20), offline_bytes[(length(offline_bytes) - 19):length(offline_bytes)])
})

test_that("a read past the end returns only the bytes that exist", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_equal(seek(conn, length(offline_bytes) - 10, "start"), 0)
  expect_equal(seek(conn, 0, "current"), length(offline_bytes) - 10)
  expect_identical(readBin(conn, "raw", 100), offline_bytes[(length(offline_bytes) - 9):length(offline_bytes)])
  expect_length(readBin(conn, "raw", 100), 0L)
})

test_that("a 3-byte file read with 4-byte items returns 0 items and consumes no bytes", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(as.raw(c(1, 2, 3)))
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_length(readBin(conn, "integer", 1, size = 4), 0L)
  expect_equal(seek(conn, 0, "current"), 0)
  expect_identical(readBin(conn, "raw", 3), as.raw(c(1, 2, 3)))
})

test_that("a memory-backed connection rejects seeks outside the file", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_error(seek(conn, -1, "start"), "outside the file")
  expect_equal(seek(conn, 0, "current"), 0)
  expect_error(seek(conn, length(offline_bytes) + 1, "start"), "outside the file")
  expect_equal(seek(conn, 0, "current"), 0)
})

test_that("the size of a memory-backed connection is its byte length", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  on.exit(tryCatch(close(conn), error = function(e) NULL), add = TRUE)

  expect_equal(seek(conn, 0, "end"), 0)
  expect_equal(seek(conn, 0, "current"), length(offline_bytes))
})

test_that("closing a memory-backed connection releases its reader early", {
  skip_if_not(is_compiled(), "Rust extension not available")
  h <- offline_conn(offline_bytes)
  conn <- h$conn
  id <- h$id

  expect_true(rxet_reader_is_open(id))
  close(conn)
  expect_false(rxet_reader_is_open(id))
})
