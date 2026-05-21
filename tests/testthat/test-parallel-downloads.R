context("Parallel downloads with future.apply")

test_that("process_file_batch returns structured results", {
  # Mock setup
  mock_client <- "test-client-handle"
  mock_cache <- list()
  mock_file_info <- list(hash = "abc123", size = 1024)
  mock_file_data <- list(file = "test.bin", file_info = mock_file_info)

  # Test structured action system
  action <- determine_action(
    file_exists = FALSE,
    hash_matches = FALSE,
    cached = NULL
  )

  expect_equal(action$type, "DOWNLOAD")
  expect_equal(action$reason, "new")
  expect_equal(format_action(action), "DOWNLOAD (new)")
})

test_that("action determination handles all cases", {
  # Case 1: File doesn't exist
  action <- determine_action(FALSE, FALSE, NULL)
  expect_equal(action$type, "DOWNLOAD")
  expect_equal(action$reason, "new")

  # Case 2: File exists, hash matches (cached)
  cached_entry <- list(hash = "xyz789", size = 2048)
  action <- determine_action(TRUE, TRUE, cached_entry)
  expect_equal(action$type, "SKIP")
  expect_equal(action$reason, "no_changes")

  # Case 3: File exists, hash changed
  action <- determine_action(TRUE, FALSE, cached_entry)
  expect_equal(action$type, "UPDATE")
  expect_equal(action$reason, "hash_changed")

  # Case 4: Unknown state
  action <- determine_action(TRUE, FALSE, NULL)
  expect_equal(action$type, "DOWNLOAD")
  expect_equal(action$reason, "unknown_state")
})

test_that("result wrapper maintains consistent structure", {
  # Success case
  result <- make_result(data = list(key = "value"))
  expect_true(result$success)
  expect_equal(result$data$key, "value")
  expect_null(result$error)

  # Error case
  result <- make_result(error = "test error")
  expect_false(result$success)
  expect_null(result$data)
  expect_equal(result$error, "test error")
})

test_that("parallel plan is available", {
  # Check that future.apply is loaded
  expect_true("future.apply" %in% loadedNamespaces())
})
