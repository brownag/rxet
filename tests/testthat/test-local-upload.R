context("Local upload round-trip")

# Start a local server and a client for one test. The Xet client keeps a
# shard cache under HF_HOME that is shared across processes and endpoints; a
# second upload of identical bytes is deduplicated against it and never reaches
# a fresh server. Give each test its own HF_HOME so results do not depend on
# earlier runs. Cleanup is registered on the calling test's frame.
start_upload_client <- function(env = parent.frame()) {
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
  list(client = client, endpoint = h$endpoint)
}

test_that("upload of 64 KiB returns a 64-hex hash and the exact size", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  info <- upload_fixture(client, make_fixture_bytes(65536L))
  expect_match(info$hash, "^[0-9a-f]{64}$")
  expect_identical(info$file_size, 65536)
})

test_that("64 KiB upload round-trips byte-identical with no .part leftovers", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  bytes <- make_fixture_bytes(65536L)
  info <- upload_fixture(client, bytes)
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)
  xet_download_file(client, info$hash, info$file_size, dest)
  expect_identical(readBin(dest, "raw", 65536L), bytes)
  expect_length(list.files(dirname(dest), pattern = "\\.part$"), 0)
})

test_that("4 MiB multi-chunk upload round-trips byte-identical", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  bytes <- make_fixture_bytes(4194304L)
  info <- upload_fixture(client, bytes)
  expect_identical(info$file_size, 4194304)
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)
  xet_download_file(client, info$hash, info$file_size, dest)
  expect_identical(readBin(dest, "raw", 4194304L), bytes)
})

test_that("empty file uploads as success with all-zero hash, size 0, and round-trips to 0 bytes", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  src <- tempfile(fileext = ".bin")
  on.exit(unlink(src), add = TRUE)
  file.create(src)
  info <- xet_upload_file(client, src)
  expect_match(info$hash, "^0{64}$")
  expect_identical(info$file_size, 0)
  dest <- tempfile(fileext = ".bin")
  on.exit(unlink(dest), add = TRUE)
  xet_download_file(client, info$hash, info$file_size, dest)
  expect_identical(file.size(dest), 0)
})

test_that("missing source errors before any server call", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  expect_error(
    xet_upload_file(client, "/nonexistent/path"),
    "source file does not exist"
  )
})

test_that("same bytes uploaded twice give the same hash", {
  skip_without_local_cas()
  client <- start_upload_client()$client

  bytes <- make_fixture_bytes(65536L)
  first <- upload_fixture(client, bytes)
  second <- upload_fixture(client, bytes)
  expect_identical(first$hash, second$hash)
})
