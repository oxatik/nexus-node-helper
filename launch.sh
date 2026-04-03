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
