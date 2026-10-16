use crate::registry::Registry;
use std::sync::{mpsc, Arc};
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
