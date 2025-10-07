#!/usr/bin/env python3
"""
WASI Feature Benchmark Suite
Comprehensive performance testing for WASI implementation in wx runtime vs Wasmer and Wasmtime
"""

import subprocess
import time
import sys
from pathlib import Path

def run_benchmark(runtime, wasm_file, runs=5):
    """Run a WASI benchmark multiple times and return the average time"""
    times = []
    
    for _ in range(runs):
        try:
            start_time = time.time()
            if runtime == "wx":
                result = subprocess.run(
                    ["./zig-out/bin/wx", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
            elif runtime == "wasmer":
                result = subprocess.run(
                    ["wasmer", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
            elif runtime == "wasmtime":
                result = subprocess.run(
                    ["wasmtime", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
            end_time = time.time()
            
            if result.returncode == 0:
                times.append((end_time - start_time) * 1000)  # Convert to milliseconds
            else:
                return None, f"Error: {result.stderr[:100]}"
                
        except subprocess.TimeoutExpired:
            return None, "Timeout"
        except FileNotFoundError:
            return None, f"Runtime '{runtime}' not found"
    
    return sum(times) / len(times), None

def format_comparison(wx_time, other_time, other_name):
    """Format performance comparison"""
    if wx_time < other_time:
        ratio = other_time / wx_time
        return f"🚀 {ratio:.2f}x FASTER than {other_name}"
    else:
        ratio = wx_time / other_time
        return f"⚠️  {ratio:.2f}x slower than {other_name}"

def compile_wat_files():
    """Compile all WAT files to WASM if wat2wasm is available"""
    wat_files = [
        "bench/wasm/wasi_fd_write.wat",
        "bench/wasm/wasi_args.wat",
        "bench/wasm/wasi_environ.wat",
        "bench/wasm/wasi_comprehensive.wat"
    ]
    
    # Check if wat2wasm is available
    try:
        subprocess.run(["wat2wasm", "--version"], capture_output=True, check=True)
        has_wat2wasm = True
    except (subprocess.CalledProcessError, FileNotFoundError):
        has_wat2wasm = False
        print("⚠️  wat2wasm not found. Please install WABT toolkit.")
        print("   Ubuntu/Debian: sudo apt-get install wabt")
        print("   macOS: brew install wabt")
        return False
    
    if has_wat2wasm:
        print("📦 Compiling WAT files to WASM...")
        for wat_file in wat_files:
            wasm_file = wat_file.replace(".wat", ".wasm")
            if Path(wat_file).exists():
                try:
                    subprocess.run(
                        ["wat2wasm", wat_file, "-o", wasm_file],
                        check=True,
                        capture_output=True
                    )
                    print(f"   ✅ {wat_file} -> {wasm_file}")
                except subprocess.CalledProcessError as e:
                    print(f"   ❌ Failed to compile {wat_file}: {e.stderr.decode()}")
                    return False
        print()
        return True
    
    return False

def main():
    print("🚀 WASI Feature Benchmark Suite")
    print("=" * 80)
    print()
    
    # Compile WAT files first
    if not compile_wat_files():
        print("❌ Failed to compile WAT files. Exiting.")
        return 1
    
    # WASI-specific benchmarks
    benchmarks = [
        ("bench/wasm/wasi_fd_write.wasm", "fd_write (10K iterations)", "High-frequency output operations"),
        ("bench/wasm/wasi_args.wasm", "args_get/sizes (5K iterations)", "Argument retrieval operations"),
        ("bench/wasm/wasi_environ.wasm", "environ_get/sizes (8K iterations)", "Environment variable operations"),
        ("bench/wasm/wasi_comprehensive.wasm", "Comprehensive WASI (7K ops)", "All WASI features combined"),
    ]
    
    results = {}
    
    for wasm_file, label, description in benchmarks:
        if not Path(wasm_file).exists():
            print(f"⚠️  Skipping {wasm_file} (file not found)")
            continue
            
        print(f"📁 Testing: {label}")
        print(f"   Description: {description}")
        print(f"   File: {wasm_file}")
        print("-" * 80)
        
        # Test wx runtime
        wx_time, wx_error = run_benchmark("wx", wasm_file)
        if wx_error:
            print(f"  ❌ wx runtime: {wx_error}")
            continue
        else:
            print(f"  ✅ wx runtime: {wx_time:.2f}ms")
        
        # Test wasmer
        wasmer_time, wasmer_error = run_benchmark("wasmer", wasm_file)
        if wasmer_error:
            print(f"  ❌ wasmer: {wasmer_error}")
            wasmer_time = None
        else:
            print(f"  ✅ wasmer: {wasmer_time:.2f}ms")
        
        # Test wasmtime
        wasmtime_time, wasmtime_error = run_benchmark("wasmtime", wasm_file)
        if wasmtime_error:
            print(f"  ❌ wasmtime: {wasmtime_error}")
            wasmtime_time = None
        else:
            print(f"  ✅ wasmtime: {wasmtime_time:.2f}ms")
        
        # Store results
        results[label] = {
            'wx': wx_time,
            'wasmer': wasmer_time,
            'wasmtime': wasmtime_time,
            'description': description
        }
        
        # Show comparisons
        print(f"\\n  📊 Performance comparison:")
        if wasmer_time:
            comparison = format_comparison(wx_time, wasmer_time, "wasmer")
            print(f"    {comparison}")
        if wasmtime_time:
            comparison = format_comparison(wx_time, wasmtime_time, "wasmtime")
            print(f"    {comparison}")
        print()
    
    # Overall summary
    print("=" * 80)
    print("📈 WASI PERFORMANCE SUMMARY")
    print("=" * 80)
    print()
    
    wx_wins_wasmer = 0
    wx_wins_wasmtime = 0
    total_wasmer = 0
    total_wasmtime = 0
    
    for label, times in results.items():
        if times['wx'] and times['wasmer'] and times['wx'] < times['wasmer']:
            wx_wins_wasmer += 1
        if times['wx'] and times['wasmtime'] and times['wx'] < times['wasmtime']:
            wx_wins_wasmtime += 1
        if times['wasmer']:
            total_wasmer += 1
        if times['wasmtime']:
            total_wasmtime += 1
    
    print(f"🏆 wx wins against Wasmer: {wx_wins_wasmer}/{total_wasmer} benchmarks")
    print(f"🏆 wx wins against Wasmtime: {wx_wins_wasmtime}/{total_wasmtime} benchmarks")
    print()
    
    # Calculate average performance
    if results:
        wx_avg = sum(t['wx'] for t in results.values() if t['wx']) / len([t for t in results.values() if t['wx']])
        wasmer_times = [t['wasmer'] for t in results.values() if t['wasmer']]
        wasmtime_times = [t['wasmtime'] for t in results.values() if t['wasmtime']]
        
        print(f"📊 Average Performance:")
        print(f"  wx runtime: {wx_avg:.2f}ms")
        if wasmer_times:
            wasmer_avg = sum(wasmer_times) / len(wasmer_times)
            print(f"  wasmer: {wasmer_avg:.2f}ms ({wasmer_avg/wx_avg:.2f}x vs wx)")
        if wasmtime_times:
            wasmtime_avg = sum(wasmtime_times) / len(wasmtime_times)
            print(f"  wasmtime: {wasmtime_avg:.2f}ms ({wasmtime_avg/wx_avg:.2f}x vs wx)")
        print()
    
    # Performance breakdown by feature
    print("📋 Performance Breakdown by WASI Feature:")
    print()
    for label, times in results.items():
        print(f"  {label}:")
        print(f"    Description: {times['description']}")
        print(f"    wx:       {times['wx']:.2f}ms")
        if times['wasmer']:
            ratio = times['wasmer'] / times['wx']
            print(f"    wasmer:   {times['wasmer']:.2f}ms ({ratio:.2f}x vs wx)")
        if times['wasmtime']:
            ratio = times['wasmtime'] / times['wx']
            print(f"    wasmtime: {times['wasmtime']:.2f}ms ({ratio:.2f}x vs wx)")
        print()
    
    # Key optimizations
    print("🎯 WASI Implementation Optimizations:")
    print("  • Zero-copy I/O vector processing")
    print("  • Optimized memory bounds checking")
    print("  • Fast argument/environment variable caching")
    print("  • Streamlined file descriptor operations")
    print("  • Efficient string handling and memory layout")
    print()
    
    # Final verdict
    if wx_wins_wasmer == total_wasmer and wx_wins_wasmtime == total_wasmtime:
        print("🎉 TOTAL VICTORY: wx dominates ALL WASI benchmarks!")
    elif wx_wins_wasmer + wx_wins_wasmtime >= (total_wasmer + total_wasmtime) * 0.8:
        print("🏆 EXCELLENT: wx wins majority of WASI benchmarks!")
    else:
        print("⚡ COMPETITIVE: wx shows strong WASI performance!")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
