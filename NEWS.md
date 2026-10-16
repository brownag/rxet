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
