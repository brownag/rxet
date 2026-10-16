#' Read a raster file from Xet storage using terra
#'
#' Downloads a raster file from Xet storage and reads it with terra.
#' The whole file is buffered into memory before terra reads it.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the raster file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ext Optional extent to crop to (terra SpatExtent)
#' @param ... Additional arguments passed to `terra::rast()`
#'
#' @return A SpatRaster object
#'
#' @details
#' Uses the terra package (successor to raster) for reading raster files.
#'
#' ```r
#' dem <- read_xet_raster(client, "geotiff-hash", 2e9)
#' cropped <- terra::crop(dem, terra::ext(100, 110, 40, 50))
#' ```
#'
#' **Supported formats:**
#' - GeoTIFF (.tif, .tiff)
#' - COG (Cloud-Optimized GeoTIFF)
#' - HDF5 spatial data
#' - netCDF with spatial metadata
#'
#' **Status:** Experimental pending live evidence.
#'
#' @examples
#' \dontrun{
#' library(terra)
#'
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Read Copernicus DEM
#' dem <- read_xet_raster(
#'   client,
#'   file_hash = "copernicus-dem-hash",
#'   file_size = 4e9
#' )
#'
#' # Crop to region of interest
#' roi <- terra::ext(c(100, 105, 20, 25))  # lon/lat bounds
#' dem_roi <- terra::crop(dem, roi)
#'
#' # Resample to coarser resolution
#' dem_coarse <- terra::aggregate(dem_roi, 10)
#'
#' # Extract elevation profile
#' profile <- terra::extract(dem_roi, xy = matrix(c(102.5, 102.5, 22.5, 23.5), ncol = 2))
#' }
#'
#' @seealso [xet_stream_range()] for manual byte-range queries,
#'   `terra::rast()` for raster operations
#' @export
read_xet_raster <- function(handle, file_hash, file_size, ext = NULL, ...) {
  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("The 'terra' package is required. Install it with: install.packages('terra')")
  }

  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size > 0)

  conn <- xet_open_connection(handle, file_hash, file_size)
  bytes <- readBin(conn, "raw", file_size)
  close(conn)

  path <- tempfile()
  on.exit(unlink(path), add = TRUE)
  writeBin(bytes, path)

  rast <- terra::rast(path, ...)
  rast <- terra::unwrap(terra::wrap(rast))
  if (!is.null(ext)) {
    terra::crop(rast, ext)
  } else {
    rast
  }
}

#' Read a vector file from Xet storage using sf/GDAL
#'
#' Downloads a shapefile, GeoJSON, GeoPackage, or other vector format from Xet
#' storage and reads it with sf/GDAL. The whole file is buffered into memory
#' before sf reads it.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the vector file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ... Additional arguments passed to [sf::st_read()]
#'
#' @return An sf object (data frame with geometry column)
#'
#' @details
#' Supports any format that GDAL can read:
#' - Shapefiles (.shp, .dbf, .shx, etc.)
#' - GeoJSON (.geojson, .json)
#' - GeoPackage (.gpkg)
#' - KML (.kml)
#' - GML (.gml)
#' - OSM (.osm)
#' - And 80+ other formats
#'
#' **Status:** Experimental pending live evidence.
#'
#' @examples
#' \dontrun{
#' library(sf)
#'
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Read GeoJSON from Xet
#' boundaries <- read_xet_vector(
#'   client,
#'   file_hash = "geojson-countries-hash",
#'   file_size = 500e6
#' )
#'
#' # Plot
#' plot(boundaries)
#'
#' # Query
#' africa <- boundaries[boundaries$continent == "Africa", ]
#' }
#'
#' @seealso `sf::st_read()` for sf package details
#' @export
read_xet_vector <- function(handle, file_hash, file_size, ...) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("The 'sf' package is required. Install it with: install.packages('sf')")
  }

  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size > 0)

  conn <- xet_open_connection(handle, file_hash, file_size)
  bytes <- readBin(conn, "raw", file_size)
  close(conn)

  path <- tempfile()
  on.exit(unlink(path), add = TRUE)
  writeBin(bytes, path)

  sf::st_read(path, ...)
}
