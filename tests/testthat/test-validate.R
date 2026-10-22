test_that("check_handle and check_hash reject bad strings", {
  bad <- list("", NA_character_, 1, c("a", "b"), NULL)
  for (b in bad) {
    expect_error(rxet:::check_handle(b), "handle")
    expect_error(rxet:::check_hash(b), "file_hash")
  }
  expect_error(rxet:::check_hash("", "hash"), "`hash`")
  expect_silent(rxet:::check_handle("abc"))
  expect_silent(rxet:::check_hash("abc"))
})

test_that("handle value is never echoed", {
  expect_false(grepl("secret-token", tryCatch(rxet:::check_handle(c("secret-token", "x")), error = conditionMessage)))
})

test_that("check_file_size", {
  expect_silent(rxet:::check_file_size(0))
  for (b in list(-1, 1.5, Inf, NaN, "big", c(1, 2))) {
    expect_error(rxet:::check_file_size(b))
  }
  expect_error(rxet:::check_file_size(2^31, in_memory = TRUE), "2 GiB limit")
  expect_silent(rxet:::check_file_size(2^31, in_memory = FALSE))
})

test_that("check_range", {
  expect_silent(rxet:::check_range(0, 10, 10))
  expect_error(rxet:::check_range(5, 5, 10), "greater")
  expect_error(rxet:::check_range(0, 11, 10), "exceed")
  expect_error(rxet:::check_range(-1, 5, 10), ">= 0")
  expect_error(rxet:::check_range(0, 2^31 + 5, 2^32), "2 GiB limit")
})

test_that("check_string and require_pkg", {
  expect_silent(rxet:::check_string("a", "dest_path"))
  expect_error(rxet:::check_string(NA_character_, "dest_path"), "dest_path")
  expect_error(rxet:::check_string(1, "src_path"), "src_path")
  expect_error(
    rxet:::require_pkg("definitelynotapkg", "f"),
    "The 'definitelynotapkg' package is required for f\\(\\)"
  )
})
