//! Reader window policy: serves byte ranges of one file from cached windows,
//! fetching new windows through a `RangeSource`. Plain Rust: no R types.

use std::collections::VecDeque;
use std::sync::Mutex;

/// Readahead bounds for a lazy reader. Each miss costs one reconstruction
/// metadata round trip, so windows are sized to amortize it without reading
/// a large fraction of a small file.
pub(crate) const READ_WINDOW_MIN: u64 = 1024 * 1024;
pub(crate) const READ_WINDOW_MAX: u64 = 16 * 1024 * 1024;

/// Windows start on this boundary, so two nearby reads usually share one window.
pub(crate) const READ_ALIGN_BYTES: u64 = 64 * 1024;

/// Total bytes of fetched windows kept per connection.
pub(crate) const READ_CACHE_BYTES: usize = 64 * 1024 * 1024;

/// Where windows come from. `fetch` returns the bytes of `[start, end)`.
pub(crate) trait RangeSource {
    fn fetch(&self, start: u64, end: u64) -> Result<Vec<u8>, String>;

    /// Releases the source's resources. Default: nothing to release.
    fn finish(&self) -> Result<(), String> {
        Ok(())
    }
}

impl<T: RangeSource + ?Sized> RangeSource for Box<T> {
    fn fetch(&self, start: u64, end: u64) -> Result<Vec<u8>, String> {
        (**self).fetch(start, end)
    }
    fn finish(&self) -> Result<(), String> {
        (**self).finish()
    }
}

/// A source over bytes already in memory.
pub(crate) struct BytesSource {
    pub(crate) bytes: Vec<u8>,
}

impl RangeSource for BytesSource {
    fn fetch(&self, start: u64, end: u64) -> Result<Vec<u8>, String> {
        self.bytes
            .get(start as usize..end as usize)
            .map(|s| s.to_vec())
            .ok_or_else(|| format!("range {start}..{end} past end of memory source"))
    }
}

/// A file served from cached windows, fetching misses through a `RangeSource`.
pub(crate) struct WindowedReader<S: RangeSource> {
    source: S,
    file_size: u64,
    cache: Mutex<WindowCache>,
}

/// Most recently fetched windows, newest first, plus the current readahead size.
struct WindowCache {
    windows: VecDeque<ReaderWindow>,
    bytes: usize,
    readahead: u64,
    base_readahead: u64,
}

struct ReaderWindow {
    start: u64,
    data: Vec<u8>,
}

impl WindowCache {
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

impl<S: RangeSource> WindowedReader<S> {
    /// Base readahead = (file_size / 32).clamp(READ_WINDOW_MIN, READ_WINDOW_MAX).
    /// The cache starts empty (no windows, 0 bytes) with readahead == base.
    pub(crate) fn new(source: S, file_size: u64) -> Self {
        let window_bytes = (file_size / 32).clamp(READ_WINDOW_MIN, READ_WINDOW_MAX);
        WindowedReader {
            source,
            file_size,
            cache: Mutex::new(WindowCache {
                windows: VecDeque::new(),
                bytes: 0,
                readahead: window_bytes,
                base_readahead: window_bytes,
            }),
        }
    }

    /// The file size this reader was built with.
    pub(crate) fn file_size(&self) -> u64 {
        self.file_size
    }

    /// The adapter, so lib.rs can release it on close (`finish_blocking`).
    #[allow(dead_code)]
    pub(crate) fn source(&self) -> &S {
        &self.source
    }

    /// Releases the source's resources while holding the cache lock, serializing
    /// shutdown with any concurrent or in-flight reads.
    pub(crate) fn finish(&self) -> Result<(), String> {
        let _cache = self
            .cache
            .lock()
            .map_err(|e| format!("reader cache poisoned: {e}"))?;
        self.source.finish()
    }

    /// Serves `[offset, offset + length)` from a cached window, or fetches a new
    /// window covering it. Returns exactly `length` bytes.
    ///
    /// The cache lock is held across the fetch, so concurrent reads on one
    /// reader are serialized.
    pub(crate) fn read_at(&self, offset: u64, length: u64) -> Result<Vec<u8>, String> {
        if length == 0 {
            return Ok(Vec::new());
        }
        let end = offset
            .checked_add(length)
            .filter(|end| *end <= self.file_size)
            .ok_or_else(|| {
                format!(
                    "read of {length} bytes at offset {offset} runs past the end of a {} byte file",
                    self.file_size
                )
            })?;

        let mut cache = self
            .cache
            .lock()
            .map_err(|e| format!("reader cache poisoned: {e}"))?;

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
        let data = self.source.fetch(start, fetch_end)?;
        let expected = fetch_end - start;
        if data.len() as u64 != expected {
            return Err(format!(
                "stream returned {} bytes, expected {expected} for range {start}..{fetch_end}",
                data.len()
            ));
        }
        let begin = (offset - start) as usize;
        let out = data[begin..begin + length as usize].to_vec();
        cache.insert(ReaderWindow { start, data });
        Ok(out)
    }
}
