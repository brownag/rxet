use extendr_api::prelude::*;
use xet::xet_session::{XetSession, XetSessionBuilder, XetFileInfo, Sha256Policy, XetConfig};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use std::panic;
use uuid::Uuid;
use tokio::runtime::{Builder, Runtime};

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
            });
        }
    }
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
        // Load configuration from environment variables (HF_XET_* env vars)
        let config = XetConfig::new();

        let session = XetSessionBuilder::new_with_config(config)
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
    let mut clients = CLIENTS.lock()
        .map_err(|e| Error::Other(format!("client registry poisoned: {}", e)))?;

    clients
        .remove(handle)
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

        let size_bytes = file_size.round() as u64;
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

        let mut buf = Vec::with_capacity(size_bytes as usize);
        while let Some(chunk) = stream.blocking_next()
            .map_err(|e| Error::Other(format!("stream read error: {}", e)))? {
            buf.extend_from_slice(&chunk);
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

        let client = clients
            .get(handle)
            .ok_or_else(|| Error::Other(format!("invalid or closed client handle")))?;

        let start = start_offset.round() as u64;
        let end = end_offset.round() as u64;
        let size = end - start;

        // Use xet-core's download stream API with byte range
        let info = XetFileInfo::new(file_hash.to_string(), total_size.round() as u64);
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

        let mut buf = Vec::with_capacity(size as usize);
        while let Some(chunk) = stream.blocking_next()
            .map_err(|e| Error::Other(format!("stream read error: {}", e)))? {
            buf.extend_from_slice(&chunk);
        }

        Ok(buf.into_robj())
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

        let info = XetFileInfo::new(hash.to_string(), file_size.round() as u64);
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
    fn xet_stream_raw;
    fn xet_stream_range;
}
