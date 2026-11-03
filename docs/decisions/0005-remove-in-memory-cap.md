# 0005. Remove the 2 GiB in-memory cap

- **Status:** Accepted
- **Date:** 2026-11-01
- **Supersedes:** the in-memory cap in EXECUTION_PLAN_4 decision D2
- **Superseded by:** none

## Context

D2 capped every read that returns bytes to R at 2^31 - 1 bytes (2 GiB), the
32-bit R vector limit. Rust enforced it in `MAX_IN_MEMORY_BYTES`; R enforced it
again in `.rxet_check_file_size(in_memory = TRUE)` and in the range validation.
The intent was a clean error instead of an out-of-memory crash.

Xet carries large files. A cap set at the 32-bit vector limit refuses exactly
the files the storage layer exists for, so it forced users of big Parquet,
GeoTIFF and vector files onto `xet_download_file()` and lost the helpers
entirely.

Two implementation facts made the cap the lesser problem:

- `xet_stream_raw()` built a full Rust `Vec<u8>` and then copied it into an R
  vector, so a request of size *n* needed 2*n* bytes. The cap did not bound
  memory use; it bounded the file size while the real cost was double.
- `read_xet_raster()` and `read_xet_vector()` read bytes back through
  `readBin()`, whose `n` argument is an integer. They could not exceed 2 GiB
  even with the checks removed.

## Decision

Remove the cap. Address memory directly instead:

1. `allocate_raw()` allocates one R `raw()` vector at full size before the
   download starts. A request that does not fit fails before any network call,
   which keeps the clean-error property without a numeric limit.
2. `fill_raw()` copies each chunk straight into that vector. Peak memory is one
   copy of the file plus one chunk, not two copies.
3. The file-backed readers (`read_xet_raster()`, `read_xet_vector()`) download
   with `xet_download_file()` to a temporary file. Their bytes never enter R
   memory and `readBin()` is no longer involved. `read_xet_parquet()` keeps the
   connection path, since Arrow parses from a connection.

## Consequences

- Files of any size work through the in-memory entry points, limited only by
  R's long-vector support and installed RAM.
- Peak memory for an in-memory read is now the file size, down from twice the
  file size.
- The raster and vector helpers need disk space equal to the file, and no
  longer hold the bytes in RAM.
- A request larger than RAM reports an allocation failure rather than a size
  limit. The message does not mention a cap because there is none.
- `read_xet_parquet()` still holds the file in memory while Arrow parses it, so
  it needs the file plus the parsed table. `xet_download_file()` remains the
  option when that does not fit.
