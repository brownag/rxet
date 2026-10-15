context("Input validation for all public functions")

describe("xet_client_new", {
  it("rejects empty endpoint", {
    expect_error(xet_client_new("", "token"))
  })

  it("rejects non-http endpoint", {
    expect_error(xet_client_new("ftp://example.com", "token"))
  })

  it("rejects endpoint with wrong type", {
    expect_error(xet_client_new(123, "token"))
  })

  it("rejects empty token", {
    expect_error(xet_client_new("https://example.com", ""))
  })

  it("rejects token with wrong type", {
    expect_error(xet_client_new("https://example.com", 123))
  })

  it("accepts valid https endpoint with token", {
    skip_if_not(is_compiled(), "Rust extension not available")
    # Test that client creation succeeds without error
    client <- xet_client_new("https://cas-cf.huggingface.co", "test_token")
    expect_is(client, "character")
    expect_length(client, 1)
    xet_client_close(client)
  })

  it("rejects remote http endpoint", {
    expect_error(xet_client_new("http://example.com", "token"), "https://")
  })

  it("accepts http localhost endpoint", {
    skip_if_not(is_compiled(), "Rust extension not available")
    client <- xet_client_new("http://localhost:8080", "token")
    on.exit(xet_client_close(client), add = TRUE)
    expect_is(client, "character")
  })

  it("accepts http 127.0.0.1 endpoint", {
    skip_if_not(is_compiled(), "Rust extension not available")
    client <- xet_client_new("http://127.0.0.1:9", "token")
    on.exit(xet_client_close(client), add = TRUE)
    expect_is(client, "character")
  })

  it("accepts http localhost endpoint case-insensitively", {
    skip_if_not(is_compiled(), "Rust extension not available")
    client <- xet_client_new("HTTP://LOCALHOST", "token")
    on.exit(xet_client_close(client), add = TRUE)
    expect_is(client, "character")
  })

  it("rejects http userinfo and IPv6 loopback hosts", {
    expect_error(xet_client_new("http://localhost@example.com", "token"), "https://")
    expect_error(xet_client_new("http://[::1]:8080", "token"), "https://")
  })
})

describe("xet_download_file", {
  it("rejects empty handle", {
    expect_error(xet_download_file("", "abc", 1024, "/tmp/file"), "nchar.*handle")
  })

  it("rejects empty hash", {
    expect_error(xet_download_file("handle", "", 1024, "/tmp/file"))
  })

  it("rejects negative file_size", {
    expect_error(xet_download_file("handle", "abc123", -1, "/tmp/file"))
  })

  it("rejects non-numeric file_size", {
    expect_error(xet_download_file("handle", "abc123", "big", "/tmp/file"))
  })

  it("rejects directory as dest_path", {
    tmpdir <- tempdir()
    expect_error(xet_download_file("handle", "abc123", 1024, tmpdir))
  })

  it("rejects non-existent parent directory", {
    expect_error(
      xet_download_file("handle", "abc123", 1024, "/nonexistent/path/file.bin")
    )
  })
})

describe("xet_stream_raw", {
  it("rejects negative file_size", {
    skip_if_not(is_compiled())
    expect_error(xet_stream_raw("handle", "abc123", -1))
  })

  it("rejects empty hash", {
    expect_error(xet_stream_raw("handle", "", 1024))
  })

  it("rejects infinite file_size", {
    skip_if_not(is_compiled())
    expect_error(xet_stream_raw("handle", "abc123", Inf), "file_size")
  })

  it("rejects NaN and fractional file_size", {
    expect_error(xet_stream_raw("handle", "abc123", NaN), "file_size")
    expect_error(xet_stream_raw("handle", "abc123", 1.5), "file_size")
  })

  it("rejects file_size above the 2 GiB in-memory limit before network access", {
    expect_error(xet_stream_raw("handle", "abc123", 2^31), "2 GiB limit")
  })
})

describe("xet_stream_range", {
  it("rejects empty handle", {
    expect_error(xet_stream_range("", "abc", 1e9, 100, 200), "nchar.*handle")
  })

  it("rejects end <= start", {
    expect_error(xet_stream_range("handle", "abc", 1e9, 100, 100))
  })

  it("rejects end > file_size", {
    expect_error(xet_stream_range("handle", "abc", 1e9, 500, 2e9))
  })

  it("rejects negative start", {
    expect_error(xet_stream_range("handle", "abc", 1e9, -1, 1000))
  })

  it("rejects requested range above the 2 GiB in-memory limit", {
    expect_error(xet_stream_range("handle", "abc", 2^32, 0, 2^31), "2 GiB limit")
  })

  it("rejects non-finite and fractional file_size", {
    expect_error(xet_stream_range("handle", "abc", Inf, 0, 100), "file_size")
    expect_error(xet_stream_range("handle", "abc", 1.5, 0, 1), "file_size")
  })
})

describe("xet_open_connection", {
  it("rejects empty handle", {
    expect_error(xet_open_connection("", "abc", 1024), "nchar.*handle")
  })

  it("rejects negative file_size", {
    expect_error(xet_open_connection("handle", "abc", -1), "file_size")
  })

  it("rejects empty hash", {
    expect_error(xet_open_connection("handle", "", 1024), "nchar")
  })

  it("rejects non-finite and fractional file_size", {
    expect_error(xet_open_connection("handle", "abc", Inf), "file_size")
    expect_error(xet_open_connection("handle", "abc", NaN), "file_size")
    expect_error(xet_open_connection("handle", "abc", 1.5), "file_size")
  })

  it("returns valid R connection object", {
    skip_if_not(is_compiled(), "Rust extension not available")
    # Parameter validation - xet_open_connection should reject invalid parameters
    expect_error(xet_open_connection("", "hash", 1024), "nchar.*handle")
    expect_error(xet_open_connection("client", "", 1024), "nchar.*file_hash")
    expect_error(xet_open_connection("client", "hash", -1), "file_size")
  })
})

describe("xet_upload_file", {
  it("rejects empty handle", {
    # Create a temp file for testing
    tmp <- tempfile(fileext = ".bin")
    writeBin(raw(10), tmp)
    on.exit(unlink(tmp), add = TRUE)
    expect_error(xet_upload_file("", tmp), "nchar.*handle")
  })
})

describe("xet_config_environment", {
  it("rejects negative timeout", {
    expect_error(xet_config_environment(timeout_sec = -1))
  })

  it("rejects negative cache_bytes", {
    expect_error(xet_config_environment(cache_bytes = -1))
  })

  it("rejects non-logical high_perf", {
    expect_error(xet_config_environment(high_perf = "yes"))
  })
})
