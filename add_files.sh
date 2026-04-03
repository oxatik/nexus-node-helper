#!/bin/bash
# ============================================================
# Nexus Node Helper — Add all 5 files in one script
# Run from the root of your cloned repo:
#   bash add_files.sh
# ============================================================

set -e

echo "📁 Creating directory structure..."
mkdir -p scripts docs src

# ============================================================
# 1. scripts/launch.sh
# ============================================================
cat > scripts/launch.sh << 'EOF'
#!/bin/bash
# ============================================================
# 🚀 Nexus Node Launcher — with screen session management
# Usage: bash launch.sh <node_id> <threads> [difficulty]
# Example: bash launch.sh 123456 8 extra_large_5
# ============================================================

set -e

NODE_ID="${1}"
MAX_THREADS="${2:-8}"
MAX_DIFFICULTY="${3:-extra_large_5}"
SESSION_NAME="nexus3"
BINARY="./target/release/nexus-network"

# ── Validate input ───────────────────────────────────────────
if [[ -z "$NODE_ID" ]]; then
  echo "❌ Error: node_id is required."
  echo "   Usage: bash launch.sh <node_id> <threads> [difficulty]"
  exit 1
fi

if [[ ! -f "$BINARY" ]]; then
  echo "❌ Error: Binary not found at $BINARY"
  echo "   Make sure you've built the project with: cargo build --release"
  exit 1
fi

# ── RAM check ────────────────────────────────────────────────
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(echo "scale=1; $TOTAL_RAM_KB / 1024 / 1024" | bc)
SAFE_THREADS=$(echo "$TOTAL_RAM_KB * 1024 / 1610612736" | bc)

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Nexus Node Helper Tool         ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Node ID     : $NODE_ID"
echo "  Threads     : $MAX_THREADS  (safe max for your RAM: $SAFE_THREADS)"
echo "  Difficulty  : $MAX_DIFFICULTY"
echo "  Total RAM   : ${TOTAL_RAM_GB} GB"
echo ""

if (( MAX_THREADS > SAFE_THREADS )); then
  echo "⚠️  WARNING: Requested threads ($MAX_THREADS) exceed safe max ($SAFE_THREADS)."
  echo "   Each thread uses ~1.5 GB RAM. You may hit OOM."
  echo "   Continuing in 5 seconds... Press Ctrl+C to abort."
  sleep 5
fi

# ── Install screen if missing ────────────────────────────────
if ! command -v screen &>/dev/null; then
  echo "📦 Installing screen..."
  sudo apt update -qq && sudo apt install -y screen
fi

# ── Kill old session if exists ───────────────────────────────
screen -S "$SESSION_NAME" -X quit 2>/dev/null || true

# ── Launch in screen ─────────────────────────────────────────
echo "🚀 Launching node in screen session: $SESSION_NAME"
echo ""

screen -dmS "$SESSION_NAME" bash -c "
  $BINARY start \
    --node-id $NODE_ID \
    --max-threads $MAX_THREADS \
    --max-difficulty $MAX_DIFFICULTY
  echo '⛔ Node process exited. Press Enter to close.'
  read
"

sleep 1

if screen -list | grep -q "$SESSION_NAME"; then
  echo "✅ Node is running in background!"
  echo ""
  echo "   To view logs:    screen -r $SESSION_NAME"
  echo "   To detach again: Ctrl + A, then D"
  echo "   To stop node:    screen -S $SESSION_NAME -X quit"
else
  echo "❌ Failed to start screen session. Check your binary path."
  exit 1
fi
EOF

# ============================================================
# 2. scripts/check_ram.sh
# ============================================================
cat > scripts/check_ram.sh << 'EOF'
#!/bin/bash
# ============================================================
# 🧮 RAM → Safe Thread Calculator for Nexus Node
# Usage: bash check_ram.sh
# ============================================================

MEMORY_PER_THREAD_BYTES=1610612736  # 1.5 GB in bytes

TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
FREE_RAM_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

TOTAL_RAM_BYTES=$(( TOTAL_RAM_KB * 1024 ))
FREE_RAM_BYTES=$(( FREE_RAM_KB * 1024 ))

TOTAL_RAM_GB=$(echo "scale=2; $TOTAL_RAM_KB / 1024 / 1024" | bc)
FREE_RAM_GB=$(echo "scale=2; $FREE_RAM_KB / 1024 / 1024" | bc)

SAFE_THREADS_TOTAL=$(( TOTAL_RAM_BYTES / MEMORY_PER_THREAD_BYTES ))
SAFE_THREADS_FREE=$(( FREE_RAM_BYTES / MEMORY_PER_THREAD_BYTES ))

[[ $SAFE_THREADS_TOTAL -lt 1 ]] && SAFE_THREADS_TOTAL=1
[[ $SAFE_THREADS_FREE  -lt 1 ]] && SAFE_THREADS_FREE=1

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║      🧮 Nexus Node — RAM Thread Calculator   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Total RAM        : ${TOTAL_RAM_GB} GB"
echo "  Available RAM    : ${FREE_RAM_GB} GB"
echo "  RAM per thread   : 1.5 GB"
echo ""
echo "  ✅ Safe threads (total RAM)     : $SAFE_THREADS_TOTAL"
echo "  ✅ Safe threads (available RAM) : $SAFE_THREADS_FREE"
echo ""
echo "  💡 Recommended command:"
echo ""
echo "     ./target/release/nexus-network start \\"
echo "       --node-id <YOUR_NODE_ID> \\"
echo "       --max-threads $SAFE_THREADS_FREE \\"
echo "       --max-difficulty extra_large_5"
echo ""
EOF

# ============================================================
# 3. docs/memory-math.md
# ============================================================
cat > docs/memory-math.md << 'EOF'
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

Fires when `N × 1.5 GB ≥ process RAM`. Uses **process memory** (not total system RAM),
so it is more conservative than the hard cap.

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
EOF

# ============================================================
# 4. src/session.rs
# ============================================================
cat > src/session.rs << 'EOF'
//! Session setup and initialization
use crate::analytics::set_wallet_address_for_reporting;
use crate::config::Config;
use crate::environment::Environment;
use crate::events::Event;
use crate::orchestrator::OrchestratorClient;
use crate::runtime::start_authenticated_worker;
use ed25519_dalek::SigningKey;
use std::error::Error;
use sysinfo::{Pid, ProcessRefreshKind, ProcessesToUpdate, System};
use tokio::sync::{broadcast, mpsc};
use tokio::task::JoinHandle;

/// Session data for both TUI and headless modes
#[derive(Debug)]
pub struct SessionData {
    pub event_receiver: mpsc::Receiver<Event>,
    pub join_handles: Vec<JoinHandle<()>>,
    pub shutdown_sender: broadcast::Sender<()>,
    pub max_tasks_shutdown_sender: broadcast::Sender<()>,
    pub node_id: u64,
    pub orchestrator: OrchestratorClient,
    pub num_workers: usize,
}

// ----------------------------------------------------------------------
// 🧮 MEMORY AND THREAD CONTROL
// ----------------------------------------------------------------------

/// Each thread is expected to use ~1.5 GB of RAM
const MEMORY_PER_THREAD: u64 = (1.5 * 1024.0 * 1024.0 * 1024.0) as u64; // bytes

/// Clamp thread count based on available RAM
fn clamp_threads_by_memory(requested_threads: usize) -> usize {
    let mut sys = System::new();
    sys.refresh_memory();
    let total_bytes = sys.total_memory() * 1024; // KB → bytes
    let max_threads_by_memory = (total_bytes / MEMORY_PER_THREAD) as usize;

    requested_threads.min(max_threads_by_memory.max(1))
}

/// Warn if RAM is insufficient for the requested thread count
pub fn warn_memory_configuration(max_threads: Option<u32>) {
    if let Some(threads) = max_threads {
        let current_pid = Pid::from(std::process::id() as usize);

        let mut sysinfo = System::new();
        sysinfo.refresh_processes_specifics(
            ProcessesToUpdate::Some(&[current_pid]),
            true,
            ProcessRefreshKind::nothing().with_memory(),
        );

        if let Some(process) = sysinfo.process(current_pid) {
            let ram_total = process.memory() * 1024; // KB → bytes
            if threads as u64 * MEMORY_PER_THREAD >= ram_total {
                crate::print_cmd_warn!(
                    "⚠️ OOM warning",
                    "Projected memory usage across {} threads (~1.5GB each) may exceed available memory.",
                    threads
                );
                std::thread::sleep(std::time::Duration::from_secs(3));
            }
        }
    }
}

// ----------------------------------------------------------------------
// 🚀 SESSION SETUP
// ----------------------------------------------------------------------

pub async fn setup_session(
    config: Config,
    env: Environment,
    check_mem: bool,
    max_threads: Option<u32>,
    max_tasks: Option<u32>,
    max_difficulty: Option<crate::nexus_orchestrator::TaskDifficulty>,
) -> Result<SessionData, Box<dyn Error>> {
    let node_id = config.node_id.parse::<u64>()?;
    let client_id = config.user_id;

    // Signing key
    let mut csprng = rand_core::OsRng;
    let signing_key: SigningKey = SigningKey::generate(&mut csprng);

    // Orchestrator client
    let orchestrator_client = OrchestratorClient::new(env.clone());

    // Determine worker count based on max_threads or RAM
    let requested_threads = max_threads.unwrap_or(40) as usize;
    let mut num_workers = clamp_threads_by_memory(requested_threads);

    if check_mem {
        warn_memory_configuration(Some(num_workers as u32));
    }

    // Shutdown channels
    let (shutdown_sender, _) = broadcast::channel(1);
    // ... rest of session setup
    todo!("Complete session setup implementation")
}
EOF

# ============================================================
# 5. .gitignore
# ============================================================
cat > .gitignore << 'EOF'
# Rust build artifacts
target/
Cargo.lock

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo

# Logs
*.log
EOF

# ── Make shell scripts executable ────────────────────────────
chmod +x scripts/launch.sh
chmod +x scripts/check_ram.sh

echo ""
echo "╔══════════════════════════════════════════════╗"
