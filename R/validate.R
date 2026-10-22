# Internal request validation shared by the transfer functions and readers.
# Not exported: names deliberately lack the `xet_` prefix (exportPattern "^xet_").
# Messages never echo `handle` values.

#' @noRd
check_handle <- function(handle) {
  if (!is.character(handle) || length(handle) != 1L || is.na(handle) || !nzchar(handle)) {
    stop("`handle` must be a non-empty string", call. = FALSE)
  }
  invisible(handle)
}

#' @noRd
check_hash <- function(file_hash, arg = "file_hash") {
  if (!is.character(file_hash) || length(file_hash) != 1L || is.na(file_hash) || !nzchar(file_hash)) {
    stop(sprintf("`%s` must be a non-empty string", arg), call. = FALSE)
  }
  invisible(file_hash)
}

#' @noRd
check_file_size <- function(file_size, in_memory = FALSE) {
  if (!is.numeric(file_size) || length(file_size) != 1L) {
    stop("`file_size` must be a single number", call. = FALSE)
  }
  if (!is.finite(file_size) || file_size != floor(file_size)) {
    stop("`file_size` must be a finite whole number of bytes", call. = FALSE)
  }
  if (file_size < 0) {
    stop("`file_size` must be >= 0", call. = FALSE)
  }
  if (in_memory && file_size > .Machine$integer.max) {
    stop(sprintf(
      "in-memory read of %.0f bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files",
      file_size
    ), call. = FALSE)
  }
  invisible(file_size)
}

#' @noRd
check_range <- function(start_byte, end_byte, file_size) {
  for (nm in c("start_byte", "end_byte")) {
    v <- get(nm)
    if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v != floor(v)) {
      stop(sprintf("`%s` must be a finite whole number of bytes", nm), call. = FALSE)
    }
  }
  if (start_byte < 0) {
    stop("`start_byte` must be >= 0", call. = FALSE)
  }
  if (end_byte <= start_byte) {
    stop("`end_byte` must be greater than `start_byte`", call. = FALSE)
  }
  if (end_byte > file_size) {
    stop("`end_byte` must not exceed `file_size`", call. = FALSE)
  }
  if (end_byte - start_byte > .Machine$integer.max) {
    stop(sprintf(
      "in-memory requested range of %.0f bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files",
      end_byte - start_byte
    ), call. = FALSE)
  }
  invisible(TRUE)
}

#' @noRd
check_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be a single non-NA string", arg), call. = FALSE)
  }
  invisible(x)
}

#' @noRd
require_pkg <- function(pkg, fn) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf(
      "The '%s' package is required for %s(). Install it with: install.packages('%s')",
      pkg, fn, pkg
    ), call. = FALSE)
  }
  invisible(TRUE)
}
