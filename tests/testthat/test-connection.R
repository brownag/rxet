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

test_that("live connection reads the public parquet and closes (RXET_LIVE_TESTS)", {
  skip_if_not(identical(Sys.getenv("RXET_LIVE_TESTS"), "1"), "live tests are opt-in: set RXET_LIVE_TESTS=1")
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("digest")

  # Private HF_HOME so the developer's shard cache is not touched (see test-live-hf.R).
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  hf_home <- tempfile("hf_home_")
  Sys.setenv(HF_HOME = hf_home)
  on.exit(unlink(hf_home, recursive = TRUE), add = TRUE)
  on.exit(if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home), add = TRUE)

  client <- xet_client_new("https://cas-server.xethub.hf.co", live_cas_token())
  on.exit(xet_client_close(client), add = TRUE)

  # Same constants as test-live-hf.R (LIVE_HASH, LIVE_SIZE, LIVE_SHA256).
  live_hash <- "4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331"
  conn <- xet_open_connection(client, live_hash, 2931)
  got <- readBin(conn, "raw", 2931L)
  expect_length(got, 2931L)
  expect_identical(digest::digest(got, algo = "sha256", serialize = FALSE),
                   "c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4")
  expect_null(xet_close_connection(conn))
})
