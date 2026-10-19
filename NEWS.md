# rxet 0.2.0

Minor release with breaking changes. Each removed function or argument
has a replacement, listed below.

## Breaking changes

- `read_xet_parquet_stream()` is removed. Use `read_xet_parquet()`.
- `xet_close_connection()` is removed. Use `close()` on the connection.
- `xet_config_environment()` is removed. Use the `timeout_sec`,
  `cache_bytes` and `high_perf` arguments of `xet_client_new()`.
- The `ext` argument of `read_xet_raster()` is removed. Use `terra::crop()`.

## Features

- `xet_client_new()` gains `timeout_sec`, `cache_bytes` and `high_perf`
  arguments.
- `read_xet_vector()` gains an `ext` argument.

## Fixes

- The `high_perf` help text now says that it applies hf-xet's
  high-performance preset and does not disable the chunk cache. The cache
  claim is removed. Use `cache_bytes = 0` for no cache.

## Internal

- Removed the unused helpers in `R/utils.R` and their tests.
- Removed the unused Rust crates `tokio`, `byteorder`, `lru`,
  `crossbeam-channel` and `futures-util`.

# rxet 0.1.1

Patch release. It fixes documentation and test gaps found in the 0.1.0 review.
There is no API change: the 13 exports, their ADR 0001 tiers and their
Experimental labels are unchanged.

## Fixes

- `xet_close_connection()` returns `NULL` without error when the connection is
  already closed. Non-connection input still errors.
- The vector helper documentation no longer claims "80+ formats". It names the
  limit: only single-file formats that GDAL can identify from the file content
  are reliable, because the temporary file has no extension.
- The memory notes for `read_xet_raster()`, `read_xet_vector()`,
  `read_xet_parquet()` and `read_xet_parquet_stream()` state only what the code
  does: the whole file is read, and about one copy of the bytes is held.
- DESCRIPTION Suggests no longer lists `jsonlite` or `covr`, which nothing
  uses.
- AGENTS.md states the Rust minimum as 1.85.

## Tests

- Token canary checks now cover every offline public path: download, open
  connection, stream raw, stream range and the four `read_xet_*` helpers. Upload
  is checked on its offline validation path. Each check confirms that the token never appears in an error or warning.
- A test checks that `read_xet_parquet()` closes its connection on success.

## Internal

- Removed the unused `make_hf_api_request()`.

## Deferred

- `read_xet_vector()` has no format argument yet. It is planned for 0.2.0.

# rxet 0.1.0

First release of rxet, an R interface to Hugging Face's Xet content-addressed
storage. The API is synchronous. Tiers below follow the public API support
contract (ADR 0001).

## Features

### Client

- `xet_client_new()` create a client handle from an endpoint and token (Supported)
- `xet_client_close()` release a client handle (Supported)
- `xet_config_environment()` set the Xet environment variables for timeout, chunk cache size and high-performance mode (Supported)

### Download

- `xet_download_file()` download a file by content hash to a destination path (Experimental)
- `xet_open_connection()` open a read connection to a file's bytes (Experimental)
- `xet_close_connection()` close a connection opened with `xet_open_connection()` (Experimental)
- `xet_stream_range()` fetch a byte range of a file (Experimental)
- `xet_stream_raw()` fetch a whole file into memory as a raw vector (Experimental)

### Upload

- `xet_upload_file()` upload a local file and return its hash and size (Experimental)

### Optional helpers

These read Xet files with an optional package. Each package is listed in
Suggests and checked with `requireNamespace()`.

- `read_xet_parquet()` read a Parquet file with arrow, in memory (Experimental)
- `read_xet_parquet_stream()` read a Parquet file with arrow, through a temporary file (Experimental)
- `read_xet_raster()` read a raster file with terra (Experimental)
- `read_xet_vector()` read a single-file vector format with sf (Experimental)

## Limitations

- **Whole-download only.** The optional helpers read the entire file before they
  return. None of them stream.
- **`read_xet_parquet_stream()` is a whole-download helper, not a streaming one.**
  It downloads the whole file into memory, writes a temporary `.parquet` file,
  and reads that file.
- **2 GiB cap.** Files over 2147483647 bytes are refused before any network call.
  `read_xet_parquet_stream()` is refused by `xet_stream_raw()`. The other optional
  helpers are refused by `xet_open_connection()`. Both errors name
  `xet_download_file()`, which handles larger files.
- **Single-file vector formats only.** `read_xet_vector()` writes one temporary
  file. Multi-file formats such as shapefiles (with `.shp`, `.dbf` and `.shx`
  sidecars) are not supported.
- **Experimental.** The optional helpers are labelled "Experimental pending live
  evidence" in their documentation. The `xet_*` functions marked Experimental above
  carry the same contract tier.

## Installation prerequisites

- R (>= 4.2)
- Cargo and rustc (Rust >= 1.85). The package build checks this minimum.
- The optional helpers need arrow, terra or sf installed. They are not required
  for the core API.

## Authentication

Set your Hugging Face token in the `HF_TOKEN` environment variable before creating
a client:

```r
Sys.setenv(HF_TOKEN = "<your token>")
```

rxet does not write the token into its error output. The token-expiry fault test checks this.

## Test evidence

Recorded at the release gate (HEAD before this commit):

- Routine suite, local CAS server, arrow, terra and sf installed: 242 passed, 0 failed, 0 errors, 15 skipped.
- Clean-archive `R CMD build` and `R CMD check --no-manual` (no server or live variables): Status OK.
- Live suite (`RXET_LIVE_TESTS=1`, opt-in, live Hub token): 18 passed, 0 failed, 0 errors, 0 skipped.
