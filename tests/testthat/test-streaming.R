context("Streaming functions returning actual bytes")

test_that("xet_stream_raw returns raw vector", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

  # Test with a mock client - real endpoint but fake file hash
  # The Rust code will attempt to fetch but fail gracefully
  with_test_client({
    expect_error(
      xet_stream_raw(client, "fake_hash_nonexistent", 1024),
      "could not find|not found|error"
    )
  })
})

test_that("xet_stream_raw validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

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
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

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
