#' Stream an entire file from Xet storage into memory
#'
#' Downloads a complete file from Xet storage directly into memory without
#' writing to disk. Uses background streaming with bounded backpressure to
#' prevent memory exhaustion. Ideal for in-memory analytics on large files.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#'
#' @return A list containing:
#'   - `file_hash`: The file hash
#'   - `file_size`: The file size in bytes
#'   - `stream_status`: Current status of the stream
#'   - `controller_active`: Boolean indicating if StreamController is active
#'   - `note`: Implementation status note
#'
#' @details
#' This function streams a file using a background StreamController that manages
#' chunks through a bounded crossbeam channel. The bounded channel (128 chunks)
#' provides backpressure, preventing the R main thread from being blocked or
#' overwhelmed by network speed differences.
#'
#' **Note:** Current implementation (Phase 5) returns metadata about the stream.
#' Full byte-range assembly into Raw vectors comes later in Phase 5.
#'
#' @seealso [xet_stream_range()] for partial downloads
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Download entire 1GB file into memory
#' stream <- xet_stream_raw(
#'   handle = client,
#'   file_hash = "abc123def456...",
#'   file_size = 1e9
#' )
#' }
xet_stream_raw <- function(handle, file_hash, file_size) {
  stopifnot(is.character(handle), length(handle) == 1)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0)

  .Call(
    "_rxet_xet_stream_raw",
    handle,
    file_hash,
    as.double(file_size),
    PACKAGE = "rxet"
  )
}

#' Stream a byte range of a file from Xet storage
#'
#' Retrieves a specific byte range of a file from Xet storage without downloading
#' the entire file. This enables efficient partial downloads, such as reading
#' Parquet metadata footers or spatial windows from remote GeoTIFFs.
#'
#' @param handle Character string handle from [xet_client_new()]
#' @param file_hash Character string, the content hash of the file
#' @param file_size Numeric scalar, total file size in bytes
#' @param start_byte Numeric scalar, starting byte offset (0-indexed, inclusive)
#' @param end_byte Numeric scalar, ending byte offset (exclusive)
#'
#' @return A list containing:
#'   - `range_start`: Starting byte offset requested
#'   - `range_end`: Ending byte offset requested
#'   - `range_size`: Number of bytes in the range
#'   - `chunks_needed`: Character vector of chunk hashes needed to reconstruct range
#'   - `status`: Status message (currently placeholder for Phase 5)
#'
#' @details
#' This function uses the file's metadata shard (obtained via [xet_get_file_metadata()])
#' to determine which chunks are needed to reconstruct the requested byte range.
#' It then downloads only those chunks, assembling them into the final result.
#'
#' **Note:** Current implementation (Phase 4) returns metadata about chunks needed.
#' Phase 5 will implement actual byte-range downloading and assembly into raw vectors.
#'
#' @seealso [xet_get_file_metadata()] for understanding file chunk structure
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#'
#' # Get first 1MB of a 10GB file
#' result <- xet_stream_range(
#'   handle = client,
#'   file_hash = "abc123def456...",
#'   file_size = 10e9,
#'   start_byte = 0,
#'   end_byte = 1e6
#' )
#'
#' # See which chunks are needed
#' result$chunks_needed
#' }
xet_stream_range <- function(handle, file_hash, file_size, start_byte, end_byte) {
  stopifnot(is.character(handle), length(handle) == 1)
  stopifnot(is.character(file_hash), length(file_hash) == 1, nchar(file_hash) > 0)
  stopifnot(is.numeric(file_size), length(file_size) == 1, file_size >= 0)
  stopifnot(is.numeric(start_byte), length(start_byte) == 1, start_byte >= 0)
  stopifnot(is.numeric(end_byte), length(end_byte) == 1, end_byte > start_byte)
  stopifnot(end_byte <= file_size)

  .Call(
    "_rxet_xet_stream_range",
    handle,
    file_hash,
    as.double(file_size),
    as.double(start_byte),
    as.double(end_byte),
    PACKAGE = "rxet"
  )
}
