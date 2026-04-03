
#  Nexus Node Helper Tool

> A helper toolkit for running high-performance [Nexus Network](https://nexus.xyz) nodes — with screen session management, memory-aware threading, and difficulty tuning.

---

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Screen Session Setup](#-screen-session-setup)
- [Full Launch Command](#-full-launch-command)
- [Difficulty Levels](#-difficulty-levels)
- [Thread & Memory Guide](#-thread--memory-guide)
- [How Memory Protection Works](#-how-memory-protection-works)
- [Scripts](#-scripts)
- [Connect](#-connect)

---

## ⚡ Quick Start

```bash
# 1. Update & install screen
sudo apt update
sudo apt install -y screen

# 2. Create a named screen session
screen -S nexus3

# 3. Launch your node (inside screen)
./target/release/nexus-network start \
  --node-id <YOUR_NODE_ID> \
  --max-threads <NUMBER> \
  --max-difficulty extra_large_5

# 4. Detach from screen (keep node running in background)
# Press: Ctrl + A, then D

# 5. Reattach later
screen -r nexus3
```

---

## 🖥️ Screen Session Setup

`screen` keeps your node running even after you disconnect from SSH.

| Command | Description |
|---------|-------------|
| `screen -S nexus3` | Create a new session named `nexus3` |
| `Ctrl + A, D` | Detach (leave node running in background) |
| `screen -r nexus3` | Reattach to your session |
| `screen -ls` | List all active sessions |
| `exit` | Kill the session entirely |

---

## 🚀 Full Launch Command

```bash
./target/release/nexus-network start \
  --node-id <YOUR_NODE_ID> \
  --max-threads <NUMBER> \
  --max-difficulty extra_large_5
```

### Parameter Reference

| Flag | Description | Example |
|------|-------------|---------|
| `--node-id` | Your unique Nexus node ID | `--node-id 123456` |
| `--max-threads` | Number of CPU threads to use | `--max-threads 8` |
| `--max-difficulty` | Maximum task difficulty tier | `--max-difficulty extra_large_5` |

---

## 🎯 Difficulty Levels

Tasks start at `small` difficulty and auto-promote if they complete in under **7 minutes**.

```bash
nexus-cli start --max-difficulty medium
nexus-cli start --max-difficulty large
nexus-cli start --max-difficulty extra_large
nexus-cli start --max-difficulty extra_large_2
nexus-cli start --max-difficulty extra_large_3
nexus-cli start --max-difficulty extra_large_4
nexus-cli start --max-difficulty extra_large_5
```

> **Note:** `extra_large_5` automatically falls back to `extra_large_4` if no matching tasks are available.

### Which difficulty should I use?

| Hardware | Recommended Difficulty |
|----------|----------------------|
| 2–4 cores, 4–8 GB RAM | `medium` or `large` |
| 4–8 cores, 8–16 GB RAM | `extra_large` – `extra_large_3` |
| 8+ cores, 16+ GB RAM | `extra_large_4` or `extra_large_5` |
| Dedicated proving machine | `extra_large_5` |

---

## 🧮 Thread & Memory Guide

Each thread uses approximately **1.5 GB of RAM**. Use this table to choose `--max-threads`:

| RAM | Safe Max Threads | Command Example |
|-----|-----------------|-----------------|
| 8 GB | 5 | `--max-threads 5` |
| 16 GB | 10 | `--max-threads 10` |
| 32 GB | 21 | `--max-threads 21` |
| 64 GB | 42 | `--max-threads 42` |
| 128 GB | 85 | `--max-threads 85` |

**Formula:**
```
Safe threads = floor(Total RAM in GB × 1024³ / 1,610,612,736)
```

---

## 🔬 How Memory Protection Works

The CLI has **two built-in layers** of memory protection in its Rust source:

### Layer 1 — Hard Cap (Silent)

```rust
const MEMORY_PER_THREAD: u64 = (1.5 * 1024.0 * 1024.0 * 1024.0) as u64;

fn clamp_threads_by_memory(requested_threads: usize) -> usize {
    let mut sys = System::new();
    sys.refresh_memory();
    let total_bytes = sys.total_memory() * 1024; // KB → bytes
    let max_threads_by_memory = (total_bytes / MEMORY_PER_THREAD) as usize;
    requested_threads.min(max_threads_by_memory.max(1))
}
```

If you request more threads than your RAM can support, the CLI **silently clamps** the count down. No crash, no error — just a safe ceiling.

### Layer 2 — OOM Warning (Visible)

```rust
pub fn warn_memory_configuration(max_threads: Option<u32>) {
    // ...
    if threads as u64 * MEMORY_PER_THREAD >= ram_total {
        // prints ⚠️ OOM warning and sleeps 3 seconds
    }
}
```

If projected memory usage meets or exceeds available process memory, the CLI prints a warning and **pauses for 3 seconds** so you can see it before execution continues.

### The Full Flow

```
You request N threads
        ↓
Hard cap:  min(N, floor(total RAM / 1.5 GB))   ← silent clamp
        ↓
Soft warn: if N × 1.5 GB ≥ process RAM         ← visible warning + 3s pause
        ↓
Workers spawn
```

---

## 📜 Scripts

See the [`/scripts`](./scripts) folder for:

- [`launch.sh`](./scripts/launch.sh) — one-command node launcher with screen
- [`check_ram.sh`](./scripts/check_ram.sh) — calculate your safe thread count

---

## 🔗 Connect

- 💬 **Discord:** `atkw3`
- 🐦 **Twitter / X:** [@Ladin90A](https://twitter.com/Ladin90A)
- 🐙 **GitHub:** [@oxatik](https://github.com/oxatik)

---

> Built for the Nexus Network community. Run hard, run smart. 🚀
