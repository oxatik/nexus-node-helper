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

# Clamp to minimum of 1
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
