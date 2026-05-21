# Auto-generated wrappers for extendr functions
# These dispatch to the compiled Rust functions via .Call()

xet_init_client <- function(endpoint, token) {
  .Call(wrap__xet_init_client, endpoint, token)
}

xet_close_client <- function(handle) {
  .Call(wrap__xet_close_client, handle)
}

xet_download_file <- function(handle, hash, file_size, dest_path) {
  .Call(wrap__xet_download_file, handle, hash, file_size, dest_path)
}

xet_upload_file <- function(handle, src_path) {
  .Call(wrap__xet_upload_file, handle, src_path)
}
