context("Arrow, spatial, and vector integrations")

test_that("read_xet_parquet validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not(requireNamespace("arrow", quietly = TRUE), "arrow not installed")
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

  # Validate parameter requirements
  expect_error(read_xet_parquet("", "hash", 1024), "nchar.*handle")
  expect_error(read_xet_parquet("client", "", 1024), "nchar.*file_hash")
  expect_error(read_xet_parquet("client", "hash", -1), "file_size")
})

test_that("read_xet_parquet handles nonexistent files gracefully", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not(requireNamespace("arrow", quietly = TRUE), "arrow not installed")
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

  with_test_client({
    # Should error when trying to stream a nonexistent file
    expect_error(
      read_xet_parquet(client, "fake_nonexistent_hash", 1024),
      "error|failed|not found"
    )
  })
})

test_that("read_xet_raster requires terra package", {
  skip_if_not(is_compiled())
  if (requireNamespace("terra", quietly = TRUE)) {
    skip("terra is installed; test needs it to be missing")
  }
  expect_error(
    read_xet_raster("client", "geotiff_hash", 1024),
    "terra.*required"
  )
})

test_that("read_xet_vector requires sf package", {
  skip_if_not(is_compiled())
  if (requireNamespace("sf", quietly = TRUE)) {
    skip("sf is installed; test needs it to be missing")
  }
  expect_error(
    read_xet_vector("client", "geojson_hash", 1024),
    "sf.*required"
  )
})
