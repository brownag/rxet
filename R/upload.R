#' Upload a local file to Xet storage
#'
#' Uploads a local file to a Xet content-addressed storage endpoint and returns
#' its Merkle hash.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param src_path Path to the local file to upload (must exist)
#'
#' @return Named list with components:
#'   - `hash`: Character string with the Merkle hash of the uploaded file
#'   - `file_size`: Numeric size of the file in bytes
#'
#' **Status:** Experimental pending live evidence.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-server.xethub.hf.co", "token")
#' on.exit(xet_client_close(client))
#' result <- xet_upload_file(client, "/path/to/file.bin")
#' cat("Hash:", result$hash, "\n")
#' cat("Size:", result$file_size, "\n")
#' }
xet_upload_file <- function(handle, src_path) {
  .rxet_check_handle(handle)
  .rxet_check_string(src_path, "src_path")

  if (!file.exists(src_path)) {
    stop(sprintf("source file does not exist: %s", src_path))
  }

  rxet_upload_file(handle, src_path)
}
