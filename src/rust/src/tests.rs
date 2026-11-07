use crate::registry::Registry;
use crate::reader::{RangeSource, WindowedReader, READ_ALIGN_BYTES, READ_CACHE_BYTES, READ_WINDOW_MAX, READ_WINDOW_MIN};
use std::sync::{mpsc, Arc, Mutex};
use std::thread;
use std::time::Duration;

#[test]
fn acquire_returns_clone_and_releases_lock() {
    let reg: Arc<Registry<u32>> = Arc::new(Registry::new());
    reg.insert("k".to_string(), 7).unwrap();

    let held = reg.acquire("k").unwrap().expect("key should exist");
    assert_eq!(*held, 7);

    // Hold an Arc clone in another thread while removing the entry.
    // If the registry lock were still held by acquire, remove would block.
    let (done_tx, done_rx) = mpsc::channel();
    let reg2 = Arc::clone(&reg);
    let held2 = Arc::clone(&held);
    let worker = thread::spawn(move || {
        let removed = reg2.remove("k").unwrap();
        done_tx.send(removed.map(|a| *a)).unwrap();
        drop(held2);
    });

    let removed = done_rx
        .recv_timeout(Duration::from_secs(1))
        .expect("remove must not block on the registry lock");
    assert_eq!(removed, Some(7));
    worker.join().unwrap();
    assert_eq!(*held, 7);
}

#[test]
fn acquire_unknown_key_is_none() {
    let reg: Registry<u32> = Registry::new();
    assert!(reg.acquire("missing").unwrap().is_none());
}

#[test]
fn remove_twice_second_is_none() {
    let reg: Registry<u32> = Registry::new();
    reg.insert("k".to_string(), 1).unwrap();
    assert!(reg.remove("k").unwrap().is_some());
    assert!(reg.remove("k").unwrap().is_none());
}

#[test]
fn insert_then_remove_then_acquire_none() {
    let reg: Registry<u32> = Registry::new();
    reg.insert("k".to_string(), 1).unwrap();
    assert!(reg.remove("k").unwrap().is_some());
    assert!(reg.acquire("k").unwrap().is_none());
}

#[test]
fn size_mismatch_message_names_both_sizes() {
    let raw = "Internal error: File size mismatch: expected 65537 bytes but downloaded 65536 bytes";
    assert_eq!(
        crate::size_mismatch_message(65537, raw).as_deref(),
        Some("downloaded size does not match file_size: expected 65537 bytes, got 65536 bytes")
    );
}

#[test]
fn size_mismatch_message_ignores_other_errors() {
    assert!(crate::size_mismatch_message(10, "Internal error: something else").is_none());
}

#[test]
fn size_mismatch_message_unparseable_count_is_none() {
    assert!(crate::size_mismatch_message(10, "File size mismatch: expected 10 bytes but downloaded many bytes").is_none());
}

#[test]
fn size_mismatch_message_maps_debug_panic_form() {
    let raw = "task 245 panicked with message \"assertion `left == right` failed\n  left: 65537\n right: 65536\"";
    assert_eq!(
        crate::size_mismatch_message(65537, raw).as_deref(),
        Some("downloaded size does not match file_size: expected 65537 bytes, got 65536 bytes")
    );
}

#[test]
fn size_mismatch_message_debug_panic_swapped_operands() {
    let raw = "task 9 panicked with message \"assertion `left == right` failed\n  left: 65536\n right: 65537\"";
    assert_eq!(
        crate::size_mismatch_message(65537, raw).as_deref(),
        Some("downloaded size does not match file_size: expected 65537 bytes, got 65536 bytes")
    );
}

#[test]
fn size_mismatch_message_debug_panic_neither_operand_is_expected_is_none() {
    let raw = "task 9 panicked with message \"assertion `left == right` failed\n  left: 65536\n right: 0\"";
    assert!(crate::size_mismatch_message(65537, raw).is_none());
}

#[test]
fn size_mismatch_message_other_panic_is_none() {
    let raw = "task 9 panicked with message \"index out of bounds: the len is 3\"";
    assert!(crate::size_mismatch_message(65537, raw).is_none());
}

#[test]
fn build_config_none_leaves_defaults() {
    let base = xet::xet_session::XetConfig::new();
    let cfg = crate::build_config(None, None, false).unwrap();
    assert_eq!(cfg.chunk_cache.size_bytes, base.chunk_cache.size_bytes);
    assert_eq!(cfg.client.read_timeout, base.client.read_timeout);
}

#[test]
fn build_config_zero_cache_sets_zero() {
    let cfg = crate::build_config(None, Some(0.0), false).unwrap();
    assert_eq!(cfg.chunk_cache.size_bytes, 0);
}

#[test]
fn build_config_timeout_sets_read_timeout() {
    let cfg = crate::build_config(Some(45.0), None, false).unwrap();
    assert_eq!(cfg.client.read_timeout, Duration::from_secs(45));
}

#[test]
fn build_config_high_perf_changes_concurrency() {
    let base = xet::xet_session::XetConfig::new();
    let cfg = crate::build_config(None, None, true).unwrap();
    assert_eq!(cfg.data.max_concurrent_file_ingestion, 100);
    assert_ne!(
        cfg.data.max_concurrent_file_ingestion,
        base.data.max_concurrent_file_ingestion
    );
    assert_eq!(cfg.client.ac_max_download_concurrency, 124);
    assert_eq!(cfg.chunk_cache.size_bytes, base.chunk_cache.size_bytes);
}

#[test]
fn build_config_rejects_bad_numbers() {
    assert!(crate::build_config(Some(-1.0), None, false).is_err());
    assert!(crate::build_config(None, Some(1.5), false).is_err());
    assert!(crate::build_config(None, Some(f64::NAN), false).is_err());
    assert!(crate::build_config(Some(18446744073709551616.0), None, false).is_err());
}

#[test]
fn whole_bytes_accepts_whole_numbers() {
    assert_eq!(crate::whole_bytes("f", 0.0).unwrap(), 0);
    assert_eq!(crate::whole_bytes("f", 42.0).unwrap(), 42);
}

#[test]
fn whole_bytes_rejects_bad_values_with_field_message() {
    for v in [-1.0, 1.5, f64::NAN, f64::INFINITY, f64::NEG_INFINITY, 18446744073709551616.0] {
        let e = crate::whole_bytes("file_size", v).unwrap_err().to_string();
        assert!(e.contains("file_size must be a finite non-negative whole number"), "{e}");
    }
}

const MIB: u64 = 1024 * 1024;

/// What `MemorySource::fetch` returns relative to the requested range.
enum Mode {
    Exact,
    Short,
    Long,
    Fail(String),
}

/// In-memory `RangeSource` that generates bytes on demand and logs each fetch.
struct MemorySource {
    size: u64,
    log: Mutex<Vec<(u64, u64)>>,
    mode: Mode,
}

/// Content of the test file at byte offset `i`.
fn byte(i: u64) -> u8 {
    (i % 251) as u8
}

impl RangeSource for MemorySource {
    fn fetch(&self, start: u64, end: u64) -> Result<Vec<u8>, String> {
        assert!(end <= self.size, "fetch past end of source");
        self.log.lock().unwrap().push((start, end));
        match &self.mode {
            Mode::Fail(msg) => Err(msg.clone()),
            Mode::Exact => Ok((start..end).map(byte).collect()),
            Mode::Short => {
                let mut data: Vec<u8> = (start..end).map(byte).collect();
                data.pop();
                Ok(data)
            }
            Mode::Long => {
                let mut data: Vec<u8> = (start..end).map(byte).collect();
                data.push(byte(end));
                Ok(data)
            }
        }
    }
}

#[test]
fn reader_first_read_fetches_base_window() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    let out = reader.read_at(0, 10).unwrap();
    assert_eq!(out, (0..10).map(byte).collect::<Vec<u8>>());
    assert_eq!(*reader.source().log.lock().unwrap(), vec![(0, size / 32)]);
}

#[test]
fn reader_second_read_in_window_is_hit() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    reader.read_at(0, 10).unwrap();
    let out = reader.read_at(100, 10).unwrap();
    assert_eq!(out, (100..110).map(byte).collect::<Vec<u8>>());
    assert_eq!(reader.source().log.lock().unwrap().len(), 1);
}

#[test]
fn reader_sequential_reads_double_readahead() {
    let size = 256 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    assert_eq!(size / 32, 8 * MIB);
    reader.read_at(0, 10).unwrap();
    reader.read_at(8 * MIB, 10).unwrap();
    reader.read_at(24 * MIB, 10).unwrap();
    assert_eq!(
        *reader.source().log.lock().unwrap(),
        vec![(0, 8 * MIB), (8 * MIB, 24 * MIB), (24 * MIB, 40 * MIB)]
    );
}

#[test]
fn reader_backward_seek_resets_readahead() {
    let size = 256 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    reader.read_at(0, 10).unwrap();
    reader.read_at(8 * MIB, 10).unwrap();
    reader.read_at(24 * MIB, 10).unwrap();
    // Spans windows (0, 8M) and (8M, 24M): a miss, outside the newest window.
    let out = reader.read_at(7 * MIB, 2 * MIB).unwrap();
    assert_eq!(out, (7 * MIB..9 * MIB).map(byte).collect::<Vec<u8>>());
    // Sequential again after the reset; reaches past 24 MiB.
    let out = reader.read_at(15 * MIB, 10 * MIB).unwrap();
    assert_eq!(out, (15 * MIB..25 * MIB).map(byte).collect::<Vec<u8>>());
    assert_eq!(
        *reader.source().log.lock().unwrap(),
        vec![
            (0, 8 * MIB),
            (8 * MIB, 24 * MIB),
            (24 * MIB, 40 * MIB),
            (7 * MIB, 15 * MIB),
            (15 * MIB, 31 * MIB),
        ]
    );
}

#[test]
fn reader_aligns_window_start_to_64_kib() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    let out = reader.read_at(70_000, 10).unwrap();
    assert_eq!(out, (70_000..70_010).map(byte).collect::<Vec<u8>>());
    // Start aligns down to READ_ALIGN_BYTES; end is offset + base readahead.
    assert_eq!(70_000 % READ_ALIGN_BYTES, 4_464);
    assert_eq!(
        *reader.source().log.lock().unwrap(),
        vec![(65_536, 70_000 + size / 32)]
    );
}

#[test]
fn reader_clamps_base_window_to_file_size() {
    let size = 100_000;
    assert!(size / 32 < READ_WINDOW_MIN);
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    let out = reader.read_at(0, 10).unwrap();
    assert_eq!(out, (0..10).map(byte).collect::<Vec<u8>>());
    assert_eq!(*reader.source().log.lock().unwrap(), vec![(0, size)]);
}

#[test]
fn reader_large_read_fetches_exact_range() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    let out = reader.read_at(0, 20 * MIB).unwrap();
    assert_eq!(out.len() as u64, 20 * MIB);
    assert_eq!(out, (0..20 * MIB).map(byte).collect::<Vec<u8>>());
    assert_eq!(*reader.source().log.lock().unwrap(), vec![(0, 20 * MIB)]);
}

#[test]
fn reader_overrun_errors_without_fetch() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    let err = reader.read_at(size - 5, 10).unwrap_err();
    assert!(err.contains("runs past the end"), "unexpected error: {err}");
    assert!(reader.source().log.lock().unwrap().is_empty());
}

#[test]
fn reader_zero_length_is_empty_without_fetch() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    assert!(reader.read_at(0, 0).unwrap().is_empty());
    assert!(reader.source().log.lock().unwrap().is_empty());
}

#[test]
fn reader_eviction_drops_oldest_window() {
    let size = 1024 * MIB;
    let reader = WindowedReader::new(
        MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
        size,
    );
    assert_eq!(size / 32, 32 * MIB);
    assert_eq!(READ_WINDOW_MAX, 16 * MIB);
    // Four 16 MiB windows fit exactly; the fifth pushes past the cap.
    assert!(4 * READ_WINDOW_MAX as usize <= READ_CACHE_BYTES);
    assert!(5 * READ_WINDOW_MAX as usize > READ_CACHE_BYTES);
    for offset in [0, 100 * MIB, 200 * MIB, 300 * MIB, 400 * MIB] {
        reader.read_at(offset, 10).unwrap();
    }
    assert_eq!(reader.source().log.lock().unwrap().len(), 5);
    // Window at 0 was evicted, so re-reading it fetches again.
    let out = reader.read_at(0, 10).unwrap();
    assert_eq!(out, (0..10).map(byte).collect::<Vec<u8>>());
    assert_eq!(
        *reader.source().log.lock().unwrap(),
        vec![
            (0, 16 * MIB),
            (100 * MIB, 116 * MIB),
            (200 * MIB, 216 * MIB),
            (300 * MIB, 316 * MIB),
            (400 * MIB, 416 * MIB),
            (0, 16 * MIB),
        ]
    );
    // Window at 400 MiB is still cached, so no fetch.
    reader.read_at(400 * MIB, 10).unwrap();
    assert_eq!(reader.source().log.lock().unwrap().len(), 6);
}

#[test]
fn reader_wrong_length_fetch_errors() {
    let size = 100 * MIB;
    for mode in [Mode::Short, Mode::Long] {
        let reader = WindowedReader::new(
            MemorySource { size, log: Mutex::new(Vec::new()), mode },
            size,
        );
        let err = reader.read_at(0, 10).unwrap_err();
        assert!(err.contains("expected"), "unexpected error: {err}");
    }
}

#[test]
fn reader_source_error_is_propagated() {
    let size = 100 * MIB;
    let reader = WindowedReader::new(
        MemorySource {
            size,
            log: Mutex::new(Vec::new()),
            mode: Mode::Fail("boom".to_string()),
        },
        size,
    );
    assert_eq!(reader.read_at(0, 10).unwrap_err(), "boom");
}

#[test]
fn reader_reports_size_it_was_built_with() {
    for size in [12345u64, 0] {
        let reader = WindowedReader::new(
            MemorySource { size, log: Mutex::new(Vec::new()), mode: Mode::Exact },
            size,
        );
        assert_eq!(reader.file_size(), size);
    }
}

#[test]
fn reader_is_open_false_for_unknown_id() {
    assert!(!crate::xet_reader_is_open("no-such-id"));
}
