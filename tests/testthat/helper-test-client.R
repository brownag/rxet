#' Create a test client and run code, ensuring cleanup
#'
#' Helper to reduce boilerplate in tests that need a client.
#'
#' @param expr Expression to evaluate with client available
#' @param endpoint Character string, endpoint URL (default: dummy)
#' @param token Character string, token (default: dummy)
#'
#' @return Result of expr
#' @keywords internal
with_test_client <- function(expr, endpoint = "https://cas-cf.huggingface.co", token = "test_token") {
  client <- xet_client_new(endpoint, token)
  on.exit(xet_client_close(client), add = TRUE)
  # Pass client into the parent environment so expressions can reference it
  # This is a workaround for testthat's quosure handling
  parent_env <- parent.frame()
  parent_env$client <- client
  on.exit(rm("client", envir = parent_env), add = TRUE)
  eval(substitute(expr), envir = parent_env)
}
