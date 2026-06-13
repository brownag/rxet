# Auto-generated wrappers for extendr functions
# These dispatch to the compiled Rust functions via .Call()

.xet_init_client <- function(endpoint, token) {
  .Call("wrap__xet_init_client", endpoint, token, PACKAGE = "rxet")
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
