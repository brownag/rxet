# 0007. Close releases the reader at once, and the Rust reader owns the file size

- **Status:** Accepted
- **Date:** 2026-11-07
- **Supersedes:** none
- **Superseded by:** none
- **Amends:** 0006 decision 4

## Context

ADR 0006 decision 4 bound the reader's lifetime to the connection only through
a finalizer. Closing the connection did not release the Rust reader; the next
garbage collection did. The R comment in `R/stream_connection.R` already said
that close released the reader, so code and comment disagreed.

File size was also held in two places. The Rust reader stored `file_size`, and
the R side passed the size again when it opened the connection. The read path
had two sources of truth for one value.

## Decision

1. **Early release (D1).** `close(conn)` releases the Rust reader immediately.
   The C close callback calls an R closure, `close_fun`, that runs
   `rxet_close_reader(id)`. The GC finalizer stays as a backstop for connections
   that are never closed.
2. **Size owner (D2).** The Rust reader owns the file size. R passes the size
   only to `rxet_open_reader`. The connection constructor takes the reader id
   and reads the size from Rust once.
3. **Memory-backed tests (D7, user choice).** The offline connection tests drive
   the connection through a memory-backed Rust reader, not through a plain R
   closure over local bytes. This changes the G2 exit criterion as originally
   written. GOALS.md G2 is reworded to match.
4. **C keeps a size copy (J1, accepted).** `src/connection.c` stores `size` for
   seek bounds, because `seek()` must answer synchronously in C. The Rust reader
   is the authoritative owner. C derives its copy from the reader once, at
   construction.
5. **Internal memory reader (J2, accepted).** `rxet_memory_reader_open` is
   compiled into the package for the offline tests. It is internal and is not
   part of the public API.
6. **Binding prefix.** Rust binding functions use an `rxet_` prefix. The
   generated `xet_*` names collided with the public R wrappers `xet_stream_raw`,
   `xet_stream_range`, `xet_download_file` and `xet_upload_file`. Commit 892ef3a
   made the rename. The names in this ADR are the current ones:
   `rxet_stream_connection(read_fun, close_fun, reader_handle)`,
   `rxet_reader_is_open`, and `rxet_memory_reader_open`.

## Consequences

- Closing a connection releases its reader at once. The GC finalizer covers
  connections that are never closed.
- The binding signature changes from `(read_fun, file_size)` to
  `(read_fun, close_fun, reader_handle)`.
- The pre-4.3 `#else` stub in `src/connection.c` used the same new signature.
  It was removed when the package floor became R 4.3.0 (ADR 0008).
- `rxet_memory_reader_open` is internal. It is not exported.
- The R-level behavior of `xet_open_stream_connection()` is unchanged.
- The Rust binding names changed in commit 892ef3a. Any code that called the
  old `xet_*` binding names must use the `rxet_*` names.
