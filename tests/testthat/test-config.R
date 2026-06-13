context("Configuration via xet_config_environment()")

test_that("xet_config_environment sets HF_XET_CLIENT_READ_TIMEOUT", {
  xet_config_environment(timeout_sec = 600)
  expect_equal(Sys.getenv("HF_XET_CLIENT_READ_TIMEOUT"), "600")
})

test_that("xet_config_environment sets HF_XET_CHUNK_CACHE_SIZE_BYTES", {
  xet_config_environment(cache_bytes = 2e9)
  expect_equal(Sys.getenv("HF_XET_CHUNK_CACHE_SIZE_BYTES"), "2000000000")
})

test_that("xet_config_environment sets HF_XET_HIGH_PERFORMANCE to 1", {
  xet_config_environment(high_perf = TRUE)
  expect_equal(Sys.getenv("HF_XET_HIGH_PERFORMANCE"), "1")
})

test_that("xet_config_environment unsets HF_XET_HIGH_PERFORMANCE when high_perf=FALSE", {
  xet_config_environment(high_perf = TRUE)
  expect_equal(Sys.getenv("HF_XET_HIGH_PERFORMANCE"), "1")

  xet_config_environment(high_perf = FALSE)
  expect_equal(Sys.getenv("HF_XET_HIGH_PERFORMANCE"), "")
})

test_that("xet_config_environment returns NULL invisibly", {
  result <- xet_config_environment()
  expect_null(result)
})

test_that("xet_config_environment applies defaults", {
  # Reset env vars
  Sys.unsetenv("HF_XET_CLIENT_READ_TIMEOUT")
  Sys.unsetenv("HF_XET_CHUNK_CACHE_SIZE_BYTES")
  Sys.unsetenv("HF_XET_HIGH_PERFORMANCE")

  xet_config_environment()

  expect_equal(Sys.getenv("HF_XET_CLIENT_READ_TIMEOUT"), "300")
  expect_equal(Sys.getenv("HF_XET_CHUNK_CACHE_SIZE_BYTES"), "10000000000")
  expect_equal(Sys.getenv("HF_XET_HIGH_PERFORMANCE"), "")
})

test_that("xet_config_environment accepts mixed parameters", {
  xet_config_environment(timeout_sec = 1200, cache_bytes = 5e9, high_perf = TRUE)
  expect_equal(Sys.getenv("HF_XET_CLIENT_READ_TIMEOUT"), "1200")
  expect_equal(Sys.getenv("HF_XET_CHUNK_CACHE_SIZE_BYTES"), "5000000000")
  expect_equal(Sys.getenv("HF_XET_HIGH_PERFORMANCE"), "1")
})
