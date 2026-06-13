#' rxet: Xet Storage R Package
#'
#' Native R bindings to the Hugging Face Xet content-addressed storage engine
#' via Rust and the extendr framework.
#'
#' @keywords internal
#' @useDynLib rxet, .registration = TRUE
"_PACKAGE"

# Suppress R CMD check notes for extendr-generated wrappers
utils::globalVariables(c(
  "wrap__xet_init_client",
  "wrap__xet_close_client",
  "wrap__xet_download_file",
  "wrap__xet_upload_file",
  "wrap__xet_stream_raw",
  "wrap__xet_stream_range"
))
