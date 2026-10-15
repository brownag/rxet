#' Download a file from Xet storage
#'
#' Retrieves a file from a Xet content-addressed storage endpoint using its
#' Merkle hash and saves it to a local path. The file is written to a temporary
#' file in the destination directory and moved into place only after the download
#' succeeds; a failed download leaves no partial file and does not modify an
#' existing `dest_path`.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param hash Merkle hash hex string (obtained from HuggingFace Hub headers or metadata)
#' @param file_size File size in bytes (must be non-negative)
#' @param dest_path Local destination path where the file will be saved. The parent
#'   directory must already exist.
#'
#' @return `dest_path` invisibly on success
#'
#' **Status:** Experimental pending live evidence.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#' xet_download_file(client,
#'   hash = "abc123def456...",
#'   file_size = 1024,
#'   dest_path = "/tmp/downloaded_file"
#' )
#' }
xet_download_file <- function(handle, hash, file_size, dest_path) {
  stopifnot(is.character(handle), length(handle) == 1, nchar(handle) > 0)
  stopifnot(is.character(hash), length(hash) == 1, nchar(hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0, file_size <= .Machine$double.xmax)
  if (!(is.finite(file_size) && file_size == floor(file_size))) {
    stop("file_size must be a finite whole number of bytes")
  }
  stopifnot(is.character(dest_path), length(dest_path) == 1)

  if (dir.exists(dest_path)) {
    stop(sprintf("dest_path is a directory, not a file: %s", dest_path))
  }

  dest_dir <- dirname(dest_path)
  if (!dir.exists(dest_dir)) {
    stop(sprintf("destination directory does not exist: %s", dest_dir))
  }

  tmp <- tempfile(pattern = paste0(".", basename(dest_path), "-"), tmpdir = dest_dir, fileext = ".part")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)

  .Call("wrap__xet_download_file", handle, hash, as.double(file_size), tmp, PACKAGE = "rxet")

  if (!file.rename(tmp, dest_path)) {
    stop(sprintf("could not move download into place: %s", dest_path))
  }
  invisible(dest_path)
}
