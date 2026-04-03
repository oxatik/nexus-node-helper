# 🧮 Memory Math — Deep Dive

How the Nexus CLI automatically protects your system from running out of RAM.

---

## The Core Constant

```rust
const MEMORY_PER_THREAD: u64 = (1.5 * 1024.0 * 1024.0 * 1024.0) as u64;
```

Each worker thread is budgeted **1.5 GB of RAM**. The conversion chain:

| Unit | Bytes |
|------|-------|
| 1 KB | 1,024 |
| 1 MB | 1,048,576 |
| 1 GB | 1,073,741,824 |
| **1.5 GB** | **1,610,612,736** |

---

## Layer 1 — Hard Cap

```rust
fn clamp_threads_by_memory(requested_threads: usize) -> usize {
    let total_bytes = sys.total_memory() * 1024; // sysinfo returns KB
    let max_threads_by_memory = (total_bytes / MEMORY_PER_THREAD) as usize;
    requested_threads.min(max_threads_by_memory.max(1))
}
```

**Formula:** `max threads = floor(total RAM / 1.5 GB)`

| RAM | Max Threads |
|-----|------------|
| 8 GB | 5 |
| 16 GB | 10 |
| 32 GB | 21 |
| 64 GB | 42 |

---

## Layer 2 — OOM Warning

```rust
if threads as u64 * MEMORY_PER_THREAD >= ram_total {
    // warn + sleep 3s
}
```

Fires when `N × 1.5 GB ≥ process RAM`. Uses **process memory** (not total system RAM), so it's more conservative than the hard cap.

---

## Flow Summary

```
Request N threads
    ↓
min(N, floor(total_RAM / 1.5GB))   ← silent hard cap
    ↓
if N × 1.5GB ≥ process_RAM         ← visible warning, 3s pause
    ↓
spawn workers
```
