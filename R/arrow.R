#' Read a Parquet file from Xet storage using Arrow
#'
#' Streams a Parquet file from Xet storage and reads it with Arrow. Arrow reads
#' the footer and then only the column chunks it needs, and each read is served
#' as a Xet byte range, so unread columns are never transferred.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the Parquet file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ... Additional arguments passed to `arrow::read_parquet()`,
#'   such as `col_select`, `filters`, `schema`, etc.
#'
#' @return An Arrow Table or R data frame (depending on `as_data_frame` argument)
#'
#' @details
#' This function:
#' 1. Opens a seekable range connection with [xet_open_stream_connection()]
#' 2. Passes it to `arrow::read_parquet()`, which seeks and reads as needed
#' 3. Supports all Arrow read_parquet options (col_select, filters, schema, etc.)
#' 4. Arrow closes the connection after reading; this function closes it only
#'    if reading fails
#'
#' **Partial download:** bytes are fetched on demand in windows of at least
#' 1 MiB (larger while reads move forward, up to 16 MiB), aligned to 64 KiB.
#' A file with 40 columns where you select 2
#' transfers only the footer and the chunks for those 2 columns.
#'
#' **Memory:** the parsed table is the main cost. The only raw bytes held are
#' the readahead window and the chunk being parsed.
#'
#' **Optional package:** `arrow` is in Suggests and is checked with
#' `requireNamespace()`.
#'
#' **Status:** Experimental pending live evidence.
#'
#' **Requirements:** The `arrow` package must be installed.
#'
#' @examples
#' \dontrun{
#' library(arrow)
#'
#' client <- xet_client_new("https://cas-server.xethub.hf.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # file_hash and file_size come from the Hub file metadata
#' df <- read_xet_parquet(
#'   client,
#'   file_hash = "parquet-hash-abc123...",
#'   file_size = 500e6,
#'   col_select = c("user_id", "timestamp", "value")
#' )
#' }
#'
#' @seealso [xet_open_connection()], `arrow::read_parquet()` for Arrow options
#' @export
read_xet_parquet <- function(handle, file_hash, file_size, ...) {
  .rxet_require_pkg("arrow", "read_xet_parquet")

  # Arrow closes the connection it reads; .rxet_whole_download() closes it only
  # when reading fails before arrow gets to it.
  .rxet_whole_download(
    handle, file_hash, file_size,
    reader = function(conn) arrow::read_parquet(conn, ...),
    via = "stream"
  )
}
