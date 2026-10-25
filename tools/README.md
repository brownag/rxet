# XET-Sync Tools

This directory contains utility scripts for benchmarking, configuration, and maintenance.

## Syncing models

The sync scripts live in `tools/sync/`. They are developer tooling and are not
part of the installed package. They need `jsonlite`, `httr2`, `future` and
`future.apply` in addition to `rxet`.

```bash
# Copy the example config, then edit repos and files
cp tools/sync/models.example.json models.json

# Download or update every listed file
tools/sync/xet-sync.sh models.json

# Only report upstream changes (append to model-updates.log)
tools/sync/check-updates.sh models.json
```

`xet-sync.R` also accepts `--force` (re-download even when the hash matches),
`--check-only` (report only) and `--retry-failures` (retry the previous run's
failures). Both shell wrappers read `HF_TOKEN` from the environment.

## Benchmarking

### Quick Benchmark

Run the basic benchmark to measure sync performance:

```bash
Rscript tools/benchmark.R models.json
```

Output includes total execution time, per-file average, and performance rating.

### Extended Benchmark with Latency Breakdown

For detailed performance analysis:

```bash
Rscript tools/benchmark-extended.R models.json
```

This provides:
- **Metadata fetch latency** (sequential network roundtrips)
- **Download latency** (parallel transfers)
- **Cache write latency** (filesystem I/O)
- **Per-file statistics** (min, max, median, p95, p99)
- **Bottleneck identification** (which phase limits throughput)

Example output:
```
=== Latency Breakdown ===

Metadata Fetch (Sequential):
  Mean:          234.5 ms
  Median:        215.0 ms
  P95:           450.2 ms
  Min-Max:       85.3 ms - 892.1 ms

Download (Parallel, 4 workers):
  Mean per file: 12.5 s
  Median:        10.2 s
  P95:           35.8 s
  Min-Max:       1.2 s - 245.3 s
  Total (4 workers): 42.5 min

Cache Write (Sequential):
  Mean:          89.2 ms
  Median:        75.4 ms
  P95:           180.5 ms
  Min-Max:       12.1 ms - 523.6 ms

=== Total Execution Time ===

Sequential (1 worker):
  Metadata: 3.9 min (3.2%)
  Download: 85.4 min (70.2%)
  Cache:    1.5 min (1.2%)
  TOTAL:    90.8 min

Parallel (4 workers):
  Metadata: 3.9 min (9.2%)
  Download: 21.4 min (50.8%)
  Cache:    1.5 min (3.6%)
  TOTAL:    26.8 min

Parallelism speedup: 3.4x
Efficiency: 85.0% (ideal = 400%)
```

### Memory Profiling

Include memory usage analysis:

```bash
Rscript tools/benchmark-extended.R models.json --memory
```

Reports:
- **Peak streaming buffer** (bounded channel, ~1.3 GB for 128 chunks × 10 MB)
- **Peak cache usage** (grows with cumulative downloads)
- **Total peak memory** (concurrent buffering + cache)

### Worker Scaling Comparison

Compare performance across different worker counts:

```bash
Rscript tools/benchmark-extended.R models.json --workers
```

Shows execution time for 1, 2, 4, and 8 workers with:
- Speedup factor relative to 1 worker
- Efficiency percentage (ideal is 100 × workers%)
- Recommendations for optimal configuration

### Full Analysis

Run all measurements:

```bash
Rscript tools/benchmark-extended.R models.json --memory --workers
```

## Interpreting Results

### Speedup and Efficiency

**Speedup** = Time for 1 worker / Time for N workers
- Linear speedup = N (unrealistic due to overhead)
- Expected with 4 workers: 3.0x to 3.8x (75-95% efficiency)
- Diminishing returns beyond 4 workers (I/O saturation, overhead)

Example:
- 1 worker: 100 minutes
- 4 workers: 28 minutes
- Speedup: 3.6x
- Efficiency: 90% ✓ (excellent)

### Bottleneck Identification

**If Download > Metadata + Cache:**
- Download parallelism is the limit
- Expected and normal; increasing workers won't help much
- Optimize: check network bandwidth, increase chunk size

**If Metadata >> Download + Cache:**
- Sequential metadata fetches are limiting
- Causes: high latency to HF Hub, small files, many repos
- Optimize: batch metadata requests, increase parallelism

**If Cache >> Download + Metadata:**
- Filesystem I/O is the limit
- Causes: slow disk, many small files, cache contention
- Optimize: disable cache (HF_XET_HIGH_PERFORMANCE=1), increase cache location to faster disk

### File Size Distribution

P95 latency >> Median indicates:
- Some files are much larger than the median
- Consider tiered handling: small files in batch, large files sequential
- Stream mode recommended for files > 100 MB

Example:
```
Download latencies:
  Median: 5.2 s
  P95:    45.3 s
```
Interpretation: 95% of files download in < 45s, but typical file is 5s.

## Configuration

### Environment Variables

Set before running benchmarks to measure performance under different configs:

```bash
# Increase timeout for high-latency networks
export HF_XET_CLIENT_READ_TIMEOUT=600

# Disable cache for pure throughput
export HF_XET_CHUNK_CACHE_SIZE_BYTES=0

# Enable high-performance mode
export HF_XET_HIGH_PERFORMANCE=1

Rscript tools/benchmark-extended.R models.json
```

### Test Data

For reproducible benchmarks, use the included test fixtures in the benchmark scripts:
- **Small**: 10 MB, 10 chunks
- **Medium**: 1 GB, 10 chunks
- **Large**: 10 GB, 100 chunks
- **Parquet**: 500 MB (typical ML dataset)
- **GeoTIFF**: 2 GB (typical spatial data)

## Production Baselines

Expected performance on HuggingFace Hub (cached tokens):

| File Count | File Type | 1 Worker | 4 Workers | Speedup |
|------------|-----------|----------|-----------|---------|
| 10 | Small (100 MB) | 2.5 min | 0.8 min | 3.1x |
| 10 | Medium (1 GB) | 25 min | 7.2 min | 3.5x |
| 100 | Mixed | 4.2 hrs | 1.2 hrs | 3.5x |

Assumes:
- 300 ms HF Hub latency
- 100 Mbps network throughput
- SSD cache
- Token reuse (no refresh overhead)

## Before/After Comparison

Measure before and after optimizations:

```bash
# Before optimization
Rscript tools/benchmark-extended.R models.json --workers > before.txt

# Apply optimization

# After optimization
Rscript tools/benchmark-extended.R models.json --workers > after.txt

# Compare
echo "Improvement:"
echo "(1-worker before - 1-worker after) / 1-worker before"
```

Example:
```
Before: 180 min (1 worker), 52 min (4 workers)
After:  120 min (1 worker), 38 min (4 workers)
Improvement: 33% faster (1 worker), 27% faster (4 workers)
```

## Troubleshooting

**Benchmark hangs or is very slow:**
- Check network connectivity to HF Hub
- Check token validity (may need refresh)
- Verify models.json is reachable and configured correctly

**High variance in results:**
- Network conditions vary; run multiple times and average
- Disable other background tasks
- Use `--memory` flag to monitor for resource contention

**Unexpected worker scaling:**
- 4-8 workers often show same or slightly worse performance (overhead > benefit)
- This is normal; 2-4 workers is typical sweet spot
- Check `endpoint_called("GET", "xet-read-token")` count; high = token refresh bottleneck

## Related Files

- `config.R` — Configuration helpers
- `msrv.R` — Minimum Supported R Version checker
- `sync/xet-sync.R` — Main sync script (measured by benchmarks)
- `sync/models.example.json` — Example sync config; copy to `models.json` in the repo root and edit
