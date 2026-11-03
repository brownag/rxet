use extendr_api::prelude::*;
use xet::xet_session::{
    Sha256Policy, XetConfig, XetDownloadStreamGroup, XetFileInfo, XetSession, XetSessionBuilder,
};
use std::sync::{Arc, Mutex};
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

/// Readahead bounds for a lazy reader. Each miss costs one reconstruction
/// metadata round trip, so windows are sized to amortize it without reading
/// a large fraction of a small file.
const READ_WINDOW_MIN: u64 = 1024 * 1024;
const READ_WINDOW_MAX: u64 = 16 * 1024 * 1024;

/// Windows start on this boundary, so two nearby reads usually share one window.
const READ_ALIGN_BYTES: u64 = 64 * 1024;

/// Total bytes of fetched windows kept per connection.
const READ_CACHE_BYTES: usize = 64 * 1024 * 1024;

/// A file opened for on-demand range reads, backed by one download stream group
/// so every read shares the same connection pool and auth token.
struct XetReader {
    group: XetDownloadStreamGroup,
    info: XetFileInfo,
    file_size: u64,
    cache: Mutex<ReaderCache>,
}

/// Most recently fetched windows, newest first, plus the current readahead size.
struct ReaderCache {
    windows: std::collections::VecDeque<ReaderWindow>,
    bytes: usize,
    readahead: u64,
    base_readahead: u64,
}

struct ReaderWindow {
    start: u64,
    data: Vec<u8>,
}

impl ReaderCache {
    fn covering(&self, offset: u64, end: u64) -> Option<&ReaderWindow> {
        self.windows
            .iter()
            .find(|w| offset >= w.start && end <= w.start + w.data.len() as u64)
    }

    fn insert(&mut self, window: ReaderWindow) {
        self.bytes += window.data.len();
        self.windows.push_front(window);
        while self.bytes > READ_CACHE_BYTES {
            match self.windows.pop_back() {
                Some(dropped) => self.bytes -= dropped.data.len(),
                None => break,
            }
        }
    }
}

impl XetReader {
    /// Serves `[offset, offset + length)` from a cached window, or fetches a new
    /// window covering it. Returns exactly `length` bytes.
    fn read_at(&self, offset: u64, length: u64) -> extendr_api::Result<Vec<u8>> {
        if length == 0 {
            return Ok(Vec::new());
        }
        let end = offset
            .checked_add(length)
            .filter(|end| *end <= self.file_size)
            .ok_or_else(|| {
                Error::Other(format!(
                    "read of {length} bytes at offset {offset} runs past the end of a {} byte file",
                    self.file_size
                ))
            })?;

        let mut cache = self
            .cache
            .lock()
            .map_err(|e| Error::Other(format!("reader cache poisoned: {e}")))?;

        if let Some(window) = cache.covering(offset, end) {
            let begin = (offset - window.start) as usize;
            return Ok(window.data[begin..begin + length as usize].to_vec());
        }

        // Grow the readahead while reads keep moving forward inside the newest
        // window, so a sequential scan costs a handful of requests.
        let sequential = cache.windows.front().is_some_and(|w| {
            offset >= w.start && offset <= w.start + w.data.len() as u64
        });
        cache.readahead = if sequential {
            (cache.readahead * 2).min(READ_WINDOW_MAX)
        } else {
            cache.base_readahead
        };

        let start = offset - (offset % READ_ALIGN_BYTES);
        let fetch_end = end.max(offset + cache.readahead).min(self.file_size);
        let data = self.fetch(start, fetch_end)?;
        let begin = (offset - start) as usize;
        let out = data[begin..begin + length as usize].to_vec();
        cache.insert(ReaderWindow { start, data });
        Ok(out)
    }

    /// Downloads one contiguous range through a new stream on the shared group.
    fn fetch(&self, start: u64, end: u64) -> extendr_api::Result<Vec<u8>> {
        let expected = end - start;
        if std::env::var("RXET_DEBUG").map(|v| v == "1").unwrap_or(false) {
            rprintln!("xet reader fetch {}..{}", start, end);
        }
        let mut stream = self
            .group
            .download_stream_blocking(self.info.clone(), Some(start..end))
            .map_err(|e| Error::Other(format!("download stream error: {}", e)))?;
        stream.start();

        let mut buf = Vec::with_capacity(expected as usize);
        while let Some(chunk) = stream
            .blocking_next()
            .map_err(|e| Error::Other(format!("stream read error: {}", e)))?
        {
            buf.extend_from_slice(&chunk);
            if buf.len() as u64 > expected {
                return Err(Error::Other(format!(
                    "stream returned more than {expected} bytes for range {start}..{end}"
                )));
            }
        }
        if buf.len() as u64 != expected {
            return Err(Error::Other(format!(
                "stream returned {} bytes, expected {expected} for range {start}..{end}",
                buf.len()
            )));
        }
        Ok(buf)
    }
}

extern "C" {
    /// Builds the custom R connection declared in `src/connection.c`.
    #[allow(improper_ctypes)]
    fn rxet_connection_new(read_fun: extendr_api::SEXP, size: f64) -> extendr_api::SEXP;
}

/// Opens a reader for on-demand range reads and returns its handle.
#[extendr]
fn xet_open_reader(handle: &str, file_hash: &str, file_size: f64) -> extendr_api::Result<String> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let size = whole_bytes("file_size", file_size)?;
        let client = acquire_client(handle)?;

        let group = client
            .session
            .new_download_stream_group()
            .map_err(|e| Error::Other(format!("download stream group error: {}", e)))?
            .with_endpoint(&client.endpoint)
            .with_token_info(&client.token, u64::MAX)
            .build_blocking()
            .map_err(|e| Error::Other(format!("build download stream group error: {}", e)))?;

        let window_bytes = (size / 32).clamp(READ_WINDOW_MIN, READ_WINDOW_MAX);
        let reader = XetReader {
            group,
            info: XetFileInfo::new(file_hash.to_string(), size),
            file_size: size,
            cache: Mutex::new(ReaderCache {
                windows: std::collections::VecDeque::new(),
                bytes: 0,
                readahead: window_bytes,
                base_readahead: window_bytes,
            }),
        };

        let key = Uuid::new_v4().to_string();
        READERS.insert(key.clone(), reader).map_err(Error::Other)?;
        Ok(key)
    }))
}

/// Reads exactly `length` bytes at `offset` from an open reader.
#[extendr]
fn xet_reader_read(reader_handle: &str, offset: f64, length: f64) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let offset = whole_bytes("offset", offset)?;
        let length = whole_bytes("length", length)?;
        let reader = READERS
            .acquire(reader_handle)
            .map_err(Error::Other)?
            .ok_or_else(|| Error::Other("invalid or closed reader handle".to_string()))?;
        Ok(reader.read_at(offset, length)?.into_robj())
    }))
}

/// Closes a reader and releases its stream group.
#[extendr]
fn xet_close_reader(reader_handle: &str) -> extendr_api::Result<()> {
    let reader = READERS
        .remove(reader_handle)
        .map_err(Error::Other)?
        .ok_or_else(|| Error::Other("invalid or closed reader handle".to_string()))?;
    let _ = reader.group.finish_blocking();
    Ok(())
}

/// Wraps a range-reading closure in a seekable R connection.
/// `read_fun` is called as `read_fun(offset, length)` and must return a raw vector.
#[extendr]
fn xet_stream_connection(read_fun: Robj, file_size: f64) -> extendr_api::Result<Robj> {
    let size = whole_bytes("file_size", file_size)?;
    if !read_fun.is_function() {
        return Err(Error::Other("read_fun must be a function".to_string()));
    }
    let con = unsafe { rxet_connection_new(read_fun.get(), size as f64) };
    Ok(unsafe { Robj::from_sexp(con) })
}

/// Allocates an R raw vector with room for exactly `len` bytes.
/// Allocating first means an impossible request fails before any network call.
fn allocate_raw(len: u64) -> extendr_api::Result<Robj> {
    let len = usize::try_from(len).map_err(|_| {
        Error::Other(format!("{len} bytes does not fit in memory on this platform"))
    })?;
    Ok(<Robj as Rinternals>::alloc_vector(
        extendr_api::rtype_to_sxp(Rtype::Raw),
        len,
    ))
}

/// Fills a preallocated raw vector from a chunk source and requires exactly `len` bytes.
/// Chunks are copied straight into the R vector, so the file is held once in memory.
fn fill_raw<F>(out: &mut Robj, len: u64, file_hash: &str, mut next_chunk: F) -> extendr_api::Result<()>
where
    F: FnMut() -> extendr_api::Result<Option<Vec<u8>>>,
{
    let capacity = out.len();
    let mut filled = 0usize;
    while let Some(chunk) = next_chunk()? {
        let end = filled
            .checked_add(chunk.len())
            .filter(|end| *end <= capacity)
            .ok_or_else(|| {
                Error::Other(format!(
                    "stream returned more than {capacity} bytes for hash {file_hash}"
                ))
            })?;
        out.as_raw_slice_mut()
            .ok_or_else(|| Error::Other("could not write to the allocated raw vector".to_string()))?
            [filled..end]
            .copy_from_slice(&chunk);
        filled = end;
    }
    if filled as u64 != len {
        return Err(Error::Other(format!(
            "stream returned {filled} bytes, expected {len} for hash {file_hash}"
        )));
    }
    Ok(())
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
    static ref READERS: Registry<XetReader> = Registry::new();
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

/// Converts an R double to a whole u64, rejecting non-finite, negative, fractional or >= 2^64 values.
/// The error names only the field, never the value.
fn whole_bytes(field: &str, v: f64) -> extendr_api::Result<u64> {
    if v.is_finite() && v >= 0.0 && v.fract() == 0.0 && v < 18446744073709551616.0 {
        Ok(v as u64)
    } else {
        Err(Error::Other(format!(
            "{field} must be a finite non-negative whole number"
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
        let n = whole_bytes("timeout_sec", t)?;
        config = config
            .with_config("client.read_timeout", format!("{}s", n))
            .map_err(|_| Error::Other("could not apply timeout_sec".to_string()))?;
    }
    if let Some(c) = cache_bytes {
        let n = whole_bytes("cache_bytes", c)?;
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
        let size_bytes = whole_bytes("file_size", file_size)?;

        let client = acquire_client(handle)?;
        let mut out = allocate_raw(size_bytes)?;

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

        fill_raw(&mut out, size_bytes, file_hash, || {
            stream
                .blocking_next()
                .map(|chunk| chunk.map(|bytes| bytes.to_vec()))
                .map_err(|e| Error::Other(format!("stream read error: {}", e)))
        })?;

        Ok(out)
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
        let total = whole_bytes("file_size", total_size)?;
        let start = whole_bytes("start_offset", start_offset)?;
        let end = whole_bytes("end_offset", end_offset)?;
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

        let client = acquire_client(handle)?;
        let mut out = allocate_raw(size)?;

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

        fill_raw(&mut out, size, file_hash, || {
            stream
                .blocking_next()
                .map(|chunk| chunk.map(|bytes| bytes.to_vec()))
                .map_err(|e| Error::Other(format!("stream read error: {}", e)))
        })?;

        Ok(out)
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
        let size = whole_bytes("file_size", file_size)?;

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
    fn xet_open_reader;
    fn xet_reader_read;
    fn xet_close_reader;
    fn xet_stream_connection;
}
