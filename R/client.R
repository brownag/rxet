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
#'
#' @return A character string handle that identifies the client session. Pass this handle
#'   to other `xet_*` functions. Must be closed with [xet_client_close()] when done,
#'   even if an error occurs. Use `on.exit()` to ensure cleanup in production code.
#'
#' @export
#' @examples
#' \dontrun{
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' on.exit(xet_client_close(client))
#' xet_download_file(client, hash = "...", file_size = 1024, dest_path = "/tmp/file")
#' }
xet_client_new <- function(endpoint, token) {
  stopifnot(is.character(endpoint), length(endpoint) == 1, nchar(endpoint) > 0)
  is_https <- grepl("^https://", endpoint, ignore.case = TRUE)
  is_loopback_http <- grepl("^http://", endpoint, ignore.case = TRUE) &&
    tolower(sub("^http://([^/:]+).*$", "\\1", endpoint, ignore.case = TRUE)) %in%
      c("localhost", "127.0.0.1")
  if (!is_https && !is_loopback_http) {
    stop("endpoint must use https:// (http:// is allowed only for localhost or 127.0.0.1)")
  }
  stopifnot(is.character(token), length(token) == 1, nchar(token) > 0)
  .Call("wrap__xet_init_client", endpoint, token, PACKAGE = "rxet")
}

#' Close and free a Xet client session
#'
#' Releases the client handle and frees associated resources.
#'
#' @param handle Character string handle from [xet_client_new()]
#'
#' @return `NULL` invisibly
#' @export
xet_client_close <- function(handle) {
  stopifnot(is.character(handle), length(handle) == 1)
  .Call("wrap__xet_close_client", handle, PACKAGE = "rxet")
  invisible(NULL)
}

#' Configure Xet client environment variables
#'
#' Sets environment variables that control Xet client behavior. Call this
#' **before** initializing clients with [xet_client_new()] for the settings
#' to take effect.
#'
#' @param timeout_sec Numeric scalar, default 300. Network read timeout in seconds.
#'   Prevents premature timeouts on slow or high-latency connections.
#'   Equivalent to: `Sys.setenv(HF_XET_CLIENT_READ_TIMEOUT = timeout_sec)`
#'
#' @param cache_bytes Numeric scalar, default 10e9 (10 GiB). Local chunk cache size
#'   in bytes. Set to 0 to disable caching (useful for one-shot downloads).
#'   Equivalent to: `Sys.setenv(HF_XET_CHUNK_CACHE_SIZE_BYTES = cache_bytes)`
#'
#' @param high_perf Logical scalar, default FALSE. If TRUE, enables high-performance
#'   mode by disabling chunk cache and optimizing for throughput. Useful for
#'   large-scale downloads where deduplication is not needed.
#'   Equivalent to: `Sys.setenv(HF_XET_HIGH_PERFORMANCE = "1")`
#'
#' @return `NULL` invisibly. Modifies environment variables as a side effect.
#'
#' @details
#' This is a convenience wrapper that sets standard HuggingFace Xet environment
#' variables. You can also set these directly via [Sys.setenv()]:
#'
#' ```r
#' # Equivalent to xet_config_environment(timeout_sec=600, high_perf=TRUE)
#' Sys.setenv(HF_XET_CLIENT_READ_TIMEOUT = 600)
#' Sys.setenv(HF_XET_HIGH_PERFORMANCE = "1")
#' ```
#'
#' @examples
#' \dontrun{
#' # For slow network links, increase timeout
#' xet_config_environment(timeout_sec = 600)
#'
#' # For pure download workload, disable cache and enable high-perf
#' xet_config_environment(cache_bytes = 0, high_perf = TRUE)
#'
#' # Now initialize client; configuration takes effect
#' client <- xet_client_new("https://cas-cf.huggingface.co", "token")
#' }
#'
#' @export
xet_config_environment <- function(timeout_sec = 300, cache_bytes = 10e9, high_perf = FALSE) {
  stopifnot(is.numeric(timeout_sec), length(timeout_sec) == 1, timeout_sec > 0)
  stopifnot(is.numeric(cache_bytes), length(cache_bytes) == 1, cache_bytes >= 0)
  stopifnot(is.logical(high_perf), length(high_perf) == 1)

  Sys.setenv(HF_XET_CLIENT_READ_TIMEOUT = as.character(as.integer(timeout_sec)))
  Sys.setenv(HF_XET_CHUNK_CACHE_SIZE_BYTES = sprintf("%.0f", cache_bytes))
  if (high_perf) {
    Sys.setenv(HF_XET_HIGH_PERFORMANCE = "1")
  } else {
    Sys.unsetenv("HF_XET_HIGH_PERFORMANCE")
  }

  invisible(NULL)
}
