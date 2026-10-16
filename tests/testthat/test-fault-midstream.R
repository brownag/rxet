# Mid-stream term drop (6.2.1). The fault server sends a valid V1 reconstruction,
# then the first half of the term body, then closes. No real endpoint is used.

# Run call_fn(client) against a fresh fault server with a private HF_HOME.
# Returns the error or value, plus elapsed seconds. Cleanup is on.exit.
run_fault_case <- function(call_fn) {
  old_hf_home <- Sys.getenv("HF_HOME", unset = NA)
  Sys.setenv(HF_HOME = tempfile("hf_home_"))
  on.exit({
    if (is.na(old_hf_home)) Sys.unsetenv("HF_HOME") else Sys.setenv(HF_HOME = old_hf_home)
  }, add = TRUE)

  h <- start_fault_cas()
  on.exit(stop_fault_cas(h), add = TRUE)
  client <- make_fault_client(h$endpoint)
  on.exit(xet_client_close(client), add = TRUE)

  start <- Sys.time()
  res <- tryCatch(call_fn(client), error = function(e) e)
  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
  list(res = res, elapsed = elapsed, reqs = fault_requests(h))
}

test_that("mid-stream term drop: xet_download_file errors, no dest, no .part", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")

  dir <- tempfile("rxet-fault-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  dest <- file.path(dir, "out.bin")

  out <- run_fault_case(function(client) {
    xet_download_file(client, FAULT_HASH, FAULT_TERM_LEN, dest)
    NULL
  })

  expect_s3_class(out$res, "error")
  expect_false(grepl(FAULT_TOKEN, conditionMessage(out$res), fixed = TRUE))
  expect_lt(out$elapsed, 60)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
  expect_false(file.exists(dest))
  expect_length(list.files(dir, all.files = TRUE, pattern = "\\.part$"), 0)
})

test_that("mid-stream term drop: xet_stream_raw errors and returns no value", {
  skip_if_not(is_compiled(), "Rust extension not available")
  skip_if_not_installed("processx")

  out <- run_fault_case(function(client) xet_stream_raw(client, FAULT_HASH, FAULT_TERM_LEN))

  expect_s3_class(out$res, "error")
  expect_false(is.raw(out$res))
  expect_false(grepl(FAULT_TOKEN, conditionMessage(out$res), fixed = TRUE))
  expect_lt(out$elapsed, 60)
  expect_true(any(grepl("^GET /xorb/", out$reqs)))
})
