# Internal request validation shared by the transfer functions and readers.
# Not exported: names carry the `.rxet_` prefix and `@noRd`.
# Messages never echo `handle` values.

#' @noRd
.rxet_check_handle <- function(handle) {
  if (!is.character(handle) || length(handle) != 1L || is.na(handle) || !nzchar(handle)) {
    stop("`handle` must be a non-empty string", call. = FALSE)
  }
  invisible(handle)
}

#' @noRd
.rxet_check_hash <- function(file_hash, arg = "file_hash") {
  if (!is.character(file_hash) || length(file_hash) != 1L || is.na(file_hash) || !nzchar(file_hash)) {
    stop(sprintf("`%s` must be a non-empty string", arg), call. = FALSE)
  }
  invisible(file_hash)
}

#' @noRd
.rxet_check_file_size <- function(file_size) {
  if (!is.numeric(file_size) || length(file_size) != 1L) {
    stop("`file_size` must be a single number", call. = FALSE)
  }
  if (!is.finite(file_size) || file_size != floor(file_size)) {
    stop("`file_size` must be a finite whole number of bytes", call. = FALSE)
  }
  if (file_size < 0) {
    stop("`file_size` must be >= 0", call. = FALSE)
  }
  invisible(file_size)
}

#' @noRd
.rxet_check_range <- function(start_byte, end_byte, file_size) {
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
  invisible(TRUE)
}

#' @noRd
.rxet_check_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(sprintf("`%s` must be a single non-empty string", arg), call. = FALSE)
  }
  invisible(x)
}

#' @noRd
.rxet_require_pkg <- function(pkg, fn) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf(
      "The '%s' package is required for %s(). Install it with: install.packages('%s')",
      pkg, fn, pkg
    ), call. = FALSE)
  }
  invisible(TRUE)
}
