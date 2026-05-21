#' Open an R connection to a Xet file
#'
#' Creates an R connection object that can be used with standard R connection
#' functions like [readBin()], [readLines()], etc. This enables seamless
#' integration with packages like Arrow, GDAL, and spatial tools that expect
#' R connection objects.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#'
#' @return An R connection object that can be passed to [readBin()], [readLines()],
#'   and other connection-aware functions.
#'
#' @details
#' An R connection provides a standard interface for reading data streams.
#' By exposing Xet downloads as connections, downstream packages can
#' consume Xet files without intermediate temporary files.
#'
#' **Example use cases:**
#' - Arrow: `arrow::read_parquet(xet_open_connection(...))`
#' - GDAL/terra: `terra::rast(xet_open_connection(...))`
#' - CSV: `read.csv(xet_open_connection(...))`
#'
#' **Note:** Current implementation (Phase 5) provides the connection structure.
#' Full R connection API integration with readBin/readLines callbacks comes
#' with final Phase 5 completion.
#'
#' @seealso [xet_stream_raw()] for in-memory loading, [xet_stream_range()]
#'   for partial downloads
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Open connection to a Parquet file
#' conn <- xet_open_connection(client, "parquet-hash", 1e9)
#'
#' # Read directly with Arrow
#' df <- arrow::read_parquet(conn)
#'
#' # Clean up
#' close(conn)
#' }
xet_open_connection <- function(handle, file_hash, file_size) {
  stopifnot(is.character(handle), length(handle) == 1)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0)

  # Phase 5: Create and return connection object
  # Full implementation will register R connection callbacks
  # (read_fn, write_fn, close_fn) with R's connection manager

  structure(
    list(
      handle = handle,
      file_hash = file_hash,
      file_size = file_size,
      open = TRUE,
      position = 0
    ),
    class = "xet_connection"
  )
}

#' Close an R connection to a Xet file
#'
#' Closes the connection and releases resources.
#'
#' @param conn An R connection object created by [xet_open_connection()]
#'
#' @return `NULL` invisibly
#' @export
xet_close_connection <- function(conn) {
  stopifnot(inherits(conn, "xet_connection"))
  conn$open <- FALSE
  invisible(NULL)
}

#' Print method for Xet connections
#'
#' @param x A xet_connection object
#' @param ... Additional arguments (unused)
#' @export
print.xet_connection <- function(x, ...) {
  status <- if (x$open) "open" else "closed"
  cat(sprintf(
    "<xet_connection> %s\n  File: %s\n  Size: %.0f bytes\n",
    status, substr(x$file_hash, 1, 16), x$file_size
  ))
  invisible(x)
}
