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

test_that("read_xet_parquet returns the data frame written by make_fixtures.R", {
  skip_without_local_cas()
  skip_if_not_installed("arrow")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.parquet")

  expected <- arrow::read_parquet(fixture_path("small.parquet"))
  expect_equal(read_xet_parquet(client, info$hash, info$file_size), expected)
})

test_that("read_xet_parquet_stream returns the data frame written by make_fixtures.R", {
  skip_without_local_cas()
  skip_if_not_installed("arrow")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.parquet")

  expected <- arrow::read_parquet(fixture_path("small.parquet"))
  expect_equal(read_xet_parquet_stream(client, info$hash, info$file_size), expected)
})

test_that("xet_open_connection bytes equal the downloaded fixture bytes", {
  skip_without_local_cas()
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.parquet")

  conn <- xet_open_connection(client, info$hash, info$file_size)
  on.exit(close(conn), add = TRUE)
  streamed <- readBin(conn, "raw", as.integer(info$file_size))

  dest <- tempfile(fileext = ".parquet")
  on.exit(unlink(dest), add = TRUE)
  xet_download_file(client, info$hash, info$file_size, dest)
  expect_identical(streamed, readBin(dest, "raw", file.size(dest)))
  expect_identical(info$file_size, as.numeric(file.size(fixture_path("small.parquet"))))
})

test_that("read_xet_parquet refuses a file above the 2 GiB cap and names xet_download_file", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("arrow")

  # Refused in xet_open_connection before any client work or network call.
  expect_error(
    read_xet_parquet("dummy-handle", "dummy-hash", 2^31 + 1),
    "2 GiB.*xet_download_file"
  )
})

test_that("read_xet_raster returns the 16x16 GeoTIFF with the generator's values", {
  skip_without_local_cas()
  skip_if_not_installed("terra")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.tif")

  before <- list.files(tempdir(), full.names = TRUE)
  r <- read_xet_raster(client, info$hash, info$file_size)
  after <- list.files(tempdir(), full.names = TRUE)

  # Values are read after the call returns: the helper unlinks its temp file
  # on exit, so this also proves the raster was loaded into memory.
  expect_s4_class(r, "SpatRaster")
  expect_equal(c(terra::nrow(r), terra::ncol(r), terra::nlyr(r)), c(16, 16, 1))
  expect_equal(terra::crs(r, describe = TRUE)$code, "32633")

  # make_fixtures.R assigns round(runif(256), 4) with terra::values<-, which
  # fills cells 1..256 in order (row-major from the top-left).
  set.seed(20260102L)
  expected <- round(runif(256), 4)
  expect_equal(as.numeric(terra::values(r)[, 1]), expected, tolerance = 1e-6)

  expect_length(setdiff(after, before), 0)
})

test_that("read_xet_vector returns the three-feature GeoJSON fixture", {
  skip_without_local_cas()
  skip_if_not_installed("sf")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.geojson")

  before <- list.files(tempdir(), full.names = TRUE)
  v <- read_xet_vector(client, info$hash, info$file_size)
  after <- list.files(tempdir(), full.names = TRUE)

  expect_s3_class(v, "sf")
  expect_equal(nrow(v), 3L)
  expect_equal(nrow(v), nrow(sf::st_read(fixture_path("small.geojson"), quiet = TRUE)))
  expect_length(setdiff(after, before), 0)
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
