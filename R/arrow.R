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
#' temporary file is used. Peak memory is about one copy of the file plus the
#' parsed object.
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
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop(
      "The 'arrow' package is required for read_xet_parquet(). ",
      "Install it with: install.packages('arrow')"
    )
  }

  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size > 0)

  conn <- xet_open_connection(handle, file_hash, file_size)

  # arrow::read_parquet() closes the connection it reads, so close it here
  # only when reading fails before arrow gets to it.
  tryCatch(
    arrow::read_parquet(conn, ...),
    error = function(e) {
      tryCatch(close(conn), error = function(e2) NULL)
      stop(e)
    }
  )
}

#' Read a Parquet file from Xet via a whole-file download and temporary file
#'
#' Downloads the entire Parquet file into memory, writes it to a temporary
#' `.parquet` file, and reads it with Arrow. This is a whole-download helper,
#' not a streaming helper. Use it when a temporary file is preferred over
#' [read_xet_parquet()].
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the Parquet file
#' @param file_size Numeric scalar, total file size in bytes
#' @param ... Additional arguments passed to `arrow::read_parquet()`
#'
#' @return An R data frame (not a connection)
#'
#' @details
#' This function:
#' 1. Downloads the **entire** file into memory via [xet_stream_raw()]
#' 2. Writes those bytes to a temporary `.parquet` file
#' 3. Reads the temporary file with `arrow::read_parquet()`
#' 4. Deletes the temporary file on exit
#'
#' **Whole-download:** the file is fully read before the call returns.
#' Peak memory is about the file bytes, plus the temporary copy, plus the
#' parsed data frame.
#'
#' **2 GiB limit:** files larger than 2 GiB (2147483647 bytes) are refused by
#' [xet_stream_raw()] before any network call. The error names
#' `xet_download_file()`.
#'
#' **Optional package:** `arrow` is in Suggests and is checked with
#' `requireNamespace()`.
#'
#' **Status:** Experimental pending live evidence. The end-to-end behaviour
#' against a live Xet endpoint has not yet been verified.
#'
#' @examples
#' \dontrun{
#' library(arrow)
#'
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Read entire Parquet file into memory
#' df <- read_xet_parquet_stream(
#'   client,
#'   file_hash = "parquet-hash-abc123...",
#'   file_size = 2.5e9
#' )
#' }
#'
#' @seealso [read_xet_parquet()] for direct connection-based reading
#' @export
read_xet_parquet_stream <- function(handle, file_hash, file_size, ...) {
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("The 'arrow' package is required. Install it with: install.packages('arrow')")
  }

  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size > 0)

  # Stream file into memory
  raw_bytes <- xet_stream_raw(handle, file_hash, file_size)

  # Write to temporary file
  tmp_file <- tempfile(fileext = ".parquet")
  on.exit(unlink(tmp_file), add = TRUE)

  writeBin(raw_bytes, tmp_file)

  # Read with Arrow and pass through all additional arguments
  arrow::read_parquet(tmp_file, ...)
}
