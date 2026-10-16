context("Streaming functions returning actual bytes")

test_that("live xet_stream_raw returns the public parquet bytes (RXET_LIVE_TESTS)", {
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
  got <- xet_stream_raw(client, "4e99cb45a4ad980707548c95f5cc3dadb91e36889c68adbff641e56c53981331", 2931)
  expect_length(got, 2931L)
  expect_identical(digest::digest(got, algo = "sha256", serialize = FALSE),
                   "c25ed568c3f701e640a6d9db7495b8d989ee2f6dbaf3fc0ad2216c6d5cd28bf4")
})

test_that("xet_stream_raw validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")

  with_test_client({
    # Empty hash should be caught by R validation
    expect_error(
      xet_stream_raw(client, "", 1024),
      "nchar"
    )
    # Negative size should be caught
    expect_error(
      xet_stream_raw(client, "abc123", -1),
      "file_size"
    )
  })
})

test_that("xet_stream_range validates byte range parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")

  with_test_client({
    # end_byte must be > start_byte
    expect_error(
      xet_stream_range(client, "abc123", 1000, 500, 400),
      "end_byte.*start_byte"
    )
    # end_byte cannot exceed file_size
    expect_error(
      xet_stream_range(client, "abc123", 1000, 100, 2000),
      "end_byte.*file_size"
    )
  })
})
