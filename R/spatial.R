#' Read a raster file from Xet storage using terra
#'
#' Downloads a raster file from Xet storage and reads it with terra.
#' The whole file is downloaded before terra reads it, so this is a
#' whole-download helper.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the raster file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ... Additional arguments passed to `terra::rast()`
#'
#' @return A SpatRaster object
#'
#' @details
#' Uses the terra package (successor to raster) for reading raster files.
#'
#' **Whole-download:** the file is downloaded into memory and written to a
#' temporary file. terra reads it, and all values are loaded into memory
#' (`terra::unwrap(terra::wrap(...))`) before the temporary file is removed.
#' The whole file is read into memory, which holds about one copy of the
#' bytes, and a parsed raster is returned.
#'
#' **2 GiB limit:** files larger than 2 GiB (2147483647 bytes) are refused by
#' [xet_open_connection()] before any network call. The error names
#' `xet_download_file()`.
#'
#' **Optional package:** `terra` is in Suggests and is checked with
#' `requireNamespace()`.
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
read_xet_raster <- function(handle, file_hash, file_size, ...) {
  .rxet_require_pkg("terra", "read_xet_raster")

  .rxet_whole_download(
    handle, file_hash, file_size,
    reader = function(path) terra::unwrap(terra::wrap(terra::rast(path, ...))),
    via = "file"
  )
}

#' Read a vector file from Xet storage using sf/GDAL
#'
#' Downloads a GeoJSON, GeoPackage, or other single-file vector format from Xet
#' storage and reads it with sf/GDAL. This is a whole-download helper: the file
#' is downloaded before sf reads it.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the vector file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ext Optional file extension without the dot (e.g. `"geojson"`),
#'   letters and digits only. Used as the temporary file's extension.
#' @param ... Additional arguments passed to [sf::st_read()]
#'
#' @return An sf object (data frame with geometry column)
#'
#' @details
#' Supports single-file formats that GDAL can read from one temporary file:
#' - GeoJSON (.geojson, .json)
#' - GeoPackage (.gpkg)
#' - KML (.kml)
#' - GML (.gml)
#' - OSM (.osm)
#'
#' Only formats whose driver GDAL can identify from the file content, not from
#' the extension, are reliable here, because the temporary file has no
#' extension. Formats that detect the driver from the extension may not open.
#' Pass `ext` (for example `ext = "geojson"`) when the format cannot be
#' identified from the content alone. It sets the temporary file's extension so
#' GDAL can pick the driver. Extra arguments still go to `sf::st_read()`.
#'
#' Multi-file formats such as shapefiles (`.shp` plus `.dbf`, `.shx` and other
#' sidecars) are not supported, because a single temporary file cannot hold
#' the sidecars.
#'
#' **Whole-download:** the file is downloaded into memory and written to a
#' temporary file, which is removed on exit. The whole file is read into
#' memory, which holds about one copy of the bytes, and a parsed sf object is
#' returned.
#'
#' **2 GiB limit:** files larger than 2 GiB (2147483647 bytes) are refused by
#' [xet_open_connection()] before any network call. The error names
#' `xet_download_file()`.
#'
#' **Optional package:** `sf` is in Suggests and is checked with
#' `requireNamespace()`.
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
read_xet_vector <- function(handle, file_hash, file_size, ext = NULL, ...) {
  .rxet_require_pkg("sf", "read_xet_vector")

  if (!is.null(ext)) {
    if (!is.character(ext) || length(ext) != 1L || is.na(ext) || !grepl("^[A-Za-z0-9]+$", ext)) {
      stop("`ext` must be a single string of letters and digits only", call. = FALSE)
    }
  }

  .rxet_whole_download(
    handle, file_hash, file_size,
    reader = function(path) sf::st_read(path, ...),
    ext = ext,
    via = "file"
  )
}
