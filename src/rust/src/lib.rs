use extendr_api::prelude::*;
use xet::xet_session::{XetSession, XetSessionBuilder, XetFileInfo, Sha256Policy, XetConfig};
use std::sync::Arc;
use std::panic;
use uuid::Uuid;

mod registry;
#[cfg(test)]
mod tests;
use registry::Registry;

struct XetClient {
    session: XetSession,
    endpoint: String,
    token: String,
}

/// In-memory reads are capped at 2^31 - 1 bytes (decision D2).
const MAX_IN_MEMORY_BYTES: u64 = i32::MAX as u64;

/// Converts an R double to a byte count, rejecting anything that is not a finite whole number.
fn to_whole_bytes(value: f64, what: &str) -> extendr_api::Result<u64> {
    if !value.is_finite() || value < 0.0 || value.fract() != 0.0 || value >= 18446744073709551616.0 {
        return Err(Error::Other(format!(
            "{what} must be a finite whole number of bytes, got {value}"
        )));
    }
    Ok(value as u64)
}

/// Wraps a closure in panic::catch_unwind and converts panics to readable R errors.
fn safe_exec<F, T>(f: F) -> extendr_api::Result<T>
where
    F: FnOnce() -> extendr_api::Result<T> + panic::UnwindSafe,
{
    match panic::catch_unwind(f) {
        Ok(result) => result,
        Err(err) => {
            let msg = if let Some(s) = err.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = err.downcast_ref::<String>() {
                s.clone()
            } else {
                "Unknown Rust panic occurred during execution".to_string()
            };
            Err(Error::Other(format!("Rust Panic: {}", msg)))
        }
    }
}

lazy_static::lazy_static! {
    static ref CLIENTS: Registry<XetClient> = Registry::new();
}

/// Look up a client by handle and return an owned `Arc`.
/// The registry lock is released when this function returns, so blocking
/// network calls never hold the lock.
fn acquire_client(handle: &str) -> extendr_api::Result<Arc<XetClient>> {
    CLIENTS
        .acquire(handle)
        .map_err(Error::Other)?
        .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))
}

/// Convert an R-supplied number to a whole u64, or fail naming only the field.
fn whole_u64(field: &str, v: f64) -> extendr_api::Result<u64> {
    if v.is_finite() && v >= 0.0 && v.fract() == 0.0 && v <= u64::MAX as f64 {
        Ok(v as u64)
    } else {
        Err(Error::Other(format!(
            "{} must be a finite non-negative whole number",
            field
        )))
    }
}

/// Build the per-client configuration. Starts from the environment
/// (`XetConfig::new()`), applies the high-performance preset if requested,
/// then lets explicit arguments override the fields they set.
fn build_config(
    timeout_sec: Option<f64>,
    cache_bytes: Option<f64>,
    high_perf: bool,
) -> extendr_api::Result<XetConfig> {
    let mut config = XetConfig::new();
    if high_perf {
        config = config.with_high_performance();
    }
    if let Some(t) = timeout_sec {
        let n = whole_u64("timeout_sec", t)?;
        config = config
            .with_config("client.read_timeout", format!("{}s", n))
            .map_err(|_| Error::Other("could not apply timeout_sec".to_string()))?;
    }
    if let Some(c) = cache_bytes {
        let n = whole_u64("cache_bytes", c)?;
        config = config
            .with_config("chunk_cache.size_bytes", n)
            .map_err(|_| Error::Other("could not apply cache_bytes".to_string()))?;
    }
    Ok(config)
}

/// Initialize a Xet storage client with endpoint and authentication token.
/// Configuration starts from the HF_XET_* environment, then the optional
/// arguments are applied (high-performance preset first, explicit values last).
/// Returns a UUID string handle that identifies the client session.
#[extendr]
fn xet_init_client(
    endpoint: &str,
    token: &str,
    timeout_sec: Option<f64>,
    cache_bytes: Option<f64>,
    high_perf: bool,
) -> extendr_api::Result<String> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let config = build_config(timeout_sec, cache_bytes, high_perf)?;

        let session = XetSessionBuilder::new_with_config(config)
            .build()
            .map_err(|e| Error::Other(format!("XetSession build failed: {}", e)))?;

        let client = XetClient {
            session,
            endpoint: endpoint.to_string(),
            token: token.to_string(),
        };

        let handle = Uuid::new_v4().to_string();
        CLIENTS.insert(handle.clone(), client).map_err(Error::Other)?;

        // Print debug message only if RXET_DEBUG=1
        if std::env::var("RXET_DEBUG").map(|v| v == "1").unwrap_or(false) {
            rprintln!("XET Client initialized: {}", handle);
        }
        Ok(handle)
    }))
}

/// Close and free a Xet storage client
#[extendr]
fn xet_close_client(handle: &str) -> extendr_api::Result<()> {
    CLIENTS
        .remove(handle)
        .map_err(Error::Other)?
        .ok_or_else(|| Error::Other(format!("invalid or already-closed client handle")))?;
    Ok(())
}

/// Download an entire file from Xet storage into memory without disk writes
/// Uses xet-core's streaming API to fetch file in chunks and return as R raw vector.
#[extendr]
fn xet_stream_raw(
    handle: &str,
    file_hash: &str,
    file_size: f64,
) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let size_bytes = to_whole_bytes(file_size, "file_size")?;
        if size_bytes > MAX_IN_MEMORY_BYTES {
            return Err(Error::Other(format!(
                "in-memory read of {size_bytes} bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files"
            )));
        }

        let client = acquire_client(handle)?;

        let info = XetFileInfo::new(file_hash.to_string(), size_bytes);

        // Use download stream group to fetch entire file in chunks
        let group = client
            .session
            .new_download_stream_group()
            .map_err(|e| Error::Other(format!("download stream group error: {}", e)))?
            .with_endpoint(&client.endpoint)
            .with_token_info(&client.token, u64::MAX)
            .build_blocking()
            .map_err(|e| Error::Other(format!("build download stream group error: {}", e)))?;

        let mut stream = group
            .download_stream_blocking(info, None)  // None = full file, not a byte range
            .map_err(|e| Error::Other(format!("download stream error: {}", e)))?;

        stream.start();

        let mut buf = Vec::new();
        buf.try_reserve_exact(size_bytes as usize).map_err(|e| {
            Error::Other(format!("cannot allocate {size_bytes} bytes for in-memory read: {e}"))
        })?;
        while let Some(chunk) = stream.blocking_next()
            .map_err(|e| Error::Other(format!("stream read error: {}", e)))? {
            buf.extend_from_slice(&chunk);
        }

        if buf.len() as u64 != size_bytes {
            return Err(Error::Other(format!(
                "stream returned {} bytes, expected {} for hash {}",
                buf.len(), size_bytes, file_hash
            )));
        }

        Ok(buf.into_robj())
    }))
}

/// Stream a specific byte range of a file directly into memory as R data
/// Downloads only the chunks needed to reconstruct the requested byte range.
#[extendr]
fn xet_stream_range(
    handle: &str,
    file_hash: &str,
    total_size: f64,
    start_offset: f64,
    end_offset: f64,
) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        // Validate inputs
        let total = to_whole_bytes(total_size, "file_size")?;
        let start = to_whole_bytes(start_offset, "start_offset")?;
        let end = to_whole_bytes(end_offset, "end_offset")?;
        if start > total {
            return Err(Error::Other(format!(
                "invalid start offset: {} (file size: {})",
                start, total
            )));
        }
        if end < start || end > total {
            return Err(Error::Other(format!(
                "invalid end offset: {} (must be >= start {} and <= file size {})",
                end, start, total
            )));
        }
        let size = end.checked_sub(start).ok_or_else(|| {
            Error::Other(format!("invalid byte range: end {end} is before start {start}"))
        })?;
        if size > MAX_IN_MEMORY_BYTES {
            return Err(Error::Other(format!(
                "in-memory requested range of {size} bytes exceeds the 2 GiB limit (2147483647 bytes); use xet_download_file() for larger files"
            )));
        }

        let client = acquire_client(handle)?;

        // Use xet-core's download stream API with byte range
        let info = XetFileInfo::new(file_hash.to_string(), total);
        let range = start..end;

        let group = client
            .session
            .new_download_stream_group()
            .map_err(|e| Error::Other(format!("download stream group error: {}", e)))?
            .with_endpoint(&client.endpoint)
            .with_token_info(&client.token, u64::MAX)
            .build_blocking()
            .map_err(|e| Error::Other(format!("build download stream group error: {}", e)))?;

        let mut stream = group
            .download_stream_blocking(info, Some(range))
            .map_err(|e| Error::Other(format!("download stream error: {}", e)))?;

        stream.start();

        let mut buf = Vec::new();
        buf.try_reserve_exact(size as usize).map_err(|e| {
            Error::Other(format!("cannot allocate {size} bytes for in-memory read: {e}"))
        })?;
        while let Some(chunk) = stream.blocking_next()
            .map_err(|e| Error::Other(format!("stream read error: {}", e)))? {
            buf.extend_from_slice(&chunk);
        }

        if buf.len() as u64 != size {
            return Err(Error::Other(format!(
                "stream returned {} bytes, expected {} for hash {}",
                buf.len(), size, file_hash
            )));
        }

        Ok(buf.into_robj())
    }))
}

/// Parses the unsigned integer that follows `label` in `text`.
fn number_after(text: &str, label: &str) -> Option<u64> {
    text.split(label).nth(1)?.split(|c: char| !c.is_ascii_digit()).next()?.parse().ok()
}

/// Maps an hf-xet size-mismatch error to a plain message naming both sizes.
/// Returns None for any other error text, or when the downloaded count cannot be parsed.
fn size_mismatch_message(expected: u64, err_text: &str) -> Option<String> {
    let actual: u64 = if err_text.contains("File size mismatch") {
        err_text.split("downloaded ").nth(1)?.split_whitespace().next()?.parse().ok()?
    } else if err_text.contains("panicked with message")
        && err_text.contains("assertion `left == right` failed")
    {
        // Debug-build panic form (xet-data progress_types.rs:521). Only `expected` is trusted;
        // whichever operand equals it, the other is the downloaded count.
        let left = number_after(err_text, "left: ")?;
        let right = number_after(err_text, "right: ")?;
        if left == expected {
            right
        } else if right == expected {
            left
        } else {
            return None;
        }
    } else {
        return None;
    };
    Some(format!(
        "downloaded size does not match file_size: expected {expected} bytes, got {actual} bytes"
    ))
}

/// Download a file from Xet storage to a local path
#[extendr]
fn xet_download_file(
    handle: &str,
    hash: &str,
    file_size: f64,
    dest_path: &str,
) -> extendr_api::Result<()> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let size = to_whole_bytes(file_size, "file_size")?;

        let client = acquire_client(handle)?;

        let info = XetFileInfo::new(hash.to_string(), size);
        let dest = std::path::PathBuf::from(dest_path);

        let group = client
            .session
            .new_file_download_group()
            .map_err(|e| Error::Other(format!("download group error: {}", e)))?
            .with_endpoint(&client.endpoint)
            .with_token_info(&client.token, u64::MAX)
            .build_blocking()
            .map_err(|e| Error::Other(format!("build download group error: {}", e)))?;

        group
            .download_file_to_path_blocking(info, dest)
            .map_err(|e| {
                let text = e.to_string();
                match size_mismatch_message(size, &text) {
                    Some(msg) => Error::Other(msg),
                    None => Error::Other(format!("download error: {}", text)),
                }
            })?;

        group
            .finish_blocking()
            .map_err(|e| {
                let text = e.to_string();
                match size_mismatch_message(size, &text) {
                    Some(msg) => Error::Other(msg),
                    None => Error::Other(format!("finish error: {}", text)),
                }
            })?;

        Ok(())
    }))
}

/// Upload a local file to Xet storage
#[extendr]
fn xet_upload_file(handle: &str, src_path: &str) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let client = acquire_client(handle)?;

        let src = std::path::PathBuf::from(src_path);

        let commit = client
            .session
            .new_upload_commit()
            .map_err(|e| Error::Other(format!("upload commit error: {}", e)))?
            .with_endpoint(&client.endpoint)
            .with_token_info(&client.token, u64::MAX)
            .build_blocking()
            .map_err(|e| Error::Other(format!("build upload commit error: {}", e)))?;

        let _upload = commit
            .upload_from_path_blocking(src, Sha256Policy::Skip)
            .map_err(|e| Error::Other(format!("upload error: {}", e)))?;

        let report = commit
            .commit_blocking()
            .map_err(|e| Error::Other(format!("commit error: {}", e)))?;

        if report.uploads.len() != 1 {
            return Err(Error::Other(format!(
                "expected exactly one uploaded file, got {}",
                report.uploads.len()
            )));
        }

        let meta = report
            .uploads
            .values()
            .next()
            .ok_or_else(|| Error::Other("no upload metadata in report".to_string()))?;

        let result = list!(
            hash = meta.xet_info.hash.clone(),
            file_size = meta.xet_info.file_size.unwrap_or(0) as f64
        );
        Ok(result.into_robj())
    }))
}

extendr_module! {
    mod rxet;
    fn xet_init_client;
    fn xet_close_client;
    fn xet_download_file;
    fn xet_upload_file;
    fn xet_stream_raw;
    fn xet_stream_range;
}
