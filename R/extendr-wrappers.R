# Auto-generated wrappers for extendr functions
# These dispatch to the compiled Rust functions via .Call()

.xet_init_client <- function(endpoint, token, timeout_sec, cache_bytes, high_perf) {
  .Call("wrap__xet_init_client", endpoint, token, timeout_sec, cache_bytes, high_perf, PACKAGE = "rxet")
}

.xet_close_client <- function(handle) {
  .Call("wrap__xet_close_client", handle, PACKAGE = "rxet")
}

.xet_stream_raw <- function(handle, file_hash, file_size) {
  .Call("wrap__xet_stream_raw", handle, file_hash, as.double(file_size), PACKAGE = "rxet")
}

.xet_stream_range <- function(handle, file_hash, file_size, start_byte, end_byte) {
  .Call("wrap__xet_stream_range", handle, file_hash, as.double(file_size), as.double(start_byte), as.double(end_byte), PACKAGE = "rxet")
}

.xet_download_file <- function(handle, hash, file_size, dest_path) {
  .Call("wrap__xet_download_file", handle, hash, as.double(file_size), dest_path, PACKAGE = "rxet")
}

.xet_upload_file <- function(handle, src_path) {
  .Call("wrap__xet_upload_file", handle, src_path, PACKAGE = "rxet")
}

.xet_open_reader <- function(handle, file_hash, file_size) {
  .Call("wrap__xet_open_reader", handle, file_hash, as.double(file_size), PACKAGE = "rxet")
}

.xet_reader_read <- function(reader_handle, offset, length) {
  .Call("wrap__xet_reader_read", reader_handle, as.double(offset), as.double(length), PACKAGE = "rxet")
}

.xet_close_reader <- function(reader_handle) {
  .Call("wrap__xet_close_reader", reader_handle, PACKAGE = "rxet")
}

.xet_stream_connection <- function(read_fun, file_size) {
  .Call("wrap__xet_stream_connection", read_fun, as.double(file_size), PACKAGE = "rxet")
}
