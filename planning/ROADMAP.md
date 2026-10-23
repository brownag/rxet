# Roadmap

Open work only. Shipped behaviour is recorded in [`NEWS.md`](../NEWS.md) and in
the decisions under [`docs/decisions/`](../docs/decisions/).

Current release: v0.3.0. The package exposes 10 functions, all whole-file or
byte-range reads through a single blocking client per handle.

## Reliability

- Add OS-level context to disk write failures (for example `ENOSPC`, `EACCES`)
  while keeping the destination path out of the message.
- Add HTTP status and retry hints to transfer errors where the `hf-xet` error
  type exposes them.
- Extend the fault server tests to cover a destination directory that becomes
  unwritable mid-transfer.

## Lifecycle stress

- Exercise many create/close cycles in one session and assert client file
  descriptor and thread counts return to baseline.
- Test close-during-transfer for upload as well as download.

## Continuous integration

- Validate the local-server suite on the first push and keep the three-OS
  matrix green.
- Keep the live suite manual; it must never run in public CI.

## Documentation

- Keep the support tiers in the README aligned with the exports when the API
  changes.
- Add an example to `NEWS.md` for any new user-facing argument.

## Not planned

- A custom Xet shard parser or metadata API. Chunk resolution belongs to
  `hf-xet`; `xet_stream_range()` asks for the byte range directly.
- An in-process mock CAS backend. The loopback fault server and the upstream
  `local_cas_server` cover the same ground without duplicating protocol code.
- An async or callback API. R has no event loop, so calls stay synchronous and
  block the calling thread.
