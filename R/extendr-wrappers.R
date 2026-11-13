#' Initialize a Xet storage client with endpoint and authentication token.

# nolint start

#' Configuration starts from the HF_XET_* environment, then the optional
#' arguments are applied (high-performance preset first, explicit values last).
#' Returns a UUID string handle that identifies the client session.
#' @noRd
rxet_init_client <- function(endpoint, token, timeout_sec, cache_bytes, high_perf) .Call("wrap__rxet_init_client", endpoint, token, timeout_sec, cache_bytes, high_perf, PACKAGE = "rxet")

#' Close and free a Xet storage client
#' @noRd
rxet_close_client <- function(handle) .Call("wrap__rxet_close_client", handle, PACKAGE = "rxet")

#' Download a file from Xet storage to a local path
#' @noRd
rxet_download_file <- function(handle, hash, file_size, dest_path) .Call("wrap__rxet_download_file", handle, hash, file_size, dest_path, PACKAGE = "rxet")

#' Upload a local file to Xet storage
#' @noRd
rxet_upload_file <- function(handle, src_path) .Call("wrap__rxet_upload_file", handle, src_path, PACKAGE = "rxet")

#' Download an entire file from Xet storage into memory without disk writes
#' Uses xet-core's streaming API to fetch file in chunks and return as R raw vector.
#' @noRd
rxet_stream_raw <- function(handle, file_hash, file_size) .Call("wrap__rxet_stream_raw", handle, file_hash, file_size, PACKAGE = "rxet")

#' Stream a specific byte range of a file directly into memory as R data
#' Downloads only the chunks needed to reconstruct the requested byte range.
#' @noRd
rxet_stream_range <- function(handle, file_hash, total_size, start_offset, end_offset) .Call("wrap__rxet_stream_range", handle, file_hash, total_size, start_offset, end_offset, PACKAGE = "rxet")

#' Opens a reader for on-demand range reads and returns its handle.
#' @noRd
rxet_open_reader <- function(handle, file_hash, file_size) .Call("wrap__rxet_open_reader", handle, file_hash, file_size, PACKAGE = "rxet")

#' Reads exactly `length` bytes at `offset` from an open reader.
#' @noRd
rxet_reader_read <- function(reader_handle, offset, length) .Call("wrap__rxet_reader_read", reader_handle, offset, length, PACKAGE = "rxet")

#' Closes a reader and releases its stream group.
#' @noRd
rxet_close_reader <- function(reader_handle) .Call("wrap__rxet_close_reader", reader_handle, PACKAGE = "rxet")

#' Wraps an open reader in a seekable R connection.
#' `read_fun(offset, length)` must return a raw vector; `close_fun()` runs on close.
#' The file size comes from the reader.
#' @noRd
rxet_stream_connection <- function(read_fun, close_fun, reader_handle) .Call("wrap__rxet_stream_connection", read_fun, close_fun, reader_handle, PACKAGE = "rxet")

#' Reports whether a reader handle is still registered.
#' @noRd
rxet_reader_is_open <- function(reader_handle) .Call("wrap__rxet_reader_is_open", reader_handle, PACKAGE = "rxet")

#' Opens a reader over bytes held in memory and returns its id.
#' Internal (no `xet_` prefix, so not exported); used by offline tests.
#' @noRd
rxet_memory_reader_open <- function(bytes) .Call("wrap__rxet_memory_reader_open", bytes, PACKAGE = "rxet")


# nolint end
