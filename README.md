
# rxet: Native R Bindings to Hugging Face Xet Storage

<!-- badges: start -->
<!-- badges: end -->

rxet provides fast, efficient access to files stored in [Hugging Face
Hub](https://huggingface.co/) using Xet’s content-addressed storage
engine. Download large ML models, datasets, and geospatial files with
minimal overhead—directly into R memory or Arrow tables, without
intermediate disk copies.

## Key Features

- **Streaming downloads** into memory without temporary files
- **Random access** — fetch specific byte ranges (10% of file in
  seconds)
- **Zero-copy integration** with Arrow, terra, sf, and GDAL
- **Parallel downloads** with automatic token refresh and retry
- **Built on Rust** for safety and performance
- **Production-ready** with panic recovery and resource cleanup

## Installation

### From source

``` r
# Install Rust (if needed)
# https://rustup.rs/

# Build and install
devtools::install()

# Or run tests first
devtools::test()
```

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
# Stream file into R (no disk required)
data <- xet_stream_raw(client, file_hash = "abc123...", file_size = 5e9)
# Returns metadata about streaming operation
```

### Random-access download

``` r
# Download only middle 500MB of 10GB file
metadata <- xet_stream_range(
  client,
  file_hash = "abc123...",
  file_size = 1e10,
  start_byte = 4.75e9,
  end_byte = 5.25e9
)
# 5-10x faster than downloading entire file
```

### Read Parquet directly

``` r
library(arrow)

df <- read_xet_parquet(
  client,
  file_hash = "parquet_hash...",
  file_size = 2.5e9,
  col_select = c("user_id", "timestamp", "value")
)
# Arrow applies filters while reading; no full file download
```

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

Typical performance on Hugging Face Hub:

| Operation                | Time         | Notes                       |
|--------------------------|--------------|-----------------------------|
| Metadata fetch           | 200-500ms    | Sequential per-file         |
| Small file (100MB)       | 1-5s         | Depends on network          |
| Medium file (1GB)        | 10-30s       | Parallel-friendly           |
| Large file (10GB)        | 2-5 min      | Parallelizes over 4 workers |
| Token refresh            | ~100ms       | Cached for 1 hour           |
| Byte-range (10% of file) | 5-10x faster | Proportional to range size  |

**Parallelism**: 4 workers typically achieve 3.0-3.8x speedup (75-95%
efficiency).

## Benchmarking

Measure performance on your workload:

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

- `xet_client_new(endpoint, token)` — Initialize client
- `xet_client_close(handle)` — Clean up client
- `xet_config_environment(...)` — Configure client behavior

### Download

- `xet_download_file(handle, hash, file_size, dest_path)` — Download to
  disk
- `xet_stream_raw(handle, file_hash, file_size)` — Stream into memory
- `xet_stream_range(handle, file_hash, file_size, start_byte, end_byte)`
  — Partial download
- `xet_get_file_metadata(handle, file_hash)` — Query chunk metadata

### Connections

- `xet_open_connection(handle, file_hash, file_size)` — R connection
  object
- `xet_close_connection(conn)` — Close connection

### Integrations

- `read_xet_parquet(handle, file_hash, file_size, ...)` — Arrow/Parquet
- `read_xet_raster(handle, file_hash, file_size, ext = NULL, ...)` —
  Raster (terra)
- `read_xet_vector(handle, file_hash, file_size, ...)` — Vector
  (sf/GDAL)

## Architecture

rxet is built in three layers:

1.  **Rust** (`src/rust/src/lib.rs`) — Core Xet client, download
    pipeline, safety
2.  **C bindings** (`src/rust/src/lib.rs` → extendr) — FFI to R
3.  **R wrappers** (`R/*.R`) — High-level API, validation, ecosystem
    integration

**Design principles:** - Panic recovery via
`std::panic::catch_unwind()` - Async I/O with Tokio (non-blocking to R
console) - Bounded channels for backpressure - LRU cache for metadata
shards - Binary search for O(log N) chunk lookup

## Testing

Run test suite:

``` r
devtools::test()

# Run specific test file
devtools::test_file("tests/testthat/test-stream-range.R")

# Test with coverage
covr::package_coverage()
```

Test suite includes: - **Mock backend**
(`tests/testthat/helper-mock-backend.R`) — In-process HTTP simulation -
**Range downloads** (`tests/testthat/test-stream-range.R`) — Byte-range
accuracy - **Concurrent clients** (`tests/testthat/test-concurrent.R`) —
Stress testing - **Edge cases** (`tests/testthat/test-edge-cases.R`) —
Boundary conditions - **Parallel downloads**
(`tests/testthat/test-parallel-downloads.R`) — Action state machine

## FAQ

**Q: Does rxet require an internet connection?** A: Yes, for actual
downloads from Hugging Face Hub. The test suite uses a mock backend that
runs offline.

**Q: Can I use rxet with private repositories?** A: Yes, with a valid
HuggingFace token that has access to the repo. Set `HF_TOKEN` before
initializing.

**Q: How does byte-range download work?** A: Xet stores files as Merkle
trees. Querying the metadata shard identifies overlapping chunks; only
those chunks are downloaded.

**Q: What file formats are supported?** A: Any file that Xet Hub stores.
Common: `.safetensors`, `.parquet`, `.tar.gz`, GeoTIFF, netCDF, etc.

**Q: How much does caching help?** A: Significant for repeated
operations on same chunk. Set `cache_bytes=0` for one-shot downloads;
keep default (10GB) for interactive analytics.

**Q: Can I use this in Shiny apps?** A: Yes. Client is thread-safe. Use
`on.exit()` to ensure cleanup, and consider connection pooling for high
throughput.

## Contributing

Contributions welcome! Please:

1.  Fork the repository
2.  Create a feature branch
3.  Add tests in `tests/testthat/`
4.  Ensure `devtools::check()` passes
5.  Submit a pull request

## License

Licensed under Apache 2.0. See LICENSE file.

## Resources

- [Hugging Face Xet
  Documentation](https://huggingface.co/docs/hub/xet/index) — Official
  Xet storage engine docs
- [Hugging Face Hub](https://huggingface.co/) — Model and dataset
  hosting

## Acknowledgments

Built with [extendr](https://extendr.github.io/),
[Tokio](https://tokio.rs/), and [Arrow](https://arrow.apache.org/).
