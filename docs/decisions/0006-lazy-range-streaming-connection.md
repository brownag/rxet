# 0006. Lazy range streaming through a custom R connection

- **Status:** Accepted
- **Date:** 2026-11-01
- **Supersedes:** none
- **Superseded by:** none

## Context

Every read path downloaded a whole file before returning. `read_xet_parquet()`
buffered the file into memory and handed Arrow a `rawConnection()`, so
`col_select` saved Arrow work but not transfer, and the file had to fit in RAM.

Xet already supports everything a lazy reader needs:

- `XetDownloadStreamGroup::download_stream_blocking(file_info, Some(range))`
  reconstructs only the requested byte range, and the range goes to the server,
  which returns per-xorb multi-range fetch descriptors. A footer read does not
  pull the file or a whole xorb.
- One stream group owns a connection pool and an auth token; streams created
  from it reuse both.
- Each stream costs one reconstruction metadata round trip. hf-xet 1.7.0 has no
  metadata cache.

The blocker is on the R side. Arrow's R `InputStream` and `RandomAccessFile`
classes wrap C++ pointers, so R subclassing does not dispatch. Arrow does wrap
plain R connections, but R exposes no API for defining a connection type from R
code.

## Decision

1. Add a reader type in Rust: one `XetDownloadStreamGroup` per open reader, plus
   a cache of fetched windows. `xet_reader_read(handle, offset, length)` serves a
   read from cache or fetches a window that covers it.
2. Window rules: start aligned to 64 KiB, size `file_size / 32` clamped to
   1–16 MiB, doubling while reads keep moving forward inside the newest window.
   Keep up to 64 MiB of windows per connection.
3. Add a custom R connection in `src/connection.c` (`R_new_custom_connection()`,
   first available in R 4.3.0). It is binary, readable, and seekable. Its read
   callback calls an R closure that calls `xet_reader_read()`.
4. Expose `xet_open_stream_connection()`. Bind the reader's lifetime to the
   connection: C preserves the closure, releases it in `destroy`, and a
   finalizer on an environment captured by the closure then closes the reader.
5. Switch `read_xet_parquet()` to that connection. Keep the temp-file path
   (`xet_download_file()` into `tempfile()`) for terra and sf, which need a path
   and use the extension for driver detection.

## Consequences

Measured against the local CAS server, 21-column, 34 MB Parquet:

| Read | Requests | Bytes | Share of file |
|---|---|---|---|
| 2 of 21 columns | 4 | 7.6 MB | 22% |
| all 21 columns | 7 | 34.5 MB | 101% |

- Selecting a subset of columns now reduces transfer, not just Arrow's work.
- A full scan costs a handful of requests, so the per-stream metadata round trip
  is amortized. A random-access pattern costs one round trip per window.
- Readahead means partial reads over-fetch. For small files the floor is 1 MiB
  per window, so a 2 KB footer read on a 100 KB file fetches 1 MiB.
- Only 64 MiB of windows are cached, so columns read far apart refetch from
  scratch unless the hf-xet chunk cache still holds the xorb bytes.
- The new function needs R >= 4.3.0. The package still builds on older R; the
  constructor errors there and everything else is unaffected.
- `src/connection.c` uses `R_ext/Connections.h`, which R marks as not part of
  its API and not guaranteed to stay compatible. The file is guarded by
  `R_VERSION >= R_Version(4, 3, 0)` and a fallback stub.
