test_that(".rxet_check_handle and .rxet_check_hash reject bad strings", {
  bad <- list("", NA_character_, 1, c("a", "b"), NULL)
  for (b in bad) {
    expect_error(.rxet_check_handle(b), "handle")
    expect_error(.rxet_check_hash(b), "file_hash")
  }
  expect_error(.rxet_check_hash("", "hash"), "`hash`")
  expect_silent(.rxet_check_handle("abc"))
  expect_silent(.rxet_check_hash("abc"))
})

test_that("handle value is never echoed", {
  expect_false(grepl("secret-token", tryCatch(.rxet_check_handle(c("secret-token", "x")), error = conditionMessage)))
})

test_that(".rxet_check_file_size", {
  expect_silent(.rxet_check_file_size(0))
  for (b in list(-1, 1.5, Inf, NaN, "big", c(1, 2))) {
    expect_error(.rxet_check_file_size(b))
  }
  expect_silent(.rxet_check_file_size(2^31 + 5))
})

test_that(".rxet_check_range", {
  expect_silent(.rxet_check_range(0, 10, 10))
  expect_error(.rxet_check_range(5, 5, 10), "greater")
  expect_error(.rxet_check_range(0, 11, 10), "exceed")
  expect_error(.rxet_check_range(-1, 5, 10), ">= 0")
  expect_silent(.rxet_check_range(0, 2^31 + 5, 2^32))
})

test_that("xet_stream_range rejects an empty range before the Rust call (R layer)", {
  # R rule: end_byte <= start_byte is an error. Pinned by user decision (G4).
  expect_error(xet_stream_range("h", "abc", 10, 5, 5), "greater")
})

test_that("G4: Rust xet_stream_range empty-range rule", {
  skip("G4: empty-range rule disagreement, see EXECUTION_PLAN_13 D5")
})

test_that(".rxet_check_string and .rxet_require_pkg", {
  expect_silent(.rxet_check_string("a", "dest_path"))
  expect_error(.rxet_check_string(NA_character_, "dest_path"), "dest_path")
  expect_error(.rxet_check_string(1, "src_path"), "src_path")
  expect_error(
    .rxet_require_pkg("definitelynotapkg", "f"),
    "The 'definitelynotapkg' package is required for f\\(\\)"
  )
})
