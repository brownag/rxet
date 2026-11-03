context("Arrow, spatial, and vector integrations")

test_that("read_xet_parquet validates input parameters", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not(requireNamespace("arrow", quietly = TRUE), "arrow not installed")
  skip_if(nchar(Sys.getenv("HF_TOKEN")) == 0, "HF_TOKEN not set")

  # Validate parameter requirements
  expect_error(read_xet_parquet("", "hash", 1024), "handle")
  expect_error(read_xet_parquet("client", "", 1024), "file_hash")
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

test_that("read_xet_parquet closes its connection on success", {
  skip_without_local_cas()
  skip_if_not_installed("arrow")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.parquet")

  captured <- NULL
  real_open <- xet_open_connection
  testthat::local_mocked_bindings(
    xet_open_connection = function(handle, file_hash, file_size) {
      captured <<- real_open(handle, file_hash, file_size)
      captured
    },
    .package = "rxet"
  )

  expected <- arrow::read_parquet(fixture_path("small.parquet"))
  expect_equal(read_xet_parquet(client, info$hash, info$file_size), expected)
  expect_true(inherits(captured, "connection"))
  # A closed R connection makes isOpen() error "invalid connection"; that is
  # the closed state. Any other error is re-raised.
  closed <- tryCatch(!isOpen(captured), error = function(e) {
    if (grepl("invalid connection", conditionMessage(e))) TRUE else stop(e)
  })
  expect_true(closed)
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

test_that("read_xet_vector accepts ext and returns the three-feature GeoJSON fixture", {
  skip_without_local_cas()
  skip_if_not_installed("sf")
  client <- start_fixture_client()
  info <- serve_fixture(client, "small.geojson")

  v <- read_xet_vector(client, info$hash, info$file_size, ext = "geojson")

  expect_s3_class(v, "sf")
  expect_equal(nrow(v), 3L)
})

test_that("read_xet_vector rejects ext with a dot before any download", {
  skip_if_not_installed("sf")
  expect_error(
    read_xet_vector("client", "geojson_hash", 1024, ext = "geo.json"),
    "ext"
  )
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

test_that("read_xet_raster and read_xet_vector remove their temp file when the reader errors", {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")

  before <- list.files(tempdir(), full.names = TRUE)
  testthat::local_mocked_bindings(
    xet_download_file = function(handle, hash, file_size, dest_path) {
      writeBin(as.raw(1:5), dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )

  # Five bytes are not a raster or a vector file, so the readers error.
  expect_error(read_xet_raster("h", "x", 5))
  expect_error(read_xet_vector("h", "x", 5))
  expect_setequal(list.files(tempdir(), full.names = TRUE), before)
})

test_that("file_size = 0 reaches the reader and fails there, not at argument validation", {
  testthat::local_mocked_bindings(
    xet_open_connection = function(...) rawConnection(raw(0), "r"),
    xet_download_file = function(handle, hash, file_size, dest_path) {
      file.create(dest_path)
      invisible(dest_path)
    },
    .package = "rxet"
  )
  not_arg <- function(expr) {
    msg <- tryCatch({ expr; "" }, error = conditionMessage)
    expect_true(nzchar(msg))
    expect_false(grepl("file_size", msg))
  }
  skip_if_not_installed("arrow")
  not_arg(read_xet_parquet("h", "abc", 0))
  skip_if_not_installed("terra")
  not_arg(read_xet_raster("h", "abc", 0))
  skip_if_not_installed("sf")
  not_arg(read_xet_vector("h", "abc", 0))
})
