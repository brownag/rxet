#' Stream an entire file from Xet storage into memory
#'
#' Downloads a complete file from Xet storage into memory as a `raw()` vector
#' without writing to disk. The whole file is buffered in memory, so it must
#' fit in available RAM.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#'
#' @return A `raw()` vector containing the complete file contents
#'
#' @details
#' The file bytes are returned as a `raw()` vector, with the whole file buffered
#' in memory. This vector can be passed to [xet_open_connection()]
#' to create an R connection, or used directly with downstream functions
#' like `arrow::read_parquet()` via a temporary file.
#'
#' `file_size` must be a finite whole number of bytes, and at most 2^31 - 1
#' bytes (2 GiB). Larger files error before any network access; use
#' [xet_download_file()] instead.
#'
#' **Status:** Experimental pending live evidence.
#'
#' @seealso [xet_stream_range()] for partial downloads
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Download entire 1GB file into memory
#' stream <- xet_stream_raw(
#'   handle = client,
#'   file_hash = "abc123def456...",
#'   file_size = 1e9
#' )
#' }
xet_stream_raw <- function(handle, file_hash, file_size) {
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size, in_memory = TRUE)

  .xet_stream_raw(handle, file_hash, file_size)
}

#' Stream a byte range of a file from Xet storage
#'
#' Retrieves a specific byte range of a file from Xet storage and returns it as
#' a `raw()` vector. Byte ranges can be used to read Parquet metadata footers or
#' spatial windows from remote GeoTIFFs.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#' @param start_byte Numeric scalar, starting byte offset (0-indexed, inclusive)
#' @param end_byte Numeric scalar, ending byte offset (exclusive)
#'
#' @return A `raw()` vector containing the requested byte range.
#'
#' @details
#' `start_byte` is inclusive and `end_byte` is exclusive, so the requested range
#' covers bytes `start_byte` through `end_byte - 1`. The result is a `raw()`
#' vector of the returned bytes.
#'
#' `file_size` must be a finite whole number of bytes. The requested range
#' (`end_byte - start_byte`) must be at most 2^31 - 1 bytes (2 GiB); larger
#' ranges error before any network access. Use [xet_download_file()] for
#' larger transfers.
#'
#' **Status:** Experimental pending live evidence.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Get first 1MB of a 10GB file
#' bytes <- xet_stream_range(
#'   handle = client,
#'   file_hash = "abc123def456...",
#'   file_size = 10e9,
#'   start_byte = 0,
#'   end_byte = 1e6
#' )
#' }
xet_stream_range <- function(handle, file_hash, file_size, start_byte, end_byte) {
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size)
  .rxet_check_range(start_byte, end_byte, file_size)

  .xet_stream_range(handle, file_hash, file_size, start_byte, end_byte)
}
