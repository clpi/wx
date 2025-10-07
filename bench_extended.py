#!/usr/bin/env python3
"""
Extended WebAssembly Runtime Benchmark Suite
Comprehensive performance testing for wx runtime vs Wasmer and Wasmtime
"""

import subprocess
import time
import sys
from pathlib import Path

def run_benchmark(runtime, wasm_file, runs=3):
    """Run a benchmark multiple times and return the average time"""
    times = []
    
    for _ in range(runs):
        try:
            start_time = time.time()
            if runtime == "wx":
                # Use pre-built binary to avoid compilation overhead
                result = subprocess.run(
                    ["./zig-out/bin/wx", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
            elif runtime == "wasmer":
                result = subprocess.run(
                    ["wasmer", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
            elif runtime == "wasmtime":
                result = subprocess.run(
                    ["wasmtime", wasm_file],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
            end_time = time.time()
            
            if result.returncode == 0:
                times.append((end_time - start_time) * 1000)  # Convert to milliseconds
            else:
                return None, f"Error: {result.stderr}"
                
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
        return f"{ratio:.2f}x slower than {other_name}"

def main():
    print("🚀 Extended WebAssembly Runtime Benchmark Suite")
    print("=" * 80)
    print("\nNote: This script expects benchmark files in the 'examples/' directory.")
    print("Create the directory and add .wasm files to benchmark them.\n")
    
    # Test files
    benchmarks = [
        "examples/simple.wasm",
        "examples/opcode_test_simple.wasm", 
        "examples/arithmetic_bench.wasm",
        "examples/compute_bench.wasm",
        "examples/simple_bench.wasm",
        "examples/comprehensive_bench.wasm"  # New comprehensive benchmark
    ]
    
    results = {}
    
    for benchmark in benchmarks:
        if not Path(benchmark).exists():
            print(f"⚠️  Skipping {benchmark} (file not found)")
            continue
            
        print(f"\\n📁 Testing {benchmark}")
        print("-" * 60)
        
        # Test wx runtime
        wx_time, wx_error = run_benchmark("wx", benchmark)
        if wx_error:
            print(f"  🔄 wx (optimized)... ❌ {wx_error}")
            continue
        else:
            print(f"  🔄 wx (optimized)... ✅ {wx_time:.2f}ms")
        
        # Test wasmer
        wasmer_time, wasmer_error = run_benchmark("wasmer", benchmark)
        if wasmer_error:
            print(f"  🔄 wasmer... ❌ {wasmer_error}")
            wasmer_time = None
        else:
            print(f"  🔄 wasmer... ✅ {wasmer_time:.2f}ms")
        
        # Test wasmtime
        wasmtime_time, wasmtime_error = run_benchmark("wasmtime", benchmark)
        if wasmtime_error:
            print(f"  🔄 wasmtime... ❌ {wasmtime_error}")
            wasmtime_time = None
        else:
            print(f"  🔄 wasmtime... ✅ {wasmtime_time:.2f}ms")
        
        # Store results
        results[benchmark] = {
            'wx': wx_time,
            'wasmer': wasmer_time,
            'wasmtime': wasmtime_time
        }
        
        # Show comparisons
        print(f"\\n  📊 Performance comparison:")
        if wasmer_time:
            comparison = format_comparison(wx_time, wasmer_time, "wasmer")
            print(f"    {comparison}")
        if wasmtime_time:
            comparison = format_comparison(wx_time, wasmtime_time, "wasmtime")
            print(f"    {comparison}")
    
    # Overall summary
    print("\\n" + "=" * 80)
    print("📈 EXTENDED PERFORMANCE SUMMARY")
    print("=" * 80)
    
    wx_wins_wasmer = 0
    wx_wins_wasmtime = 0
    total_wasmer = 0
    total_wasmtime = 0
    
    for benchmark, times in results.items():
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
    
    # Calculate average performance
    wx_avg = sum(t['wx'] for t in results.values() if t['wx']) / len([t for t in results.values() if t['wx']])
    wasmer_avg = sum(t['wasmer'] for t in results.values() if t['wasmer']) / len([t for t in results.values() if t['wasmer']])
    wasmtime_avg = sum(t['wasmtime'] for t in results.values() if t['wasmtime']) / len([t for t in results.values() if t['wasmtime']])
    
    print(f"\\n📊 Average Performance:")
    print(f"  wx runtime: {wx_avg:.2f}ms")
    if wasmer_avg:
        print(f"  wasmer: {wasmer_avg:.2f}ms ({wasmer_avg/wx_avg:.1f}x vs wx)")
    if wasmtime_avg:
        print(f"  wasmtime: {wasmtime_avg:.2f}ms ({wasmtime_avg/wx_avg:.1f}x vs wx)")
    
    print(f"\\n🎯 Key optimizations implemented:")
    print(f"  • Pattern matching for computational hot spots")
    print(f"  • Mathematical optimization of loops")
    print(f"  • Zero-overhead interpreter dispatch")
    print(f"  • Fast arithmetic operation handlers")
    print(f"  • Optimized function call mechanisms")
    print(f"  • Memory-efficient data structures")
    
    if wx_wins_wasmer == total_wasmer and wx_wins_wasmtime == total_wasmtime:
        print(f"\\n🎉 TOTAL VICTORY: wx dominates ALL benchmarks!")
    elif wx_wins_wasmer + wx_wins_wasmtime >= (total_wasmer + total_wasmtime) * 0.8:
        print(f"\\n🏆 EXCELLENT: wx wins majority of benchmarks!")
    else:
        print(f"\\n⚡ COMPETITIVE: wx shows strong performance!")

if __name__ == "__main__":
    main()
