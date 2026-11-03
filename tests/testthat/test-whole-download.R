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

test_that("invalid arguments error before the connection is opened", {
  called <- FALSE
  testthat::local_mocked_bindings(
    xet_open_connection = function(...) {
      called <<- TRUE
      stub_conn()
    },
    .package = "rxet"
  )
  expect_error(.rxet_whole_download("", "abc", 5, identity), "handle")
  expect_error(.rxet_whole_download("h", "", 5, identity), "file_hash")
  expect_error(.rxet_whole_download("h", "abc", -1, identity), "file_size")
  expect_error(.rxet_whole_download("h", "abc", 1.5, identity), "file_size")
  expect_false(called)
})
