#' Read a Parquet file from Xet storage using Arrow
#'
#' Downloads a Parquet file from Xet storage and reads it with Arrow.
#' The whole file is buffered into memory first; column selection and filters
#' are applied by Arrow after the data has been downloaded.
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
#' 1. Opens a Xet connection to the file via [xet_open_connection()]
#' 2. Passes it to `arrow::read_parquet()` which reads from the connection
#' 3. Supports all Arrow read_parquet options (col_select, filters, schema, etc.)
#' 4. Arrow closes the connection after reading; this function closes it only
#'    if reading fails
#'
#' The entire file is buffered into memory by [xet_open_connection()] before
#' Arrow reads it, so column selection and filters reduce Arrow/in-memory work
#' but not the number of bytes downloaded.
#'
#' **Whole-download:** the file is fully read before the call returns. No
#' temporary file is used. The whole file is read into memory, which holds
#' about one copy of the bytes, and a parsed object is returned.
#'
#' **2 GiB limit:** files larger than 2 GiB (2147483647 bytes) are refused by
#' [xet_open_connection()] before any network call. The error names
#' `xet_download_file()`.
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
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Read entire Parquet file
#' df <- read_xet_parquet(
#'   client,
#'   file_hash = "parquet-hash-abc123...",
#'   file_size = 5e9
#' )
#'
#' # Read only specific columns
#' df <- read_xet_parquet(
#'   client,
#'   file_hash = "parquet-hash-abc123...",
#'   file_size = 5e9,
#'   col_select = c("user_id", "timestamp", "value")
#' )
#' }
#'
#' @seealso [xet_open_connection()], `arrow::read_parquet()` for Arrow options
#' @export
read_xet_parquet <- function(handle, file_hash, file_size, ...) {
  require_pkg("arrow", "read_xet_parquet")

  # arrow::read_parquet() closes the connection it reads; whole_download()
  # closes it only when reading fails before arrow gets to it.
  whole_download(
    handle, file_hash, file_size,
    reader = function(conn) arrow::read_parquet(conn, ...),
    via = "connection"
  )
}
