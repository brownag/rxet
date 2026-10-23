stub_conn <- function(...) rawConnection(as.raw(1:5), "r")

test_that("connection mode passes the connection to the reader", {
  testthat::local_mocked_bindings(xet_open_connection = stub_conn, .package = "rxet")
  out <- rxet:::.rxet_whole_download("h", "abc", 5, function(conn) {
    expect_s3_class(conn, "connection")
    readBin(conn, "raw", 5)
  })
  expect_equal(out, as.raw(1:5))
})

test_that("connection mode closes the connection when the reader errors", {
  captured <- NULL
  testthat::local_mocked_bindings(
    xet_open_connection = function(...) {
      captured <<- stub_conn()
      captured
    },
    .package = "rxet"
  )
  expect_error(rxet:::.rxet_whole_download("h", "abc", 5, function(conn) stop("boom")), "boom")
  expect_error(isOpen(captured))
})

test_that("file mode passes a temp path with bytes and removes it", {
  testthat::local_mocked_bindings(xet_open_connection = stub_conn, .package = "rxet")
  seen <- NULL
  out <- rxet:::.rxet_whole_download("h", "abc", 5, function(path) {
    seen <<- path
    expect_true(file.exists(path))
    expect_match(path, "\\.tif$")
    readBin(path, "raw", 10)
  }, ext = "tif", via = "file")
  expect_equal(out, as.raw(1:5))
  expect_false(file.exists(seen))

  seen <- NULL
  expect_error(rxet:::.rxet_whole_download("h", "abc", 5, function(path) {
    seen <<- path
    stop("bad")
  }, via = "file"), "bad")
  expect_false(file.exists(seen))
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
  expect_error(rxet:::.rxet_whole_download("", "abc", 5, identity), "handle")
  expect_error(rxet:::.rxet_whole_download("h", "", 5, identity), "file_hash")
  expect_error(rxet:::.rxet_whole_download("h", "abc", -1, identity), "file_size")
  expect_error(rxet:::.rxet_whole_download("h", "abc", 2^31, identity), "2 GiB limit")
  expect_false(called)
})
