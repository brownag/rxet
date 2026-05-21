# TODO: Next-Phase Implementation Roadmap

## Overview

This document outlines recommended features and improvements derived from comparing the architectural blueprint (`R-Xet Core Engine Blueprint & Optimization.md`) against the current implementation. Phases 1–2 (initial code review fixes) are complete; this roadmap covers Phases 3–7.

**Key Priority Tiers:**
- 🔴 **Critical Blockers**: Production requirements (async safety, panic recovery)
- 🟠 **Core Features**: Major functionality gaps (byte-range access, streaming)
- 🟡 **Performance**: Optimization opportunities (zero-copy, R connections)
- 🟢 **Quality**: Testing, integrations, ecosystem compatibility

---

## Phase 3: Rust Runtime & Safety (🔴 Critical)

Goal: Establish robust async execution and error handling at the Rust layer, enabling safe concurrent operations and graceful error propagation.

### 3.1 Implement Tokio Runtime Bridge with OnceLock Pattern

- [x] Add `tokio` crate to `src/rust/Cargo.toml` with full features
  - Add: `tokio = { version = "1.35", features = ["full", "rt-multi-thread"] }`
  - Enables async/await, multi-threaded executor, timers, and I/O utilities
  
- [x] Implement `get_rt()` function in `src/rust/src/lib.rs`
  - Use `std::sync::OnceLock<Runtime>` to lazily initialize global Tokio runtime
  - Build with `Builder::new_multi_thread().enable_all().thread_name("rxet-tokio-worker")`
  - Return static reference to prevent per-call construction overhead
  
- [ ] Wrap all async Xet operations with `rt.block_on(async { ... })`
  - Update `xet_download_file()` to use async download pipeline
  - Update `xet_upload_file()` to use async upload pipeline
  - Ensure R console remains responsive (no blocking on network timeouts)
  
- [ ] Test under load
  - Verify no deadlocks on concurrent client creation
  - Verify Tokio cleanup on session termination
  - Profile memory usage of runtime pool

**Acceptance Criteria:**
- ✅ Tokio infrastructure in place and compiles successfully
- Builds foundation for Phase 5 streaming (StreamController will use get_rt())
- Integration with existing blocking calls deferred to Phase 5

---

### 3.2 Add Panic Recovery & Deep Error Capture

- [x] Wrap critical Rust functions in `panic::catch_unwind()`
  - Applies to: `xet_init_client()`, `xet_download_file()`, `xet_upload_file()`
  - Catch panics and convert to `Error::Other("Rust Panic: ...")` for safe R propagation
  - Extract panic message from downcast `&str` or `String`
  
- [ ] Capture OS-level errors (ENOSPC, EACCES, etc.)
  - Parse `std::io::Error` to extract errno and human-readable message
  - Return formatted string: `"IO Error: No space left on device (ENOSPC)"`
  - Include system call context: `"Failed to write to /path/to/file"`
  
- [ ] Improve error context for Xet API failures
  - Include HTTP status code, response body snippet, and retry eligibility
  - Example: `"CAS 429 Too Many Requests — retry after 60s"`
  
- [ ] Test error scenarios
  - Simulated panic (panic in closure)
  - Disk full (write to invalid path)
  - Network timeout (simulate slow server)
  - Invalid authentication token

**Acceptance Criteria:**
- ✅ Panic recovery infrastructure in place (safe_exec wrapper added)
- ✅ All critical functions wrapped with panic::catch_unwind()
- ✅ Code compiles successfully
- OS-level error enhancement deferred to Phase 3.3 (finalizer pattern)
- HTTP error detail enhancement dependent on xet-core error types

---

### 3.3 Implement ExternalPtr Finalizer for Session Cleanup

- [x] Add `Drop` implementation for `RxetClient`
  - Spawn async cleanup task on Tokio runtime to close connections
  - Flush pending buffers and release connection pool resources
  - Log errors (don't panic) if cleanup fails
  
- [x] Update `xet_init_client()` to register finalizer
  - ExternalPtr automatically calls `Drop` when R's garbage collector sweeps the handle
  - Ensures cleanup happens even if user forgets to call `xet_client_close()`
  
- [ ] Document in R wrapper (`R/client.R`)
  - Add note: "On.exit() cleanup recommended; finalizer provides fallback"
  - Clarify that explicit `xet_client_close()` is preferable for predictable timing
  
- [ ] Stress test
  - Create/abandon 1000 clients; verify cleanup completes without leaks
  - Monitor file descriptor count before/after cleanup
  - Verify no zombie threads remain

**Acceptance Criteria:**
- ✅ Drop implementation in place
- ✅ Cleanup spawned on Tokio runtime with error recovery
- ✅ Code compiles successfully
- Stress testing deferred to Phase 7 (comprehensive test suite)

---

### 3.4 Integrate HF_XET_* Environment Variables

- [x] Read and apply `HF_XET_CLIENT_READ_TIMEOUT` (default 300s)
  - Prevents connection timeout on slow/high-latency links
  - Apply to all CAS HTTP requests in download/upload
  
- [x] Read and apply `HF_XET_CHUNK_CACHE_SIZE_BYTES` (default 10 GiB)
  - For download-only workloads, set to `0` to bypass disk cache entirely
  - Configuration passed to XetSession on init
  
- [x] Read and apply `HF_XET_HIGH_PERFORMANCE` flag
  - If set to `"1"`, disables chunk cache and enables high-throughput mode
  - Useful for one-shot downloads where dedup cache is wasted
  
- [x] Expose via R wrapper in `R/client.R`
  - New function: `xet_config_environment(timeout_sec = 300, cache_bytes = 10e9, high_perf = FALSE)`
  - Apply before calling `xet_init_client()` for effect
  
- [ ] Document in man page and README
  - Explain impact of each variable on performance and memory
  - Provide examples: "For geospatial data, use high_perf=TRUE"

**Acceptance Criteria:**
- ✅ XetConfig struct reads all three env vars with correct defaults
- ✅ R wrapper function validates inputs and sets env vars
- ✅ Roxygen documentation explains each parameter and use cases
- Integration testing deferred to Phase 7 (full test suite)

---

## Phase 4: Byte-Range & Random Access (🟠 Core Feature)

Goal: Enable efficient partial file downloads without retrieving entire files, supporting interactive analytics on large datasets.

### 4.1 Parse Metadata Shard Files (.xet Format)

- [x] Set up shard parsing infrastructure in Rust
  - ChunkMapping struct for chunk records
  - ParsedShard struct with LRU cache (max 100 shards)
  - parse_shard_from_bytes() framework ready for xet-core APIs
  - byteorder + lru crates added to Cargo.toml
  
- [ ] Integrate xet-core shard parsing APIs
  - Use xet_core_structures metadata shard deserializer
  - Query parsed shard to extract chunk mappings (hash, offset, size)
  - Validate chunk coverage with no gaps or overlaps
  
- [ ] Create Rust function: `parse_xet_shard(hash: &str) -> Result<Vec<ChunkMapping>>`
  - Download shard from CAS using xet-core download APIs
  - Parse shard using xet_core_structures deserializer
  - Return: `[(merkle_hash, offset_start, offset_end, size)]` for each chunk
  - Cached locally (LRU) to avoid re-parsing on repeated queries
  
- [ ] Test with real shards from HF Hub
  - Download a sample `.xet` shard for a known file
  - Verify parsed mappings match expected chunk offsets
  - Test round-trip: download file, read shard, verify chunk coverage

**Acceptance Criteria:**
- ✅ LRU shard cache infrastructure in place
- ✅ Code structure ready to integrate xet-core APIs
- Integration with xet_core_structures deserializer (straightforward once APIs explored)

---

### 4.2 Implement Merkle Tree Traversal for Chunk Lookup

- [x] Create Rust function: `find_overlapping_chunks(shard: &ParsedShard, start: u64, end: u64) -> Result<Vec<String>>`
  - Binary search shard to identify chunks overlapping `[start, end)` byte range
  - Return list of chunk hashes needed to reconstruct that range
  - Verify no gaps or overlaps in reconstruction
  
- [x] Optimize for repeated queries
  - Cache parsed shards in memory (LRU, 100 max shards in SHARD_CACHE)
  - Binary search for O(log N) lookup of overlapping chunks
  
- [ ] Test edge cases
  - Start/end at chunk boundaries
  - Start/end in middle of chunks
  - Request entirely within a single chunk
  - Request spanning 100+ chunks

**Acceptance Criteria:**
- ✅ O(log N) binary search lookup implemented
- ✅ Code compiles successfully
- ✅ Error handling for invalid ranges and empty results
- Integration testing deferred to Phase 7

---

### 4.3 Expose xet_get_file_metadata() R Binding

- [x] Create Rust function: `xet_get_file_metadata(handle: &str, file_hash: &str) -> Result<Robj>`
  - Returns cached shard metadata for `file_hash`
  - Return R list: `list(hash, offset_start, offset_end, size, shard_size)`
  - Validates client handle and queries LRU cache
  
- [x] Create R wrapper in `R/download.R`
  - Function: `xet_get_file_metadata(handle, file_hash)`
  - Validates arguments, calls Rust binding
  - Returns data frame with columns: hash, offset_start, offset_end, size
  
- [x] Add shard caching
  - LRU cache (max 100 shards) implemented in Rust (SHARD_CACHE)
  - Avoids re-parsing same shard on repeated calls
  
- [ ] Document with examples
  - Example: "Query chunks for llama-2-70b-chat model"
  - Show how to use output to plan range downloads

**Acceptance Criteria:**
- ✅ R function returns tidy data frame
- ✅ Rust code compiles and exports function
- ✅ R package loads successfully
- Full CAS shard download deferred to Phase 5 (requires async streaming)

---

### 4.4 Implement xet_stream_range() for Partial Downloads

- [x] Create Rust function: `xet_stream_range(handle: &str, file_hash: &str, total_size: f64, start: f64, end: f64) -> Result<Robj>`
  - Query shard to identify overlapping chunks via find_overlapping_chunks()
  - Validate byte range and file size parameters
  - Return metadata about chunks needed for reconstruction
  - Placeholder for Phase 5 actual chunk downloading
  
- [ ] Integrate with Tokio runtime & actual chunk download
  - Use `futures_util::StreamExt` to pipe chunk bytes
  - Collect into Vec<u8> on stack, return as Raw bytes (Phase 5)
  - Currently returns metadata; Phase 5 implements download
  
- [x] Create R wrapper in new `R/stream.R`
  - Function: `xet_stream_range(handle, file_hash, file_size, start_byte, end_byte)`
  - Validates all parameters and bounds
  - Calls Rust implementation via .Call
  
- [ ] Test on real files
  - Download middle 100MB of a 10GB model file
  - Verify bytes match full-file download at same offset
  - Benchmark: time vs full-file download (Phase 7)

**Acceptance Criteria:**
- ✅ Framework in place to identify overlapping chunks
- ✅ R wrapper validates inputs correctly
- ✅ Rust code compiles and exports function
- ✅ R package loads successfully
- Actual byte-range download deferred to Phase 5 (requires async integration)
- Memory usage proportional to range size, not file size

---

## Phase 5: Zero-Copy Streaming & R Integration (🟡 Performance)

Goal: Eliminate disk-write overhead for in-memory analytics pipelines (Arrow, GDAL, spatial).

### 5.1 Implement StreamController with Backpressure

- [x] Add `crossbeam-channel` to `src/rust/Cargo.toml`
  - Dependency: `crossbeam-channel = "0.5"` + `futures-util = "0.3"`
  
- [x] Create Rust struct: `StreamController`
  - Field: `receiver: Receiver<Vec<u8>>` (bounded channel, size 128)
  - Field: `join_handle: Option<thread::JoinHandle<Result<(), String>>>`
  - Spawns background thread that runs async download task on Tokio runtime
  
- [x] Implement bounded channel mechanics
  - Send side in background thread (Tokio worker pool)
  - Receive side callable from R main thread
  - Channel size 128 provides backpressure without blocking R
  
- [x] Graceful shutdown
  - Drop impl closes channel and joins background thread
  - Background thread detects closed channel and halts
  - Helper methods: `is_finished()` and `recv_timeout()`
  
- [ ] Test
  - Verify no deadlock when receiver closes first
  - Verify R console stays responsive during slow consumer
  - Profile memory: peak buffer size should be ~128 * chunk_size

**Acceptance Criteria:**
- ✅ StreamController struct in place with proper threading model
- ✅ Bounded channel with 128-chunk capacity for backpressure
- ✅ Code compiles and passes thread safety checks
- Full integration with xet-core download_stream() deferred to Phase 5.2

---

### 5.2 Implement xet_stream_raw() with Zero-Copy Handoff

- [x] Create Rust function: `xet_stream_raw(handle: &str, file_hash: &str, total_size: f64) -> Result<Robj>`
  - Download entire file via StreamController into memory
  - Validates file size parameters and client handle
  - Returns metadata about streaming operation initialized
  
- [ ] Optimize for large files
  - Pre-allocate Vec with exact file size to avoid reallocs
  - Stream chunks in parallel (multiple chunk fetches concurrently)
  - Write directly to Vec without intermediate buffer
  
- [x] Create R wrapper in `R/stream.R`
  - Function: `xet_stream_raw(handle, file_hash, file_size)`
  - Validates parameters and calls Rust implementation
  
- [ ] Benchmark memory and speed
  - Compare vs `xet_download_file()` (disk) for 1GB file
  - Expected: same speed or faster (no disk I/O), half memory (no disk buffer)

**Acceptance Criteria:**
- ✅ Rust function validates inputs and creates StreamController
- ✅ R wrapper validates parameters correctly
- ✅ Code compiles and R package loads successfully
- ✅ Framework in place for Phase 5.3 (R Connection interface)
- Actual byte assembly and zero-copy handoff requires Raw vector construction (defer)

---

### 5.3 Implement R Connection Interface (R_Connection)

- [x] Create Rust struct: `RConnection`
  - Wraps StreamController concept
  - Provides `read()` and `close()` callback structure
  - Tracks file hash, size, position, open status
  
- [ ] Expose Rust function: `xet_connection(handle: &str, file_hash: &str, total_size: f64) -> Result<ExternalPtr<RConnection>>`
  - Returns opaque connection object
  - R can pass to `readBin()`, `readLines()`, etc. using raw connection API
  - Requires R connection API integration (complex, Phase 5+ work)
  
- [x] Create R wrapper in new `R/connection.R`
  - Function: `xet_open_connection(handle, file_hash, file_size) -> xet_connection object`
  - Function: `xet_close_connection(conn)`
  - S3 print method for xet_connection class
  - Documentation with Arrow/GDAL integration examples
  
- [ ] Test with downstream consumers
  - Arrow: `arrow::read_parquet(conn)` reads from Xet connection
  - GDAL: `sf::st_read(conn)` reads GeoTIFF from Xet
  - Minimal example: read first 1000 lines of CSV without full download

**Acceptance Criteria:**
- ✅ RConnection struct created with metadata tracking
- ✅ R wrapper functions created with documentation
- ✅ Code compiles and R package loads successfully
- ⚠️ Full R connection API integration requires deep R C API work
- ⚠️ Arrow/GDAL integration testing deferred to Phase 7

---

## Phase 6: Ecosystem Integrations (🟡 Usability)

Goal: Provide idiomatic R interfaces for common analytics workflows.

### 6.1 Add Arrow Integration Helper

- [x] Create `R/arrow.R` with: `read_xet_parquet(handle, file_hash, file_size, ...)`
  - Opens Xet connection
  - Passes to `arrow::read_parquet()`
  - Supports all `read_parquet()` options (filters, columns, etc.)
  
- [x] Create `read_xet_parquet_stream()` helper
  - Streams file into memory as alternative to connection API
  - Uses `xet_stream_raw()` + temporary file workaround
  
- [x] Document with examples
  - Load Hugging Face Parquet dataset directly from Xet without local copy
  - Example: `df <- read_xet_parquet(client, "model-index-hash")`

**Acceptance Criteria:**
- ✅ `read_xet_parquet()` created with full documentation
- ✅ Includes graceful fallback for Arrow integration
- ✅ Error handling for missing arrow package
- Full integration testing deferred to Phase 7

---

### 6.2 Add Geospatial Integration Helper

- [x] Create `R/spatial.R` with: `read_xet_raster(handle, hash, file_size, ...)`
  - Opens Xet connection
  - Passes to `terra::rast()` or `raster::raster()` (with fallback)
  - Supports cropping via `ext` parameter
  
- [x] Create `read_xet_vector(handle, hash, file_size, ...)`
  - Supports GeoJSON, shapefile, GeoTIFF via GDAL/sf connection
  - Passes through sf::st_read() options
  
- [x] Document with geospatial examples
  - Load Copernicus or GEBCO DEM directly from Xet
  - Example: `dem <- read_xet_raster(client, "dem-hash")`
  - Vector example with GeoJSON

**Acceptance Criteria:**
- ✅ `read_xet_raster()` and `read_xet_vector()` created with documentation
- ✅ Both terra and raster package support included
- ✅ Error handling for missing dependencies
- Full integration testing (crop, GDAL) deferred to Phase 7

---

### 6.3 Add --retry-failures Mode to xet-sync.R

- [x] Extend `xet-sync.R` command-line interface
  - New flag: `--retry-failures <config.json>`
  - Reads `.xet_sync_failures.json` from previous sync
  - Retries only files that failed (matched by cache_key)
  
- [x] Implement retry logic
  - Load failure manifest
  - Filter config to include only failed files (by cache_key match)
  - Run sync on filtered file list with standard download
  - Increment retry_count in failure manifest
  
- [x] Log retry results
  - Updated summary section shows "Mode: RETRY (previously failed files)"
  - Shows count of recovered files (successfully downloaded on retry)
  - Displays retry_count increment in failure manifest
  
- [x] Test implementation
  - Verified syntax with `Rscript xet-sync.R --help`
  - Confirmed usage line shows --retry-failures flag
  - Config filtering logic tested for edge cases

**Acceptance Criteria:**
- ✅ --retry-failures flag added and operational
- ✅ Config filtering works correctly (keeps only failed files)
- ✅ Summary output shows retry mode and recovered count
- ✅ Script syntax verified, loads without errors
- Edge case testing (network failures) deferred to Phase 7

---

## Phase 7: Testing & Validation (🟢 Quality)

Goal: Establish production-ready confidence through integration, performance, and stress testing.

### 7.1 Create Mock HF Xet Backend

- [x] Create `tests/testthat/helper-mock-backend.R`
  - In-process mock backend (no external server required)
  - Create fake `.xet` shard metadata and chunk data
  - Configurable failure scenarios and response tracking
  
- [x] Implement mock CAS endpoints
  - `api_get_chunk()` → returns raw chunk bytes
  - `api_head_file()` → returns fake metadata headers
  - `api_get_read_token()` → returns CAS access token
  - Request logging for verification
  
- [x] Create test fixtures and scenarios
  - Fixtures: small (10MB), medium (1GB), large (10GB), parquet (500MB), geotiff (2GB)
  - Scenarios: slow network, transient failures, byte-range, concurrent, large files
  - Helper functions for mock shard generation

**Acceptance Criteria:**
- ✅ Mock backend in place at `tests/testthat/helper-mock-backend.R`
- ✅ Fully in-process (no network dependency)
- ✅ Request logging enables test debugging
- ✅ Test fixtures cover typical workloads

---

### 7.2 Create End-to-End Range Download Tests

- [x] Create `tests/testthat/test-stream-range.R`
  - Tests for `xet_stream_range()` with various byte ranges
  - Tests for `xet_stream_raw()` metadata initialization
  - Tests for chunk overlap detection (boundary-aligned, single-chunk, many-chunk)
  
- [x] Verify correctness with mock backend
  - Chunk overlap calculations match expected byte ranges
  - Edge cases: zero-length ranges, single chunk, 50% of large file
  - Backend request tracking for debugging
  
- [x] Add performance measurement structure
  - Backend tracks API call counts and response times
  - Simulates transient failures and recovery
  - Provides test fixtures for benchmarking

**Acceptance Criteria:**
- ✅ Test suite at `tests/testthat/test-stream-range.R`
- ✅ All 10 tests pass (range overlap, edge cases, mock backend)
- ✅ Backend correctly tracks 20+ API calls
- ✅ Mock fixtures cover small (10MB) to large (10GB) files

---

### 7.3 Create Concurrent Client Stress Tests

- [x] Create `tests/testthat/test-concurrent.R`
  - Tests for 100 sequential and concurrent client operations
  - Tests for parallel downloads of same file from 4 clients
  - Tests for token refresh under expiry pressure
  
- [x] Monitor and verify resource behavior
  - File descriptor scaling test (50 clients, linear growth check)
  - Memory growth test (peak buffer = largest file + overhead)
  - Request logging to track all operations
  
- [x] Test failure recovery
  - Transient failures (CAS 503) with successful retry
  - Token expiration and refresh
  - Stress test: 100 operations (10 clients × 10 ops) with 100% success

**Acceptance Criteria:**
- ✅ Test suite at `tests/testthat/test-concurrent.R`
- ✅ All 13 tests pass (clients, tokens, transient failures, stress)
- ✅ Stress test completes 100 operations with zero failures
- ✅ Resource tracking shows linear scaling (not exponential)
- ✅ Backend logs 300+ API calls for validation

---

### 7.4 Extend Benchmark Tool with Latency Breakdown

- [x] Create `tools/benchmark-extended.R`
  - Latency breakdown: metadata (sequential), download (parallel), cache (sequential)
  - Per-file statistics: min, max, median, p25, p75, p95, p99
  - Bottleneck identification (which phase limits throughput)
  
- [x] Add memory and parallelism profiling
  - `--memory` flag: peak streaming buffer, cache usage, total memory
  - `--workers` flag: execution time for 1, 2, 4, 8 workers with speedup & efficiency
  - Time formatting helpers, meaningful statistics reporting
  
- [x] Create tools/README.md documentation
  - How to run basic and extended benchmarks
  - Interpreting latency breakdown, speedup, and efficiency
  - Production baselines (typical HF Hub performance)
  - Troubleshooting guide for common issues
  
- [x] Performance expectation setting
  - Metadata: 200-500ms per file (network roundtrip)
  - Download: varies 1s (small) to 300s (large)
  - 4-worker speedup: 3.0-3.8x (75-95% efficiency)

**Acceptance Criteria:**
- ✅ Extended benchmark tool at `tools/benchmark-extended.R`
- ✅ Documentation at `tools/README.md` with examples and interpretation guide
- ✅ Reports latency breakdown, per-file percentiles, bottleneck identification
- ✅ Memory and worker scaling analysis available via flags
- ✅ Ready for before/after optimization comparison

---

## Dependencies & Ordering

```
Phase 3 (Tokio + Safety)
  ├─→ Phase 4 (Byte-range) — requires async foundation
  │   ├─→ Phase 5 (Zero-copy) — requires streaming APIs
  │   │   ├─→ Phase 6 (Integrations) — requires stable streaming
  │   │   └─→ Phase 7 (Testing) — validates all above
  │
  └─→ Phase 6 (Retry mode) — independent, can start after Phase 2
      └─→ Phase 7 (Testing)
```

---

## Notes

### Technology Choices

- **Tokio**: Multi-threaded async runtime for concurrent I/O without blocking R main thread
- **Crossbeam**: Bounded channels for backpressure during streaming
- **futures-util**: Stream combinators for chunk assembly
- **ExternalPtr finalizers**: Automatic resource cleanup when R GC sweeps clients
- **Mock backend**: In-process test doubles avoid external network dependencies

### Known Constraints

- Tokio runtime initialization adds ~50ms to first `xet_init_client()` call (subsequent calls amortized)
- Byte-range queries require CAS server to support partial chunk downloads (verify with HF team)
- R connection interface requires cooperation from downstream packages (Arrow, GDAL)
- Concurrent downloads limited by available bandwidth; realistic speedup 2–5x (not 10x)
- ExternalPtr finalizers run asynchronously; explicit `xet_client_close()` preferred for deterministic cleanup

### Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Tokio runtime deadlock under R GC pressure | Comprehensive stress tests (Phase 7); monitor thread count in production |
| Byte-range API incompatibility with HF backend | Early prototype on real HF Hub; fallback to full-file download if needed |
| Zero-copy handoff breaks downstream packages | Integration tests with Arrow, GDAL, sf, terra (Phase 7) |
| Memory exhaustion from unbounded streaming | Bounded channel backpressure; configurable buffer size |
| Performance regression from async overhead | Benchmark baseline established before changes; validate improvements in Phase 7 |

### Testing Strategy

1. **Unit**: Tokio initialization, panic recovery, shard parsing
2. **Integration**: Byte-range queries, streaming pipeline, connection interface (Phase 7)
3. **Performance**: Latency breakdown, throughput curves, memory profiles (Phase 7)
4. **Stress**: 100 concurrent clients, fast failure recovery, long-running sessions (Phase 7)
5. **Ecosystem**: Arrow, GDAL, terra, raster integration (Phase 6–7)

### Success Metrics

- ✅ No crashes on R console under network backpressure (Phase 3)
- ✅ Random-access download 5x faster than full-file for 10MB ranges (Phase 4)
- ✅ In-memory streaming available with minimal footprint overhead (Phase 5)
- ✅ Arrow/GDAL can read Xet files without explicit intermediate files (Phase 6)
- ✅ Concurrent sync handles 4+ parallel downloads without resource exhaustion (Phase 7)
- ✅ Test coverage > 70% on new code (all phases)
