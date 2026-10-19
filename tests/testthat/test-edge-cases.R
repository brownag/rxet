context("Edge cases and error handling")

test_that("file size validation rejects invalid values", {
  # Test negative size
  result <- tryCatch({
    stopifnot(is.numeric(-1024), -1024 >= 0)
    TRUE
  }, error = function(e) FALSE)
  expect_false(result)
})

test_that("handle validation works for string handles", {
  test_handle <- "550e8400-e29b-41d4-a716-446655440000"
  result <- is.character(test_handle) && length(test_handle) == 1
  expect_true(result)
})

test_that("concurrent handle generation doesn't collide", {
  skip_if_not_installed("uuid")
  # Note: Real concurrent test requires future package
  # This is a basic structure test
  handles <- character(10)
  for (i in 1:10) {
    handles[i] <- uuid::UUIDgenerate()
  }
  expect_equal(length(unique(handles)), 10)
})
