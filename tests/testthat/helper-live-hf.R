# Live-suite helper (opt-in, see test-live-hf.R). Loaded for every test file.

LIVE_READ_TOKEN_URL <- "https://huggingface.co/api/datasets/brownag/rxet-test-data/xet-read-token/main"

# The CAS server accepts the short-lived accessToken from the Hub's xet-read-token
# response, not the raw HF_TOKEN (raw token: HTTP 401, probe 5.3.2). Exchanging the
# token in memory keeps it out of files and out of error messages. Without HF_TOKEN
# the placeholder is returned and the live reads fail as findings, not skips.
live_cas_token <- function() {
  hf_token <- Sys.getenv("HF_TOKEN")
  if (!nzchar(hf_token)) return("anonymous")
  res <- tryCatch(
    processx::run(
      "curl",
      c("-s", "-w", "\n%{http_code}", "-H", paste0("Authorization: Bearer ", hf_token), LIVE_READ_TOKEN_URL),
      error_on_status = FALSE,
      timeout = 60
    ),
    error = function(e) stop("could not run curl to fetch the Hub read token", call. = FALSE)
  )
  lines <- strsplit(res$stdout, "\n", fixed = TRUE)[[1]]
  status <- as.integer(utils::tail(lines, 1))
  if (!identical(status, 200L)) {
    stop(sprintf("Hub xet-read-token returned HTTP %s", status), call. = FALSE)
  }
  body <- paste(utils::head(lines, -1), collapse = "\n")
  m <- regmatches(body, regexpr('"accessToken":"[^"]+"', body))
  if (!length(m)) stop("Hub xet-read-token response has no accessToken field", call. = FALSE)
  sub('^"accessToken":"', "", sub('"$', "", m))
}
