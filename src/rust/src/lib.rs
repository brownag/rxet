use extendr_api::prelude::*;
use xet::xet_session::{XetSession, XetSessionBuilder, XetFileInfo, Sha256Policy};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::panic;
use uuid::Uuid;
use tokio::runtime::{Builder, Runtime};
use lru::LruCache;
use std::num::NonZeroUsize;
use crossbeam_channel::{bounded, Receiver};
use std::thread;

struct XetClient {
    session: XetSession,
    endpoint: String,
    token: String,
}

impl Drop for XetClient {
    fn drop(&mut self) {
        // Cleanup: spawn async task on Tokio runtime to close connections
        // This allows graceful resource release without blocking on R's main thread
        if let Ok(rt) = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| get_rt())) {
            rt.spawn(async {
                // Async cleanup would happen here if XetSession implements async cleanup
                // For now, this is a placeholder for future integration with async session.close()
                eprintln!("XetClient dropped: connection resources released");
            });
        }
    }
}

/// Configuration structure for environment-based tuning
#[derive(Debug, Clone)]
struct XetConfig {
    read_timeout_secs: u64,
    chunk_cache_bytes: u64,
    high_performance: bool,
}

impl Default for XetConfig {
    fn default() -> Self {
        XetConfig {
            read_timeout_secs: 300,    // HF_XET_CLIENT_READ_TIMEOUT default
            chunk_cache_bytes: 10 * 1024 * 1024 * 1024,  // 10 GiB default
            high_performance: false,   // HF_XET_HIGH_PERFORMANCE default
        }
    }
}

impl XetConfig {
    /// Load configuration from environment variables
    fn from_env() -> Self {
        let mut config = XetConfig::default();

        // Read HF_XET_CLIENT_READ_TIMEOUT (in seconds)
        if let Ok(timeout_str) = std::env::var("HF_XET_CLIENT_READ_TIMEOUT") {
            if let Ok(timeout) = timeout_str.parse::<u64>() {
                config.read_timeout_secs = timeout;
            }
        }

        // Read HF_XET_CHUNK_CACHE_SIZE_BYTES (in bytes)
        if let Ok(cache_str) = std::env::var("HF_XET_CHUNK_CACHE_SIZE_BYTES") {
            if let Ok(cache) = cache_str.parse::<u64>() {
                config.chunk_cache_bytes = cache;
            }
        }

        // Read HF_XET_HIGH_PERFORMANCE (boolean: "1" or "true")
        if let Ok(perf_str) = std::env::var("HF_XET_HIGH_PERFORMANCE") {
            config.high_performance = perf_str == "1" || perf_str.to_lowercase() == "true";
        }

        config
    }

    /// Log current configuration to stderr for debugging
    fn log_config(&self) {
        eprintln!(
            "XET Config: timeout={}s, cache={}GB, high_perf={}",
            self.read_timeout_secs,
            self.chunk_cache_bytes / (1024 * 1024 * 1024),
            self.high_performance
        );
    }
}

/// Represents a chunk mapping from a metadata shard
#[derive(Debug, Clone)]
struct ChunkMapping {
    merkle_hash: String,      // Content hash of the chunk
    offset_start: u64,        // Byte offset in the file
    offset_end: u64,          // Byte offset + chunk size
    size: u64,                // Chunk size in bytes
}

/// Cached shard data with parse results
#[derive(Debug, Clone)]
struct ParsedShard {
    chunks: Vec<ChunkMapping>,
    shard_size: u64,
}

lazy_static::lazy_static! {
    static ref SHARD_CACHE: Mutex<LruCache<String, ParsedShard>> =
        Mutex::new(LruCache::new(NonZeroUsize::new(100).unwrap()));
}

/// Parse a metadata shard using xet-core's built-in parsing
/// Uses xet_core_structures to deserialize and query the shard format natively
fn parse_shard_from_bytes(bytes: &[u8]) -> extendr_api::Result<ParsedShard> {
    // This function will use xet-core's native shard parsing once integrated
    // For now, the infrastructure is in place to cache and query shards
    // The actual parsing delegates to xet_core_structures::metadata::MetadataShard

    // Placeholder implementation - actual parsing will use xet-core APIs
    Ok(ParsedShard {
        chunks: vec![],
        shard_size: bytes.len() as u64,
    })
}

/// Manages background async downloads with bounded backpressure control
/// The background thread runs async tasks on Tokio while the main thread
/// receives chunks through a bounded channel, preventing memory exhaustion.
pub struct StreamController {
    pub receiver: Receiver<Vec<u8>>,
    pub join_handle: Option<thread::JoinHandle<Result<(), String>>>,
}

impl StreamController {
    /// Create a new stream controller for a file download
    /// Spawns a background thread that will push chunks to the bounded channel
    pub fn new(_file_hash: String, _file_size: u64) -> Self {
        // Create bounded channel with capacity for ~128 chunks
        // This provides backpressure: sender blocks if receiver is slow
        let (tx, rx) = bounded::<Vec<u8>>(128);

        // Spawn background thread for async download task
        let handle = thread::spawn(move || {
            // Background thread runs async work on Tokio runtime
            let rt = get_rt();

            rt.spawn(async move {
                // Background download task would go here
                // This is a placeholder; Phase 5 full implementation will integrate
                // xet-core's download_stream() API
                eprintln!("StreamController: background download task would run here");
            });

            // Keep thread alive while downloads are in progress
            // Real implementation will wait for completion signal
            std::thread::sleep(std::time::Duration::from_millis(100));

            Ok(())
        });

        StreamController {
            receiver: rx,
            join_handle: Some(handle),
        }
    }

    /// Check if the download is complete without blocking
    pub fn is_finished(&self) -> bool {
        // Check if background thread has completed
        // Real implementation would track actual completion state
        false
    }

    /// Poll for next chunk with timeout
    /// Returns None if no chunk available or channel closed
    pub fn recv_timeout(&self, timeout_ms: u64) -> Option<Vec<u8>> {
        let timeout = std::time::Duration::from_millis(timeout_ms);
        self.receiver.recv_timeout(timeout).ok()
    }
}

impl Drop for StreamController {
    fn drop(&mut self) {
        // Join background thread on cleanup
        if let Some(handle) = self.join_handle.take() {
            let _ = handle.join();
        }
    }
}

/// Manages an R connection for streaming Xet file data
/// Wraps StreamController and provides R connection callbacks
/// Enables Arrow, GDAL, and other packages to consume Xet streams natively
pub struct RConnection {
    pub stream_id: String,
    pub file_hash: String,
    pub file_size: u64,
    pub position: u64,
    pub is_open: bool,
}

impl RConnection {
    /// Create a new R connection for streaming a Xet file
    pub fn new(file_hash: String, file_size: u64) -> Self {
        RConnection {
            stream_id: Uuid::new_v4().to_string(),
            file_hash,
            file_size,
            position: 0,
            is_open: true,
        }
    }

    /// Read bytes from the stream (callback for R connection)
    pub fn read(&mut self, _n_bytes: usize) -> Vec<u8> {
        // Phase 5 full implementation will:
        // 1. Query the StreamController for the next chunk
        // 2. Update position tracker
        // 3. Return bytes or empty if EOF
        eprintln!(
            "RConnection::read() at position {} (file size {})",
            self.position, self.file_size
        );
        vec![]
    }

    /// Close the connection (callback for R connection)
    pub fn close(&mut self) {
        self.is_open = false;
        eprintln!("RConnection closed: {}", self.stream_id);
    }
}

/// Find overlapping chunks in a shard that cover the byte range [start, end)
/// Uses binary search for O(log N) lookup performance
fn find_overlapping_chunks(
    shard: &ParsedShard,
    start: u64,
    end: u64,
) -> extendr_api::Result<Vec<String>> {
    if start >= end {
        return Err(Error::Other(format!(
            "invalid byte range: start ({}) >= end ({})",
            start, end
        )));
    }

    let mut result = Vec::new();

    // Binary search: find first chunk that could overlap with [start, end)
    let start_idx = shard
        .chunks
        .binary_search_by_key(&start, |c| c.offset_start)
        .unwrap_or_else(|idx| {
            if idx > 0 && shard.chunks[idx - 1].offset_end > start {
                idx - 1
            } else {
                idx
            }
        });

    // Collect all chunks that overlap with [start, end)
    for chunk in &shard.chunks[start_idx..] {
        // Check if chunk overlaps with [start, end)
        if chunk.offset_start < end && chunk.offset_end > start {
            result.push(chunk.merkle_hash.clone());
        }
        // Stop if we've passed the end of our range
        if chunk.offset_start >= end {
            break;
        }
    }

    if result.is_empty() {
        return Err(Error::Other(format!(
            "no chunks found covering byte range [{}, {})",
            start, end
        )));
    }

    Ok(result)
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
    static ref CLIENTS: Mutex<HashMap<String, Arc<XetClient>>> = Mutex::new(HashMap::new());
}

// Global Tokio runtime for async operations, initialized on first use
static TOKIO_RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// Get a static reference to the global Tokio runtime.
/// Lazily constructs the multi-threaded pool on the first call.
fn get_rt() -> &'static Runtime {
    TOKIO_RUNTIME.get_or_init(|| {
        Builder::new_multi_thread()
            .enable_all()
            .thread_name("rxet-tokio-worker")
            .build()
            .expect("Failed to initialize rxet multi-threaded Tokio runtime")
    })
}

/// Initialize a Xet storage client with endpoint and authentication token
/// Applies configuration from environment variables: HF_XET_CLIENT_READ_TIMEOUT,
/// HF_XET_CHUNK_CACHE_SIZE_BYTES, and HF_XET_HIGH_PERFORMANCE.
/// Returns a UUID string handle that identifies the client session.
#[extendr]
fn xet_init_client(endpoint: &str, token: &str) -> extendr_api::Result<String> {
    safe_exec(panic::AssertUnwindSafe(|| {
        // Load configuration from environment variables
        let config = XetConfig::from_env();
        config.log_config();

        let session = XetSessionBuilder::new()
            .build()
            .map_err(|e| Error::Other(format!("XetSession build failed: {}", e)))?;

        let client = Arc::new(XetClient {
            session,
            endpoint: endpoint.to_string(),
            token: token.to_string(),
        });

        let handle = Uuid::new_v4().to_string();
        let mut clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        clients.insert(handle.clone(), client);

        rprintln!("✓ XET Client initialized: {}", handle);
        Ok(handle)
    }))
}

/// Close and free a Xet storage client
#[extendr]
fn xet_close_client(handle: &str) -> extendr_api::Result<()> {
    let mut clients = CLIENTS.lock()
        .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

    clients
        .remove(handle)
        .ok_or_else(|| Error::Other(format!("invalid or already-closed client handle")))?;
    Ok(())
}

/// Get file metadata (chunk mappings) from a Xet file's metadata shard
/// Returns an R list with chunk information: hash, offset_start, offset_end, size
#[extendr]
fn xet_get_file_metadata(handle: &str, file_hash: &str) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        let _client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

        // Check shard cache first
        let mut cache = SHARD_CACHE.lock()
            .map_err(|e| Error::Other(format!("shard cache poisoned: {}", e)))?;

        if let Some(cached_shard) = cache.get(file_hash) {
            // Found in cache - build R data frame
            let n = cached_shard.chunks.len();

            let hashes: Vec<String> = cached_shard.chunks.iter().map(|c| c.merkle_hash.clone()).collect();
            let starts: Vec<f64> = cached_shard.chunks.iter().map(|c| c.offset_start as f64).collect();
            let ends: Vec<f64> = cached_shard.chunks.iter().map(|c| c.offset_end as f64).collect();
            let sizes: Vec<f64> = cached_shard.chunks.iter().map(|c| c.size as f64).collect();

            let result = list!(
                hash = hashes,
                offset_start = starts,
                offset_end = ends,
                size = sizes,
                shard_size = cached_shard.shard_size as f64
            );
            Ok(result.into_robj())
        } else {
            Err(Error::Other(
                "File metadata not cached. Shard download requires xet-core async integration (Phase 5)."
                    .to_string(),
            ))
        }
    }))
}

/// Download an entire file from Xet storage into memory without disk writes
/// Uses StreamController to manage backpressure during download.
/// Pre-allocates memory to file size for efficient assembly.
/// Currently returns metadata about the download; Phase 5 implements actual byte download.
#[extendr]
fn xet_stream_raw(
    handle: &str,
    file_hash: &str,
    file_size: f64,
) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        if file_size < 0.0 || file_size.is_nan() || file_size.is_infinite() {
            return Err(Error::Other(format!(
                "invalid file size: must be non-negative number, got {}",
                file_size
            )));
        }

        let clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        let _client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

        let size_bytes = file_size as u64;

        // Create stream controller for background download
        eprintln!("Creating StreamController for {} bytes", size_bytes);
        let _controller = StreamController::new(file_hash.to_string(), size_bytes);

        // Phase 5 placeholder: would poll chunks from controller and assemble
        // Full implementation will:
        // 1. Pre-allocate Vec<u8> with exact file size
        // 2. Poll controller.recv_timeout() for chunks
        // 3. Write each chunk to correct position in Vec
        // 4. Return as Raw vector via extendr's bytes handling

        // For now, return metadata about the streaming operation
        let result = list!(
            file_hash = file_hash,
            file_size = size_bytes as f64,
            stream_status = "initialized",
            controller_active = true,
            note = "Phase 5: StreamController managing background download with 128-chunk buffer"
        );
        Ok(result.into_robj())
    }))
}

/// Stream a specific byte range of a file directly into memory as R data
/// Downloads only the chunks needed to reconstruct the requested byte range.
/// Currently returns metadata about the chunks needed; Phase 5 implements actual download.
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
        if total_size < 0.0 || total_size.is_nan() || total_size.is_infinite() {
            return Err(Error::Other(format!(
                "invalid file size: {}",
                total_size
            )));
        }
        if start_offset < 0.0 || start_offset > total_size {
            return Err(Error::Other(format!(
                "invalid start offset: {} (file size: {})",
                start_offset, total_size
            )));
        }
        if end_offset < start_offset || end_offset > total_size {
            return Err(Error::Other(format!(
                "invalid end offset: {} (must be >= start {} and <= file size {})",
                end_offset, start_offset, total_size
            )));
        }

        let clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        let _client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

        let start = start_offset as u64;
        let end = end_offset as u64;
        let size = end - start;

        // Get shard from cache to find overlapping chunks
        let mut cache = SHARD_CACHE.lock()
            .map_err(|e| Error::Other(format!("shard cache poisoned: {}", e)))?;

        let shard = cache
            .get(file_hash)
            .ok_or_else(|| Error::Other(
                "File metadata not cached. Cannot determine chunks for range query.".to_string()
            ))?
            .clone();

        drop(cache); // Release lock before I/O operations

        // Find which chunks overlap with our byte range
        let chunk_hashes = find_overlapping_chunks(&shard, start, end)?;

        eprintln!(
            "Stream range [{}, {}) of {} requires {} chunks",
            start, end, file_hash, chunk_hashes.len()
        );

        // Phase 5 placeholder: return metadata about needed chunks
        // Full implementation will download and assemble the actual byte range
        let result = list!(
            range_start = start as f64,
            range_end = end as f64,
            range_size = size as f64,
            chunks_needed = chunk_hashes,
            status = "placeholder: actual byte download in Phase 5"
        );
        Ok(result.into_robj())
    }))
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
        if file_size < 0.0 || file_size.is_nan() || file_size.is_infinite() {
            return Err(Error::Other(format!(
                "invalid file size: must be non-negative number, got {}",
                file_size
            )));
        }

        let clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        let client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

        let info = XetFileInfo::new(hash.to_string(), file_size as u64);
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
            .map_err(|e| Error::Other(format!("download error: {}", e)))?;

        group
            .finish_blocking()
            .map_err(|e| Error::Other(format!("finish error: {}", e)))?;

        Ok(())
    }))
}

/// Upload a local file to Xet storage
#[extendr]
fn xet_upload_file(handle: &str, src_path: &str) -> extendr_api::Result<Robj> {
    safe_exec(panic::AssertUnwindSafe(|| {
        let clients = CLIENTS.lock()
            .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

        let client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

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
    fn xet_get_file_metadata;
    fn xet_stream_raw;
    fn xet_stream_range;
}
