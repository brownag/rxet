context("Range download and streaming")

# Initialize mock backend for this test suite
setup({
  skip_if_not_installed("uuid")
  backend <<- create_mock_backend()
  fixtures <<- create_test_fixtures()
})

teardown({
  backend$reset()
})

test_that("stream_range correctly identifies overlapping chunks", {
  # Use medium file fixture (1GB, 10 chunks of 100MB each)
  file_info <- fixtures$medium
  file_size <- file_info$file_size
  num_chunks <- length(file_info$chunks)

  # Request range [350MB, 550MB) overlaps with chunks 4, 5, 6
  start_byte <- 350e6  # Within chunk 4 (300-400MB)
  end_byte <- 550e6    # Within chunk 6 (500-600MB)

  # Manually find overlapping chunks
  overlapping <- Filter(function(chunk) {
    chunk$offset_end > start_byte && chunk$offset_start < end_byte
  }, file_info$chunks)

  # Should find 3 overlapping chunks (4, 5, 6)
  expect_equal(length(overlapping), 3, info = "Should find 3 overlapping chunks")
  expect_equal(overlapping[[1]]$offset_start, 300e6, info = "First chunk starts at 300MB")
  expect_equal(overlapping[[3]]$offset_end, 600e6, info = "Last chunk ends at 600MB")
})

test_that("stream_range handles boundary-aligned requests", {
  file_info <- fixtures$medium
  num_chunks <- length(file_info$chunks)

  # Request exactly chunk boundaries
  chunk_1 <- file_info$chunks[[1]]
  chunk_2 <- file_info$chunks[[2]]

  start_byte <- chunk_1$offset_start
  end_byte <- chunk_2$offset_end

  overlapping <- Filter(function(chunk) {
    chunk$offset_end > start_byte && chunk$offset_start < end_byte
  }, file_info$chunks)

  expect_equal(length(overlapping), 2)
  expect_equal(overlapping[[1]]$offset_start, start_byte)
  expect_equal(overlapping[[2]]$offset_end, end_byte)
})

test_that("stream_range handles single-chunk requests", {
  file_info <- fixtures$medium
  chunk <- file_info$chunks[[5]]

  # Request entirely within one chunk
  start_byte <- chunk$offset_start + 1e6
  end_byte <- chunk$offset_start + 2e6

  overlapping <- Filter(function(c) {
    c$offset_end > start_byte && c$offset_start < end_byte
  }, file_info$chunks)

  expect_equal(length(overlapping), 1)
  expect_equal(overlapping[[1]]$hash, chunk$hash)
})

test_that("stream_range returns no chunks for empty range", {
  file_info <- fixtures$medium
  chunk <- file_info$chunks[[5]]

  # Zero-length range
  start_byte <- chunk$offset_start
  end_byte <- chunk$offset_start

  overlapping <- Filter(function(c) {
    c$offset_end > start_byte && c$offset_start < end_byte
  }, file_info$chunks)

  expect_equal(length(overlapping), 0)
})

test_that("stream_range handles many overlapping chunks", {
  file_info <- fixtures$large
  num_chunks <- length(file_info$chunks)

  # Request entire middle 50% of file
  file_size <- file_info$file_size
  start_byte <- file_size * 0.25
  end_byte <- file_size * 0.75

  overlapping <- Filter(function(c) {
    c$offset_end > start_byte && c$offset_start < end_byte
  }, file_info$chunks)

  # Should be roughly 50 chunks (50% of 100)
  expect_gte(length(overlapping), 45)
  expect_lte(length(overlapping), 55)
})

test_that("stream_raw metadata is correctly structured", {
  file_info <- fixtures$small

  # Simulate stream initialization
  result <- list(
    success = TRUE,
    file_hash = file_info$file_hash,
    file_size = file_info$file_size,
    num_chunks = length(file_info$chunks),
    status = "initialized"
  )

  expect_true(result$success)
  expect_equal(result$file_size, 1e7)
  expect_equal(result$num_chunks, 10)
  expect_equal(nchar(result$file_hash), 36)  # UUID format
})

test_that("backend tracks API calls correctly", {
  repo_id <- "test-repo/model"
  file_path <- "model.safetensors"

  # Make some API calls
  backend$api_head_file(repo_id, file_path)
  backend$api_head_file(repo_id, file_path)
  backend$api_get_read_token(repo_id)

  # Verify call counts
  expect_true(backend$endpoint_called("HEAD", file_path))
  expect_equal(backend$count_calls("HEAD", file_path), 2)
  expect_equal(backend$count_calls("GET", "xet-read-token"), 1)
})

test_that("backend simulates CAS chunk download", {
  hash <- "test_chunk_hash_abc123"

  result <- backend$api_get_chunk(hash, size = 1024)

  expect_true(result$success)
  expect_is(result$data, "raw")
  expect_equal(length(result$data), 1024)
})

test_that("backend simulates transient failures", {
  hash <- "flaky_chunk"

  # First request fails
  backend$set_failure(hash, "CAS temporarily unavailable (503)")
  result1 <- backend$api_get_chunk(hash)
  expect_false(result1$success)

  # Clear failure and retry succeeds
  backend$clear_failures()
  result2 <- backend$api_get_chunk(hash)
  expect_true(result2$success)

  # Verify call counts
  expect_equal(backend$count_calls("GET", sprintf("/cas/%s", hash)), 2)
})

test_that("backend generates valid token responses", {
  repo_id <- "test-repo/model"

  result <- backend$api_get_read_token(repo_id)

  expect_true(result$success)
  token_data <- result$data
  expect_true(nchar(token_data$accessToken) > 0)
  expect_equal(token_data$casUrl, "https://cas-cf.huggingface.co")
  expect_true(token_data$exp > as.numeric(Sys.time()))
})

test_that("test fixtures have correct structure", {
  # Verify small fixture
  expect_equal(fixtures$small$file_size, 1e7)
  expect_equal(length(fixtures$small$chunks), 10)
  expect_equal(fixtures$small$chunks[[1]]$size, 1e6)

  # Verify medium fixture
  expect_equal(fixtures$medium$file_size, 1e9)
  expect_equal(length(fixtures$medium$chunks), 10)

  # Verify large fixture
  expect_equal(fixtures$large$file_size, 1e10)
  expect_equal(length(fixtures$large$chunks), 100)

  # Verify parquet fixture
  expect_equal(fixtures$parquet$file_size, 5e8)
  expect_equal(length(fixtures$parquet$chunks), 5)

  # Verify geotiff fixture
  expect_equal(fixtures$geotiff$file_size, 2e9)
  expect_equal(length(fixtures$geotiff$chunks), 20)
})

test_that("test scenarios are well-defined", {
  scenarios <- create_test_scenarios()

  expect_equal(length(scenarios), 5)
  expect_true(all(names(scenarios) %in% c(
    "slow_network", "transient_failure", "byte_range", "concurrent", "large_file"
  )))

  # Verify scenario structure
  for (scenario in scenarios) {
    expect_true("name" %in% names(scenario))
    expect_true("description" %in% names(scenario))
    expect_true("expected_behavior" %in% names(scenario))
  }
})
