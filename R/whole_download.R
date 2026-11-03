# Internal shared lifecycle for the whole-download readers (arrow, terra, sf).
# Not exported: the name carries the `.rxet_` prefix and `@noRd`.

#' @noRd
.rxet_whole_download <- function(handle, file_hash, file_size, reader, ext = NULL,
                           via = c("connection", "file")) {
  via <- match.arg(via)
  .rxet_check_handle(handle)
  .rxet_check_hash(file_hash)
  .rxet_check_file_size(file_size)

  if (via == "connection") {
    conn <- xet_open_connection(handle, file_hash, file_size)
    # Readers such as arrow close the connection themselves on success.
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
    fileext <- if (is.null(ext)) "" else paste0(".", sub("^\\.", "", ext))
    path <- tempfile(fileext = fileext)
    on.exit(unlink(path), add = TRUE)
    xet_download_file(handle, file_hash, file_size, path)
    reader(path)
  }
}
