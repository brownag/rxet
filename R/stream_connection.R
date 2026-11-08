#' Open a lazily downloaded connection to a Xet file
#'
#' Returns a seekable, read-only R connection that fetches bytes from Xet as
#' they are requested. Unlike [xet_open_connection()], the file is never
#' downloaded whole and never held in memory.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#'
#' @return A binary connection of class `c("rxet_connection", "connection")`.
#'   Read it with [readBin()], [seek()], or pass it to a reader that wants a
#'   seekable connection, such as `arrow::read_parquet()`.
#'
#' @details
#' Random access works by asking Xet for a byte range. Each miss fetches a
#' window that starts on a 64 KiB boundary and covers at least 1 MiB, growing
#' toward 16 MiB while reads move forward, so sequential and column-oriented
#' reads are served mostly from the window.
#' A hit costs nothing. A miss costs one reconstruction metadata round trip
#' plus the ranged transfer.
#'
#' All reads from one connection share a single download stream group, so they
#' reuse the same connection pool and token. The group is released when the
#' connection is closed or garbage collected.
#'
#' This is not a caching layer across connections. Two connections to the same
#' file fetch their own windows, although the hf-xet chunk cache may still serve
#' repeated bytes from disk.
#'
#' Requires R >= 4.3.0, which is when `R_new_custom_connection()` appeared.
#'
#' **Status:** Experimental pending live evidence.
#'
#' @seealso [xet_open_connection()] for a connection over a whole in-memory
#'   copy, and [xet_stream_range()] for one explicit byte range.
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-server.xethub.hf.co", "token")
#'
#' conn <- xet_open_stream_connection(client, "parquet-hash", 5e9)
#' df <- arrow::read_parquet(conn, col_select = c("id", "value"))
#' close(conn)
#' }
xet_open_stream_connection <- function(handle, file_hash, file_size) {
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size)
  if (getRversion() < "4.3.0") {
    stop("xet_open_stream_connection() needs R >= 4.3.0", call. = FALSE)
  }

  id <- rxet_open_reader(handle, file_hash, file_size)

  # close(conn) releases the reader now, through `close_fun`. The finalizer on
  # `guard` is the backstop for connections that are never closed.
  guard <- new.env(parent = emptyenv())
  reg.finalizer(guard, function(e) .rxet_close_reader_quietly(id), onexit = TRUE)
  reader <- function(offset, n) rxet_reader_read(id, offset, n)

  close_fun <- function() .rxet_close_reader_quietly(id)

  rxet_stream_connection(reader, close_fun, id)
}

#' @noRd
.rxet_close_reader_quietly <- function(id) {
  tryCatch(rxet_close_reader(id), error = function(e) NULL)
}
