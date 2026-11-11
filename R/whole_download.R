# Internal shared lifecycle for the whole-download readers (arrow, terra, sf).
# Not exported: the name carries the `.rxet_` prefix and `@noRd`.

#' @noRd
.rxet_whole_download <- function(handle, file_hash, file_size, reader, ext = NULL,
                           dest_path = NULL, keep = FALSE,
                           via = c("stream", "file")) {
  via <- match.arg(via)
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size)

  if (via == "stream") {
    # A seekable connection over Xet ranges: only the bytes the reader asks for
    # are fetched. Readers such as arrow close the connection themselves.
    conn <- xet_open_stream_connection(handle, file_hash, file_size)
    tryCatch(
      reader(conn),
      error = function(e) {
        tryCatch(close(conn), error = function(e2) NULL)
        stop(e)
      }
    )
  } else {
    # A reader that needs a path gets the file straight from disk, so the bytes
    # are never held in R memory alongside the parsed object.
    if (is.null(dest_path)) {
      fileext <- if (is.null(ext)) "" else paste0(".", sub("^\\.", "", ext))
      path <- tempfile(fileext = fileext)
      if (!keep) on.exit(unlink(path), add = TRUE)
    } else {
      path <- dest_path
    }
    xet_download_file(handle, file_hash, file_size, path)
    reader(path)
  }
}
