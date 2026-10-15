context("Phase 4 lifecycle and failure semantics (offline)")

# File-local helpers. Loopback only, no credentials, no real cache paths.

closed_port <- function() {
  repeat {
    port <- sample(20000:40000, 1)
    conn <- suppressWarnings(tryCatch(
      socketConnection("127.0.0.1", port, open = "r", timeout = 1),
      error = function(e) NULL
    ))
    if (is.null(conn)) return(port)
    close(conn)
  }
}

blackhole <- function() {
  repeat {
    port <- sample(20000:40000, 1)
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(srv)) return(list(port = port, srv = srv))
  }
}

# Test-run config seam: the client reads these at creation, so they are set only
# around xet_client_new(). The short read timeout keeps blackhole tests fast; the
# retry count of 1 keeps the 60 s bound reachable. Neither raises a timeout.
# Variables that were previously unset are unset again afterwards.
make_test_client <- function(endpoint, token = "test_token", read_timeout = "2s") {
  vars <- c("HF_XET_CLIENT_READ_TIMEOUT", "HF_XET_CLIENT_RETRY_MAX_ATTEMPTS")
  old <- Sys.getenv(vars, unset = NA)
  on.exit({
    for (v in vars) {
      if (is.na(old[[v]])) {
        Sys.unsetenv(v)
      } else {
        do.call(Sys.setenv, stats::setNames(list(old[[v]]), v))
      }
    }
  }, add = TRUE)
  Sys.setenv(HF_XET_CLIENT_READ_TIMEOUT = read_timeout, HF_XET_CLIENT_RETRY_MAX_ATTEMPTS = "1")
  xet_client_new(endpoint, token)
}

# Valid 64-hex-digit Merkle hash (shorter strings fail hash parsing before any network I/O).
HASH <- strrep("a", 64)

no_part_files <- function(dir, dest) {
  pattern <- paste0("^\\.", gsub(".", "\\.", basename(dest), fixed = TRUE), "-.*\\.part$")
  length(grep(pattern, list.files(dir, all.files = TRUE))) == 0
}

describe("xet_download_file failure lifecycle", {
  it("leaves no destination when the download fails against a closed port", {
    skip_if_not(is_compiled(), "Rust extension not available")
    dir <- tempfile("rxet-lifecycle-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    dest <- file.path(dir, "out.bin")

    client <- make_test_client(sprintf("http://127.0.0.1:%d", closed_port()))
    on.exit(xet_client_close(client), add = TRUE)
    expect_error(xet_download_file(client, HASH, 1024, dest))
    expect_false(file.exists(dest))
    expect_true(no_part_files(dir, dest))
  })

  it("preserves an existing destination when the download fails", {
    skip_if_not(is_compiled(), "Rust extension not available")
    dir <- tempfile("rxet-lifecycle-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    dest <- file.path(dir, "out.bin")
    writeChar("original", dest, eos = NULL)

    client <- make_test_client(sprintf("http://127.0.0.1:%d", closed_port()))
    on.exit(xet_client_close(client), add = TRUE)
    expect_error(xet_download_file(client, HASH, 1024, dest))
    expect_equal(readChar(dest, nchars = 8), "original")
    expect_true(no_part_files(dir, dest))
  })

  it("errors within the bound and leaves no destination when the server never replies", {
    skip_if_not(is_compiled(), "Rust extension not available")
    dir <- tempfile("rxet-lifecycle-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    dest <- file.path(dir, "out.bin")
    bh <- blackhole()
    on.exit(close(bh$srv), add = TRUE)

    client <- make_test_client(sprintf("http://127.0.0.1:%d", bh$port))
    on.exit(xet_client_close(client), add = TRUE)
    elapsed <- system.time(
      expect_error(xet_download_file(client, HASH, 1024, dest))
    )[["elapsed"]]
    expect_lt(elapsed, 60)
    expect_false(file.exists(dest))
    expect_true(no_part_files(dir, dest))
  })

  it("does not leak the token into the error message", {
    skip_if_not(is_compiled(), "Rust extension not available")
    dir <- tempfile("rxet-lifecycle-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    token <- "rxet-secret-token-XYZ"

    client <- make_test_client(sprintf("http://127.0.0.1:%d", closed_port()), token)
    on.exit(xet_client_close(client), add = TRUE)
    msg <- tryCatch(
      {
        xet_download_file(client, HASH, 1024, file.path(dir, "out.bin"))
        ""
      },
      error = function(e) conditionMessage(e)
    )
    expect_true(nzchar(msg))
    expect_false(grepl(token, msg, fixed = TRUE))
  })
})

describe("xet_stream_raw failure lifecycle", {
  it("errors within the bound and returns no data when the server never replies", {
    skip_if_not(is_compiled(), "Rust extension not available")
    bh <- blackhole()
    on.exit(close(bh$srv), add = TRUE)

    client <- make_test_client(sprintf("http://127.0.0.1:%d", bh$port))
    on.exit(xet_client_close(client), add = TRUE)
    result <- NULL
    raised <- FALSE
    elapsed <- system.time(
      result <- tryCatch(
        xet_stream_raw(client, HASH, 1024),
        error = function(e) {
          raised <<- TRUE
          NULL
        }
      )
    )[["elapsed"]]
    expect_lt(elapsed, 60)
    expect_true(raised)
    expect_null(result)
  })
})

describe("closed handle lifecycle", {
  it("rejects download on a handle after xet_client_close", {
    skip_if_not(is_compiled(), "Rust extension not available")
    dir <- tempfile("rxet-lifecycle-")
    dir.create(dir)
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
    dest <- file.path(dir, "out.bin")

    client <- make_test_client(sprintf("http://127.0.0.1:%d", closed_port()))
    xet_client_close(client)
    expect_error(
      xet_download_file(client, HASH, 1024, dest),
      "invalid or closed"
    )
    expect_false(file.exists(dest))
  })
})
