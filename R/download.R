#' Download a file from Xet storage
#'
#' Retrieves a file from a Xet content-addressed storage endpoint using its
#' Merkle hash and saves it to a local path.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param hash Merkle hash hex string (obtained from HuggingFace Hub headers or metadata)
#' @param file_size File size in bytes (must be non-negative)
#' @param dest_path Local destination path where the file will be saved. The parent
#'   directory must already exist.
#'
#' @return `dest_path` invisibly on success
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
  stopifnot(is.character(handle), length(handle) == 1)
  stopifnot(is.character(hash), length(hash) == 1, nchar(hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0, file_size <= .Machine$double.xmax)
  stopifnot(is.character(dest_path), length(dest_path) == 1)

  dest_dir <- dirname(dest_path)
  if (!dir.exists(dest_dir)) {
    stop(sprintf("destination directory does not exist: %s", dest_dir))
  }

  .Call("_rxet_xet_download_file", handle, hash, as.double(file_size), dest_path, PACKAGE = "rxet")
  invisible(dest_path)
}

#' Get file metadata (chunk mappings) from Xet storage
#'
#' Retrieves metadata about a file stored in Xet, including the chunk mappings
#' that describe how the file is decomposed into content-addressed chunks.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#'
#' @return A data frame with columns:
#'   - `hash`: Character vector of chunk hashes
#'   - `offset_start`: Numeric vector of byte offsets where each chunk starts
#'   - `offset_end`: Numeric vector of byte offsets where each chunk ends
#'   - `size`: Numeric vector of chunk sizes in bytes
#'
#' @details
#' This function queries the metadata shard for a file, which describes how the
#' file is decomposed into chunks. The returned data can be used to plan efficient
#' partial downloads via [xet_stream_range()] (Phase 5 feature).
#'
#' Currently returns cached metadata only. Full integration with CAS metadata download
#' is scheduled for Phase 5.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#' metadata <- xet_get_file_metadata(client, "abc123def456...")
#' # Returns data frame describing file chunks and their offsets
#' }
xet_get_file_metadata <- function(handle, file_hash) {
  stopifnot(is.character(handle), length(handle) == 1)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)

  result <- .Call("_rxet_xet_get_file_metadata", handle, file_hash, PACKAGE = "rxet")

  # Convert to data frame for easier use
  if (is.list(result) && !is.null(result$hash)) {
    data.frame(
      hash = result$hash,
      offset_start = result$offset_start,
      offset_end = result$offset_end,
      size = result$size,
      stringsAsFactors = FALSE
    )
  } else {
    result
  }
}
