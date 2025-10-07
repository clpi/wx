#!/usr/bin/env bash
# Compile all WAT files to WASM for benchmarking

set -euo pipefail

# Check if wat2wasm is available
if ! command -v wat2wasm >/dev/null 2>&1; then
    echo "❌ wat2wasm not found. Please install WABT toolkit."
    echo "   Ubuntu/Debian: sudo apt-get install wabt"
    echo "   macOS: brew install wabt"
    exit 1
fi

echo "📦 Compiling WAT files to WASM..."
echo

# Directory containing WAT files
WAT_DIR="$(cd "$(dirname "$0")/wasm" && pwd)"

# Find and compile all WAT files
compiled=0
failed=0

for wat_file in "$WAT_DIR"/*.wat; do
    if [ -f "$wat_file" ]; then
        wasm_file="${wat_file%.wat}.wasm"
        filename=$(basename "$wat_file")
        
        echo -n "  Compiling $filename... "
        
        if wat2wasm "$wat_file" -o "$wasm_file" 2>/dev/null; then
            echo "✅"
            ((compiled++))
        else
            echo "❌"
            ((failed++))
        fi
    fi
done

echo
echo "📊 Compilation Summary:"
echo "  ✅ Successful: $compiled"
if [ $failed -gt 0 ]; then
    echo "  ❌ Failed: $failed"
fi

if [ $failed -gt 0 ]; then
    exit 1
fi

echo
echo "🎉 All WAT files compiled successfully!"
