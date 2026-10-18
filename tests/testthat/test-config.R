context("Per-client configuration arguments of xet_client_new()")

ep <- "https://cas-cf.huggingface.co"

test_that("timeout_sec rejects invalid values", {
  expect_error(xet_client_new(ep, "t", timeout_sec = -1), "timeout_sec")
  expect_error(xet_client_new(ep, "t", timeout_sec = 1.5), "timeout_sec")
  expect_error(xet_client_new(ep, "t", timeout_sec = Inf), "timeout_sec")
  expect_error(xet_client_new(ep, "t", timeout_sec = NA_real_), "timeout_sec")
  expect_error(xet_client_new(ep, "t", timeout_sec = "60"), "timeout_sec")
  expect_error(xet_client_new(ep, "t", timeout_sec = c(1, 2)), "timeout_sec")
})

test_that("cache_bytes rejects invalid values", {
  expect_error(xet_client_new(ep, "t", cache_bytes = -1), "cache_bytes")
  expect_error(xet_client_new(ep, "t", cache_bytes = 0.5), "cache_bytes")
  expect_error(xet_client_new(ep, "t", cache_bytes = NaN), "cache_bytes")
  expect_error(xet_client_new(ep, "t", cache_bytes = "1"), "cache_bytes")
})

test_that("high_perf rejects non-logical values", {
  expect_error(xet_client_new(ep, "t", high_perf = "yes"), "high_perf")
  expect_error(xet_client_new(ep, "t", high_perf = NA), "high_perf")
  expect_error(xet_client_new(ep, "t", high_perf = c(TRUE, FALSE)), "high_perf")
  expect_error(xet_client_new(ep, "t", high_perf = NULL), "high_perf")
})

test_that("valid configuration arguments create a client", {
  skip_if_not(is.loaded("wrap__xet_init_client"), "compiled extension not loaded")
  h <- xet_client_new(ep, "t", timeout_sec = 600, cache_bytes = 0, high_perf = TRUE)
  on.exit(xet_client_close(h))
  expect_type(h, "character")
  h2 <- xet_client_new(ep, "t", timeout_sec = NULL, cache_bytes = NULL)
  xet_client_close(h2)
})
