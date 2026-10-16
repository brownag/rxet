# Committed fixtures for the optional-integration tests.
# Bytes come from tests/testthat/fixtures/ (see PROVENANCE.md). Served from the
# local CAS server only; no credentials are read.

# Path to a committed fixture file.
fixture_path <- function(name) {
  test_path("fixtures", name)
}

# Start a local CAS server and a client for one test. Each test gets its own
# HF_HOME so uploads are not deduplicated against an earlier server. Cleanup is
# registered on the calling test's frame (same pattern as start_upload_client()
# in test-local-upload.R).
start_fixture_client <- function(env = parent.frame()) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  h <- start_local_cas()
  client <- xet_client_new(h$endpoint, "local-test-token")
  cleanup <- function() {
    xet_client_close(client)
    stop_local_cas(h)
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }
  do.call(on.exit, list(bquote(.(cleanup)()), add = TRUE), envir = env)
  client
}

# Upload a committed fixture to the local server. Returns list(hash, file_size, sha256).
serve_fixture <- function(client, name) {
  path <- fixture_path(name)
  upload_fixture(client, readBin(path, "raw", file.size(path)))
}
