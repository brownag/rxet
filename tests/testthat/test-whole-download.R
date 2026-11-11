stub_conn <- function(...) rawConnection(as.raw(1:5), "r")

test_that("stream mode passes the connection to the reader", {
  testthat::local_mocked_bindings(xet_open_stream_connection = stub_conn, .package = "rxet")
  out <- .rxet_whole_download("h", "abc", 5, function(conn) {
    expect_s3_class(conn, "connection")
    readBin(conn, "raw", 5)
  })
  expect_equal(out, as.raw(1:5))
})

test_that("stream mode closes the connection when the reader errors", {
  captured <- NULL
  testthat::local_mocked_bindings(
    xet_open_stream_connection = function(...) {
      captured <<- stub_conn()
      captured
    },
    .package = "rxet"
  )
  expect_error(.rxet_whole_download("h", "abc", 5, function(conn) stop("boom")), "boom")
  expect_error(isOpen(captured))
})

test_that("file mode downloads to a temp path and removes it", {
  testthat::local_mocked_bindings(
    xet_download_file = function(handle, hash, file_size, dest_path) {
      writeBin(as.raw(1:5), dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )
  seen <- NULL
  out <- .rxet_whole_download("h", "abc", 5, function(path) {
    seen <<- path
    expect_true(file.exists(path))
    expect_match(path, "\\.tif$")
    readBin(path, "raw", 10)
  }, ext = "tif", via = "file")
  expect_equal(out, as.raw(1:5))
  expect_false(file.exists(seen))

  seen <- NULL
  expect_error(.rxet_whole_download("h", "abc", 5, function(path) {
    seen <<- path
    stop("bad")
  }, via = "file"), "bad")
  expect_false(file.exists(seen))
})

test_that("whole-download stream mode passes a seekable connection to the reader", {
  testthat::local_mocked_bindings(
    xet_open_stream_connection = function(...) rawConnection(as.raw(1:5), "r"),
    .package = "rxet"
  )
  out <- .rxet_whole_download("h", "abc", 5, function(conn) {
    expect_s3_class(conn, "connection")
    readBin(conn, "raw", 5)
  }, via = "stream")
  expect_equal(out, as.raw(1:5))
})

test_that("stream mode delegates validation and opens the public stream connection", {
  called <- FALSE
  testthat::local_mocked_bindings(
    xet_open_stream_connection = function(handle, file_hash, file_size) {
      called <<- TRUE
      .rxet_check_handle(handle)
      .rxet_check_hash(file_hash)
      .rxet_check_file_size(file_size)
      stub_conn()
    },
    .package = "rxet"
  )
  out <- .rxet_whole_download("h", "abc", 5, function(conn) readBin(conn, "raw", 5))
  expect_equal(out, as.raw(1:5))
  expect_true(called)
})

test_that("file mode with dest_path downloads to dest_path and does not unlink", {
  testthat::local_mocked_bindings(
    xet_download_file = function(handle, hash, file_size, dest_path) {
      writeBin(as.raw(1:5), dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )
  target <- tempfile(fileext = ".bin")
  on.exit(if (file.exists(target)) unlink(target), add = TRUE)

  out <- .rxet_whole_download(
    "h", "abc", 5,
    reader = function(path) {
      expect_equal(path, target)
      readBin(path, "raw", 10)
    },
    dest_path = target,
    via = "file"
  )
  expect_equal(out, as.raw(1:5))
  expect_true(file.exists(target))
})

test_that("file mode with keep = TRUE does not unlink temp file on exit", {
  testthat::local_mocked_bindings(
    xet_download_file = function(handle, hash, file_size, dest_path) {
      writeBin(as.raw(1:5), dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )
  seen <- NULL
  out <- .rxet_whole_download(
    "h", "abc", 5,
    reader = function(path) {
      seen <<- path
      readBin(path, "raw", 10)
    },
    keep = TRUE,
    via = "file"
  )
  on.exit(if (!is.null(seen) && file.exists(seen)) unlink(seen), add = TRUE)
  expect_equal(out, as.raw(1:5))
  expect_true(file.exists(seen))
})

test_that("file mode with keep = TRUE removes temp file if reader fails", {
  testthat::local_mocked_bindings(
    xet_download_file = function(handle, hash, file_size, dest_path) {
      writeBin(as.raw(1:5), dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )
  seen <- NULL
  expect_error(
    .rxet_whole_download(
      "h", "abc", 5,
      reader = function(path) {
        seen <<- path
        stop("reader exploded")
      },
      keep = TRUE,
      via = "file"
    ),
    "reader exploded"
  )
  expect_false(file.exists(seen))
})
