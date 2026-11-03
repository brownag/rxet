#' Internal Rust bindings for client initialization and cleanup
#'
#' These functions are called by the R wrappers and should not be used directly.
#'
#' @keywords internal
#' @name xet_init_client
NULL

#' @keywords internal
#' @rdname xet_init_client
#' @name xet_close_client
NULL

#' Create a Xet storage client
#'
#' Initializes a client session for interacting with a Xet content-addressed
#' storage endpoint.
#'
#' @param endpoint URL of the Xet CAS endpoint. Must use `https://`; `http://` is
#'   accepted only for `localhost` or `127.0.0.1`.
#' @param token Bearer token for authentication with the CAS endpoint
#' @param timeout_sec `NULL` or a single finite non-negative whole number.
#'   Network read timeout in seconds (hf-xet `client.read_timeout`). `NULL`
#'   leaves hf-xet's value alone, so the `HF_XET_CLIENT_READ_TIMEOUT`
#'   environment variable or hf-xet's default applies.
#' @param cache_bytes `NULL` or a single finite non-negative whole number.
#'   Local chunk cache size in bytes (hf-xet `chunk_cache.size_bytes`). `0`
#'   disables the cache. `NULL` leaves hf-xet's value alone, so the
#'   `HF_XET_CHUNK_CACHE_SIZE_BYTES` environment variable or hf-xet's default
#'   applies.
#' @param high_perf Single logical, default `FALSE`. If `TRUE`, applies hf-xet's
#'   high-performance preset, which raises concurrency and download buffer
#'   sizes. It does not change the chunk cache; to run without a cache pass
#'   `cache_bytes = 0`. The preset is applied after the `HF_XET_*` environment,
#'   so for the fields it sets it overrides an environment value.
#'
#' @details
#' The client starts from hf-xet's configuration, which reads `HF_XET_*`
#' environment variables when the client is created. `high_perf` is applied
#' next, then `timeout_sec` and `cache_bytes`, so explicit arguments override
#' the environment for the fields they set. Configuration is per client; no
#' process-wide state is changed.
#'
#' @return A character string handle that identifies the client session. Pass this handle
#'   to other `xet_*` functions. Must be closed with [xet_client_close()] when done,
#'   even if an error occurs. Use `on.exit()` to ensure cleanup in production code.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-server.xethub.hf.co", "token")
#' on.exit(xet_client_close(client))
#' xet_download_file(client, hash = "...", file_size = 1024, dest_path = "/tmp/file")
#' }
xet_client_new <- function(endpoint, token, timeout_sec = NULL, cache_bytes = NULL,
                           high_perf = FALSE) {
  stopifnot(is.character(endpoint), length(endpoint) == 1, nchar(endpoint) > 0)
  is_https <- grepl("^https://", endpoint, ignore.case = TRUE)
  is_loopback_http <- grepl("^http://", endpoint, ignore.case = TRUE) &&
    tolower(sub("^http://([^/:]+).*$", "\\1", endpoint, ignore.case = TRUE)) %in%
      c("localhost", "127.0.0.1")
  if (!is_https && !is_loopback_http) {
    stop("endpoint must use https:// (http:// is allowed only for localhost or 127.0.0.1)")
  }
  stopifnot(is.character(token), length(token) == 1, nchar(token) > 0)
  check_whole <- function(x, name) {
    if (!is.null(x) &&
        !(is.numeric(x) && length(x) == 1 && is.finite(x) && x >= 0 && x == trunc(x))) {
      stop(name, " must be NULL or a single finite non-negative whole number", call. = FALSE)
    }
  }
  check_whole(timeout_sec, "timeout_sec")
  check_whole(cache_bytes, "cache_bytes")
  if (!(is.logical(high_perf) && length(high_perf) == 1 && !is.na(high_perf))) {
    stop("high_perf must be a single TRUE or FALSE", call. = FALSE)
  }
  .xet_init_client(endpoint, token, timeout_sec, cache_bytes, high_perf)
}

#' Close and free a Xet client session
#'
#' Releases the client handle and frees associated resources.
#'
#' After closing, the handle is invalid immediately; later calls with it error.
#' An operation already in progress when the handle is closed completes normally.
#'
#' @param handle Character string handle from [xet_client_new()]
#'
#' @return `NULL` invisibly
#' @export
xet_client_close <- function(handle) {
  stopifnot(is.character(handle), length(handle) == 1)
  .xet_close_client(handle)
  invisible(NULL)
}
