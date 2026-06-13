context("Utility functions for cache management and result handling")

describe("make_result", {
  it("returns success list with data", {
    result <- make_result(list(x = 1))
    expect_true(result$success)
    expect_equal(result$data$x, 1)
    expect_null(result$error)
  })

  it("returns error list with message", {
    result <- make_result(error = "Something failed")
    expect_false(result$success)
    expect_null(result$data)
    expect_equal(result$error, "Something failed")
  })
})

describe("format_action", {
  it("formats DOWNLOAD action", {
    action <- list(type = "DOWNLOAD", reason = "new")
    formatted <- format_action(action)
    expect_equal(formatted, "DOWNLOAD (new)")
  })

  it("formats SKIP action", {
    action <- list(type = "SKIP", reason = "no_changes")
    formatted <- format_action(action)
    expect_equal(formatted, "SKIP (no_changes)")
  })

  it("formats UPDATE action", {
    action <- list(type = "UPDATE", reason = "hash_changed")
    formatted <- format_action(action)
    expect_equal(formatted, "UPDATE (hash_changed)")
  })
})

describe("determine_action", {
  it("returns DOWNLOAD for new file", {
    action <- determine_action(file_exists = FALSE, hash_matches = FALSE, cached = NULL)
    expect_equal(action$type, "DOWNLOAD")
    expect_equal(action$reason, "new")
  })

  it("returns UPDATE for hash mismatch with cache", {
    action <- determine_action(
      file_exists = TRUE,
      hash_matches = FALSE,
      cached = list(hash = "old")
    )
    expect_equal(action$type, "UPDATE")
    expect_equal(action$reason, "hash_changed")
  })

  it("returns SKIP for matching hash", {
    action <- determine_action(
      file_exists = TRUE,
      hash_matches = TRUE,
      cached = list(hash = "same")
    )
    expect_equal(action$type, "SKIP")
    expect_equal(action$reason, "no_changes")
  })

  it("returns DOWNLOAD for unknown state", {
    action <- determine_action(
      file_exists = TRUE,
      hash_matches = FALSE,
      cached = NULL
    )
    expect_equal(action$type, "DOWNLOAD")
    expect_equal(action$reason, "unknown_state")
  })
})

describe("evict_old_cache", {
  it("returns empty cache unchanged", {
    cache <- list()
    result <- evict_old_cache(cache)
    expect_equal(length(result), 0)
  })

  it("keeps fresh entries", {
    cache <- list(
      entry1 = list(data = "x", downloaded_at = Sys.time()),
      entry2 = list(data = "y", downloaded_at = Sys.time())
    )
    result <- evict_old_cache(cache, ttl_days = 90)
    expect_equal(length(result), 2)
  })

  it("removes stale entries", {
    old_time <- as.POSIXct(Sys.time() - 100 * 86400)
    cache <- list(
      stale = list(data = "x", downloaded_at = old_time),
      fresh = list(data = "y", downloaded_at = Sys.time())
    )
    result <- evict_old_cache(cache, ttl_days = 90)
    expect_equal(length(result), 1)
    expect_named(result, "fresh")
  })

  it("handles entries without downloaded_at", {
    cache <- list(
      notime = list(data = "x"),
      withtime = list(data = "y", downloaded_at = Sys.time())
    )
    result <- evict_old_cache(cache, ttl_days = 90)
    expect_equal(length(result), 2)
  })
})

describe("evict_excess_cache", {
  it("returns cache unchanged if under limit", {
    cache <- list(entry1 = list(data = "x"), entry2 = list(data = "y"))
    result <- evict_excess_cache(cache, max_entries = 5)
    expect_equal(length(result), 2)
  })

  it("trims cache to max_entries", {
    cache <- setNames(
      lapply(1:10, function(i) list(data = paste0("entry", i), downloaded_at = Sys.time() - (11 - i) * 10)),
      paste0("entry", 1:10)
    )
    result <- evict_excess_cache(cache, max_entries = 5)
    expect_equal(length(result), 5)
  })

  it("keeps most recently accessed entries", {
    cache <- list(
      old = list(data = "x", downloaded_at = Sys.time() - 1000),
      recent = list(data = "y", downloaded_at = Sys.time())
    )
    result <- evict_excess_cache(cache, max_entries = 1)
    expect_named(result, "recent")
  })
})

describe("maintain_cache", {
  it("applies both TTL and size limits", {
    old_time <- as.POSIXct(Sys.time() - 100 * 86400)
    cache <- setNames(
      lapply(1:10, function(i) {
        list(
          data = paste0("entry", i),
          downloaded_at = if (i <= 2) old_time else Sys.time()
        )
      }),
      paste0("entry", 1:10)
    )

    result <- maintain_cache(cache, ttl_days = 90, max_entries = 5)

    # 2 stale entries should be removed (8 remain)
    # Then trim to top 5 by recency
    expect_equal(length(result), 5)
  })
})
