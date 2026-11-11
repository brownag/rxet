# Tools

Developer scripts for syncing files, benchmarking, and maintenance. None of it ships in the installed package.

## Sync

`tools/sync/` downloads a list of Hub files into a local directory. It needs `jsonlite`, `httr2`, `future`, and `future.apply` on top of `rxet`, and reads `HF_TOKEN` from the environment.

```bash
cp tools/sync/models.example.json models.json   # then edit repos and files
tools/sync/xet-sync.sh models.json              # download or update every listed file
tools/sync/check-updates.sh models.json         # report upstream changes only
```

`xet-sync.R` also takes `--force` (download even when the hash matches), `--check-only` (report only), and `--retry-failures` (retry the last run's failures).

`models.json` stays local and is git-ignored. Edit the tracked template instead.

## Benchmarking

`benchmark.R` times one sync run (real timing):

```bash
Rscript tools/benchmark.R models.json
```

It prints total time, time per file, and counts of downloaded, skipped, and failed files. Use at least 10–50 files for a meaningful number.

`benchmark-extended.R` produces a synthetic estimate of phase latencies from simulated values, not a measurement of `models.json`:

```bash
Rscript tools/benchmark-extended.R models.json
Rscript tools/benchmark-extended.R models.json --memory
Rscript tools/benchmark-extended.R models.json --workers
```

It reports metadata fetch, download, and cache-write latency, each with mean, median, p95, and min–max. `--memory` adds peak buffer and cache estimates. `--workers` adds a 1-worker versus 4-worker comparison.

`benchmark.R` reads the config from `models.json` and syncs into the configured `sync_dir`, so the benchmark writes real files. Clear that directory between runs if you want to measure cold downloads.

### Reading the output

The slowest phase tells you what limits the run.

- Download dominates. Normal. More workers rarely help much, because the network is already saturated.
- Metadata dominates. Sequential round trips to the Hub are the cost. Small files and many repos make this worse.
- Cache writes dominate. The disk is the limit. Set `HF_XET_CHUNK_CACHE_SIZE_BYTES=0` to measure without the cache.

A p95 much larger than the median means file sizes vary widely. Compare per-file latency only within a similar size range.

Worker speedup is measured against one worker. Four workers rarely give 4x; overhead and I/O contention eat the rest.

### Configuring the run

Set these before the script to change what you measure:

```bash
export HF_XET_CLIENT_READ_TIMEOUT=600      # slow or high-latency networks
export HF_XET_CHUNK_CACHE_SIZE_BYTES=0     # no cache
export HF_XET_HIGH_PERFORMANCE=1           # hf-xet performance preset
```

## Related files

- `config.R`: generated `src/Makevars` support
- `msrv.R`: checks the Rust minimum version during configure
- `sync/xet-sync.R`: the sync script the benchmarks time
- `sync/models.example.json`: template for `models.json`
