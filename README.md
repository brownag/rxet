
# rxet: Native R Bindings to Hugging Face Xet Storage

<!-- badges: start -->
<!-- badges: end -->

rxet provides native access to files stored in [Hugging Face
Hub](https://huggingface.co/) using Xet’s content-addressed storage
engine. A download buffers the whole file through a single blocking Rust
client bound to R, then hands the bytes back to R — either as a `raw()`
vector in memory or written to a destination path on disk. Disk
downloads go to a temporary file beside the destination and are renamed
into place only on success, so a failed download leaves an existing file
untouched.

## Key Features

- **Native Rust client** bound to R via extendr (no Python bridge)
- **Whole-file downloads** into R memory (`raw()`) or to a destination
  path on disk
- **Ecosystem helpers** that wrap downloaded bytes for Arrow, terra, and
  sf/GDAL
- **Handle-based sessions** keyed by a character UUID and released with
  `xet_client_close()`

## Installation

### From source

Prerequisites:

- R (>= 4.2)
- Rust toolchain (>= 1.85.0), installed from [rustup.rs](https://rustup.rs/)
- Cargo (included with the Rust toolchain)
- Network access to crates.io on the first build, which compiles the
  Rust `hf-xet` client

From a source checkout, run:

``` sh
R CMD INSTALL .
```

Alternatively, from an R session in the checkout:

``` r
# Build and install
devtools::install()

# Or run tests first
devtools::test()
```

## Authentication

rxet uses the bearer token you pass to `xet_client_new()`. The examples
read it from the `HF_TOKEN` environment variable. Set `HF_TOKEN` in your
session or in `~/.Renviron`, not in code you commit. rxet does not write
the token into its error output; the token-expiry fault test checks
this.

## Quick Start

### Initialize a client and download

``` r
library(rxet)

# Set token (from https://huggingface.co/settings/tokens)
Sys.setenv(HF_TOKEN = "hf_...")

# Connect to Xet storage
client <- xet_client_new(
  "https://cas-cf.huggingface.co",
  Sys.getenv("HF_TOKEN")
)
on.exit(xet_client_close(client))

# Download a file to disk
xet_download_file(
  client,
  hash = "abc123def456...",
  file_size = 1.5e9,
  dest_path = "./model.safetensors"
)
```

### Stream into memory

``` r
# Download the whole file into R as a raw() vector (no disk copy)
data <- xet_stream_raw(client, file_hash = "abc123...", file_size = 5e9)
```

### Random-access download

``` r
# Download only the bytes in [start_byte, end_byte) of a 10GB file
chunk <- xet_stream_range(
  client,
  file_hash = "abc123...",
  file_size = 1e10,
  start_byte = 4.75e9,
  end_byte = 5.25e9
)
```

The return value is a `raw()` vector containing the requested byte
range.

### Read Parquet directly

``` r
library(arrow)

df <- read_xet_parquet(
  client,
  file_hash = "parquet_hash...",
  file_size = 2.5e9,
  col_select = c("user_id", "timestamp", "value")
)
```

The whole file is downloaded into memory first, then parsed by Arrow.

### Read geospatial data

``` r
library(terra)

# Read GeoTIFF directly from Xet
dem <- read_xet_raster(
  client,
  file_hash = "geotiff_hash...",
  file_size = 3.2e9
)

# Crop to region of interest
roi <- terra::ext(c(100, 105, 20, 25))
dem_roi <- terra::crop(dem, roi)
```

## Configuration

### Environment variables

Control client behavior before initialization:

``` r
# Increase timeout for slow networks
xet_config_environment(timeout_sec = 600)

# Disable cache for one-shot downloads
xet_config_environment(cache_bytes = 0)

# Enable high-performance mode
xet_config_environment(high_perf = TRUE)

client <- xet_client_new(endpoint, token)
```

Options: - `HF_XET_CLIENT_READ_TIMEOUT` — Network read timeout (default
300s) - `HF_XET_CHUNK_CACHE_SIZE_BYTES` — Chunk cache size (default 10
GiB) - `HF_XET_HIGH_PERFORMANCE` — Disable cache for throughput (default
false)

## Performance

rxet v0.1 makes no throughput or concurrency claims. Each handle holds a
single blocking client, and calls are serialized; caching and network
behaviour come from the underlying Xet engine and are not benchmarked
here.

## Benchmarking

Measure behavior on your workload:

``` bash
# Basic benchmark
Rscript tools/benchmark.R models.json

# Detailed latency breakdown
Rscript tools/benchmark-extended.R models.json

# Memory and worker scaling analysis
Rscript tools/benchmark-extended.R models.json --memory --workers
```

See `tools/README.md` for interpretation guide.

## API Reference

### Client Management

- `xet_client_new(endpoint, token)` — Initialize a client handle
- `xet_client_close(handle)` — Release a client handle
- `xet_config_environment(...)` — Configure client behavior via
  environment variables

### Download and upload

- `xet_download_file(handle, hash, file_size, dest_path)` — Download a
  file to disk
- `xet_upload_file(handle, src_path)` — Upload a local file
- `xet_stream_raw(handle, file_hash, file_size)` — Download a whole file
  into memory as `raw()`
- `xet_stream_range(handle, file_hash, file_size, start_byte, end_byte)`
  — Download `[start_byte, end_byte)` as `raw()`

### Connections

- `xet_open_connection(handle, file_hash, file_size)` — Wrap downloaded
  bytes in an R connection
- `xet_close_connection(conn)` — Close the connection

### Integrations

- `read_xet_parquet(handle, file_hash, file_size, ...)` — Arrow/Parquet
- `read_xet_parquet_stream(handle, file_hash, file_size, ...)` —
  Arrow/Parquet via a temporary file
- `read_xet_raster(handle, file_hash, file_size, ext = NULL, ...)` —
  Raster (terra)
- `read_xet_vector(handle, file_hash, file_size, ...)` — Vector
  (sf/GDAL)

## Architecture

rxet is built in three layers:

1.  **Rust** (`src/rust/src/lib.rs`) — Core Xet client and download
    pipeline
2.  **C bindings** (`src/rust/src/lib.rs` → extendr) — FFI to R
3.  **R wrappers** (`R/*.R`) — High-level API, validation, ecosystem
    integration

**Design principles:** - Panic recovery via
`std::panic::catch_unwind()` - Synchronous design: each network
operation calls xet-core’s `*.blocking()` API on the calling R thread -
A `Registry<T>` (`src/rust/src/registry.rs`) maps each character UUID
handle to its client behind a mutex, and reports a poisoned lock as an
error rather than as an unknown handle - Whole-file
buffering: downloads materialize the complete file in memory or on disk;
there is no remote partial-read path; in-memory reads
(`xet_stream_raw()`, `xet_stream_range()`, `xet_open_connection()`) are
capped at 2 GiB (2^31 − 1 bytes) and error above that, so use
`xet_download_file()` for larger files

## Testing

Routine offline suite (no credentials, no server, no network):

``` r
devtools::test()
```

Fault tests (always run, offline): `test-fault-midstream.R` and
`test-fault-token.R` use a loopback fault server (127.0.0.1, run in a
processx child process, helper `helper-fault-cas.R`). They need no
`RXET_LOCAL_CAS_SERVER`, no network and no `HF_TOKEN`. The mid-stream test
ends the response body early and expects an error, no destination file and
no `.part` file. The token-expiry test answers 401 and checks that the token
does not appear in the error. Real token expiry is checked manually and is
never waited for. These files skip only when the compiled extension is
absent.

Local-server tests (uploads and local round trips) run against the
upstream `local_cas_server`. Install it with
`cargo install xet-client --version 1.7.0 --features simulation --bin local_cas_server --locked`,
then set `RXET_LOCAL_CAS_SERVER` to the binary path. Without it, these
tests skip.

Live tests are on demand only and never run in public CI. They require
`RXET_LIVE_TESTS=1` and `HF_TOKEN` (fine-grained read on the dataset
`brownag/rxet-test-data`). Without `HF_TOKEN` they fail rather than skip.
The live fixtures are `multichunk_16mib.bin` and `geotiff_512x512_utm33n.tif`
at the top level of that dataset.

Public CI runs the local-server suite once task 5.4.1 lands; CI
execution is not yet validated until the first push.

## FAQ

**Q: Does rxet require an internet connection?** A: Yes, for real
downloads from Hugging Face Hub. The routine test suite runs offline without
a network connection.

**Q: Can I use rxet with private repositories?** A: Yes, if your token
grants access to the repository. `xet_client_new(endpoint, token)` takes
the bearer token explicitly, so pass `Sys.getenv("HF_TOKEN")` (or
another token with repo access) when creating the client.

**Q: How does byte-range download work?** A: `xet_stream_range()`
returns the requested bytes as a `raw()` vector. The Xet client resolves
the content for the requested `[start_byte, end_byte)` range; rxet
performs no chunk-level scheduling of its own.

**Q: What file formats are supported?** A: Any file that Xet Hub stores.
Common: `.safetensors`, `.parquet`, `.tar.gz`, GeoTIFF, netCDF, etc.

**Q: How much does caching help?** A: Caching behaviour is controlled by
the underlying Xet client through `HF_XET_CHUNK_CACHE_SIZE_BYTES`. Set
`cache_bytes = 0` to disable the cache, or leave the default in place
for repeated access.

**Q: Can I use this in Shiny apps?** A: rxet calls are synchronous and
block the calling R thread. In a standard single-threaded Shiny app that
is workable if long downloads are kept off the UI path. Do not assume
the client is safe for concurrent use from multiple R threads, and
always release handles with `on.exit(xet_client_close(...))`.
`xet_client_close()` invalidates a handle immediately: later calls on it
error, while an operation already in flight finishes normally.

## v0.1 status

This release documents two tiers of API. All 13 exported functions are
listed; the split reflects available evidence, not intent.

**Supported:**

- `xet_client_new` — create a client handle
- `xet_client_close` — release a client handle
- `xet_config_environment` — set Xet client environment variables

**Experimental (pending live evidence):**

- `xet_download_file` — download a file to a destination path
- `xet_upload_file` — upload a local file
- `xet_stream_raw` — download a whole file into a `raw()` vector (in
  memory; 2 GiB cap)
- `xet_stream_range` — download a byte range into a `raw()` vector (in
  memory; 2 GiB cap)
- `xet_open_connection` — expose downloaded bytes as an R connection (in
  memory; 2 GiB cap)
- `xet_close_connection` — close that connection
- `read_xet_parquet` — experimental helper; read a Parquet file through
  Arrow from an in-memory connection (2 GiB cap)
- `read_xet_parquet_stream` — experimental helper; downloads the whole
  file, then reads a temporary Parquet file (2 GiB cap)
- `read_xet_raster` — experimental helper; downloads the whole file to a
  temporary file, then reads it through terra
- `read_xet_vector` — experimental helper; downloads the whole file to a
  temporary file, then reads it through sf/GDAL (single-file formats
  only)

The experimental functions are exported and usable, but their end-to-end
behavior against a live Xet endpoint has not yet been verified in this
repository. The optional helpers read whole files: they are not
streaming, and in-memory reads are capped at 2 GiB. Use
`xet_download_file()` for larger files.

See [NEWS.md](NEWS.md) for release notes.

## Contributing

Contributions welcome! Please:

1.  Fork the repository
2.  Create a feature branch
3.  Add tests in `tests/testthat/`
4.  Ensure `devtools::check()` passes
5.  Submit a pull request

## License

Licensed under Apache 2.0. See the LICENSE.md file.

## Resources

- [Hugging Face Xet
  Documentation](https://huggingface.co/docs/hub/xet/index) — Official
  Xet storage engine docs
- [Hugging Face Hub](https://huggingface.co/) — Model and dataset
  hosting

## Acknowledgments

Built with [extendr](https://extendr.github.io/),
[Tokio](https://tokio.rs/), and [Arrow](https://arrow.apache.org/).
