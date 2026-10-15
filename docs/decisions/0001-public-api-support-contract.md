---
id: "0001"
title: "Preserve the 13-Function Public API and Label Unverified Functions Experimental"
status: "Accepted"
date: 2026-10-15
authors:
  - "Andrew G. Brown"
supersedes: null
superseded_by: null
source_context: "EXECUTION_PLAN_2"
---

# 1. Preserve the 13-Function Public API and Label Unverified Functions Experimental

## Context and Problem Statement

By v0.1, `rxet` exported 13 functions through `NAMESPACE`, but the shipped
`README` and help pages claimed behavior the code did not substantiate
(zero-copy integration, push-down filtering, parallel downloads, byte-range
speedups, a phantom `xet_get_file_metadata()`). Only the client session
functions had been exercised; the download, upload, streaming, and
ecosystem-integration functions were exported but not verified against a live
Xet endpoint. The question was whether to remove the unverified functions or to
keep them and bound the claims.

## Decision Drivers

* Do not break or remove already-built functionality without evidence it is a stub.
* User-facing documentation must describe only what the code actually does.
* Users must be able to distinguish proven from provisional capabilities.

## Considered Options

1. Remove the unverified exports and keep only the client session functions.
2. Keep all 13 exports and relabel the unverified ones as experimental.
3. Keep all 13 exports and make no labeling change.

## Decision Outcome

Chosen option: **Keep all 13 exports and relabel the unverified ones as
experimental**, because removing public functions is a breaking change while
truthful labeling bounds the claim without removing capability.

* **Supported (proven):** `xet_client_new`, `xet_client_close`, `xet_config_environment`.
* **Experimental (pending live evidence):** `xet_download_file`, `xet_upload_file`,
  `xet_stream_raw`, `xet_stream_range`, `xet_open_connection`,
  `xet_close_connection`, `read_xet_parquet`, `read_xet_parquet_stream`,
  `read_xet_raster`, `read_xet_vector`.

Every user-facing surface (README "v0.1 status" section and each function's
help page) must carry this classification, and documentation must describe the
real behavior (whole-file buffering into memory or disk via a single blocking
Rust client), not aspirational performance.

### Consequences

* **Positive:** No breaking change; users see what is proven versus provisional;
  overclaimed feature statements are removed.
* **Negative:** The public surface still includes functions whose end-to-end
  behavior is unverified until a later phase supplies live evidence.

## Validation & Compliance

* `NAMESPACE` contains exactly the 13 exports; no export removed or renamed.
* README "v0.1 status" list matches the 13 exports mechanically.
* `R CMD check` passes; all 10 experimental help pages contain
  "Experimental pending live evidence".
