#' Open an R connection to a Xet file
#'
#' Streams a Xet file into memory and returns a standard R connection object
#' that can be used with standard R connection functions and ecosystem packages
#' like Arrow, terra, and sf.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#'
#' @return An R connection object created via [rawConnection()], which can be
#'   passed to [readBin()], [readLines()], and other connection-aware functions.
#'
#' @details
#' This function:
#' 1. Calls [xet_stream_raw()] to download the file into memory as a `raw()` vector
#' 2. Wraps it with [rawConnection()], which returns a real R connection object
#' 3. The connection supports `readBin()`, `seek()`, `close()`, and integration
#'    with Arrow, terra, sf/GDAL, and other packages that read from connections
#'
#' **Example use cases:**
#' - Arrow: `arrow::read_parquet(xet_open_connection(...))`
#' - GDAL/terra: `terra::rast(xet_open_connection(...))`
#' - CSV: `read.csv(xet_open_connection(...))`
#'
#' @seealso [rawConnection()] (base R), [xet_stream_raw()] for direct byte access,
#'   [xet_stream_range()] for partial downloads
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Open connection to a Parquet file
#' conn <- xet_open_connection(client, "parquet-hash", 1e9)
#' on.exit(close(conn), add = TRUE)
#'
#' # Read directly with Arrow
#' df <- arrow::read_parquet(conn)
#' }
xet_open_connection <- function(handle, file_hash, file_size) {
  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0)

  # Stream file into memory
  raw_bytes <- xet_stream_raw(handle, file_hash, file_size)

  # Wrap as R connection (base R function)
  rawConnection(raw_bytes, open = "r")
}

#' Close an R connection to a Xet file
#'
#' Closes the connection and releases resources.
#' Since [xet_open_connection()] returns a standard R connection created
#' via [rawConnection()], you can use base R's `close()` function directly.
#' This function is provided for convenience and compatibility.
#'
#' @param conn An R connection object created by [xet_open_connection()]
#'
#' @return `NULL` invisibly
#'
#' @seealso [close()], [xet_open_connection()]
#' @export
xet_close_connection <- function(conn) {
  close(conn)
  invisible(NULL)
}
