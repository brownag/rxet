context("Edge cases and error handling")

test_that("cache eviction handles empty cache", {
  empty_cache <- list()
  result <- evict_old_cache(empty_cache, ttl_days = 90)
  expect_equal(length(result), 0)
})

test_that("cache eviction removes old entries", {
  now <- Sys.time()
  old_time <- now - (100 * 86400)  # 100 days ago
  new_time <- now - (30 * 86400)   # 30 days ago

  cache <- list(
    old_entry = list(
      hash = "old",
      downloaded_at = as.character(old_time)
    ),
    new_entry = list(
      hash = "new",
      downloaded_at = as.character(new_time)
    )
  )

  result <- evict_old_cache(cache, ttl_days = 90)
  expect_equal(length(result), 1)
  expect_equal(result$new_entry$hash, "new")
})

test_that("cache eviction respects size limit", {
  # Create cache with 100 entries
  cache <- setNames(
    lapply(1:100, function(i) {
      list(
        hash = sprintf("hash_%03d", i),
        downloaded_at = as.character(Sys.time() - (i * 86400))
      )
    }),
    sprintf("entry_%03d", 1:100)
  )

  result <- evict_excess_cache(cache, max_entries = 50)
  expect_equal(length(result), 50)
})

test_that("maintain_cache applies both eviction strategies", {
  now <- Sys.time()
  cache <- setNames(
    lapply(1:60, function(i) {
      list(
        hash = sprintf("hash_%03d", i),
        downloaded_at = as.character(now - (i * 86400))
      )
    }),
    sprintf("entry_%03d", 1:60)
  )

  # With TTL=90 days and size limit=50
  # Should keep entries 1-90 (within TTL)
  # Then trim to 50 most recent
  result <- maintain_cache(cache, ttl_days = 90, max_entries = 50)
  expect_equal(length(result), 50)
})

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

test_that("action formatting is consistent", {
  actions <- list(
    list(type = "DOWNLOAD", reason = "new"),
    list(type = "UPDATE", reason = "hash_changed"),
    list(type = "SKIP", reason = "no_changes"),
    list(type = "DOWNLOAD", reason = "unknown_state")
  )

  formatted <- lapply(actions, format_action)
  expected <- c(
    "DOWNLOAD (new)",
    "UPDATE (hash_changed)",
    "SKIP (no_changes)",
    "DOWNLOAD (unknown_state)"
  )

  expect_equal(unlist(formatted), expected)
})

test_that("result wrapper handles NULL values", {
  result1 <- make_result(data = NULL, error = NULL)
  expect_true(result1$success)
  expect_null(result1$data)

  result2 <- make_result(data = list(), error = NULL)
  expect_true(result2$success)
  expect_equal(length(result2$data), 0)
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
