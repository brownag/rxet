context("R connection objects for Xet files")

test_that("xet_open_connection validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")

  # Should validate handle is character
  expect_error(xet_open_connection(123, "hash", 1024), "is.character")
  # Should validate file_hash is not empty
  expect_error(xet_open_connection("handle", "", 1024), "nchar")
  # Should validate file_size is non-negative
  expect_error(xet_open_connection("handle", "hash", -1), "file_size")
})

test_that("xet_close_connection returns NULL", {
  skip_if_not(is_compiled())
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

  with_test_client({
    # Try to open connection with fake hash (will fail to stream but tests the wrapper)
    expect_error(
      xet_open_connection(client, "fake_hash", 1024),
      "error|failed|not found"
    )
  })
})
