#' Open an R connection to a Xet file
#'
#' Downloads a Xet file into memory and returns a standard R connection object
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
#' The whole file becomes one in-memory `raw()` vector, so the call needs that
#' much free RAM. `seek()` works within that copy, but this is **not** remote
#' range access: no bytes are fetched lazily from the endpoint.
#'
#' **Status:** Experimental pending live evidence.
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
#' client <- xet_client_new("https://cas-server.xethub.hf.co", "token")
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
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size)

  # Stream file into memory
  raw_bytes <- xet_stream_raw(handle, file_hash, file_size)

  # Wrap as R connection (base R function)
  rawConnection(raw_bytes, open = "r")
}
