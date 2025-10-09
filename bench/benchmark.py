#!/usr/bin/env python3
"""
Comprehensive WebAssembly Runtime Benchmark Suite
Tests wx against wasmer and wasmtime across multiple workloads
"""

import subprocess
import time
import sys
import os
from pathlib import Path
from typing import Optional, Tuple, Dict, List

class BenchmarkRunner:
    def __init__(self, runs: int = 5):
        self.runs = runs
        self.results: Dict[str, Dict[str, Optional[float]]] = {}
        
    def check_runtime(self, runtime: str) -> bool:
        """Check if a runtime is available"""
        try:
            if runtime == "wx":
                wx_path = Path(__file__).parent.parent / "zig-out" / "bin" / "wx"
                return wx_path.exists()
            
            result = subprocess.run(
                [runtime, "--version"],
                capture_output=True,
                timeout=5
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def run_single(self, runtime: str, wasm_file: str) -> Tuple[Optional[float], Optional[str]]:
        """Run a single benchmark and return execution time in milliseconds"""
        times = []
        
        for _ in range(self.runs):
            try:
                start = time.time()
                
                if runtime == "wx":
                    wx_path = Path(__file__).parent.parent / "zig-out" / "bin" / "wx"
                    cmd = [str(wx_path), wasm_file]
                elif runtime == "wasmer":
                    cmd = ["wasmer", "run", wasm_file]
                elif runtime == "wasmtime":
                    cmd = ["wasmtime", wasm_file]
                else:
                    return None, f"Unknown runtime: {runtime}"
                
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    timeout=60
                )
                
                end = time.time()
                
                if result.returncode == 0:
                    times.append((end - start) * 1000)
                else:
                    error = result.stderr.decode('utf-8', errors='ignore')[:200]
                    return None, f"Exit code {result.returncode}: {error}"
                    
            except subprocess.TimeoutExpired:
                return None, "Timeout after 60s"
            except Exception as e:
                return None, f"Error: {str(e)[:200]}"
        
        if not times:
            return None, "No successful runs"
        
        # Return average time
        return sum(times) / len(times), None
    
    def format_time(self, ms: float) -> str:
        """Format milliseconds nicely"""
        if ms < 1:
            return f"{ms*1000:.2f}µs"
        elif ms < 1000:
            return f"{ms:.2f}ms"
        else:
            return f"{ms/1000:.2f}s"
    
    def run_benchmarks(self, benchmarks: List[str], runtimes: List[str]):
        """Run all benchmarks across all runtimes"""
        
        print("=" * 80)
        print("🚀 WebAssembly Runtime Benchmark Suite")
        print("=" * 80)
        print()
        
        # Check runtime availability
        available_runtimes = {}
        print("📋 Checking runtime availability...")
        for runtime in runtimes:
            is_available = self.check_runtime(runtime)
            available_runtimes[runtime] = is_available
            status = "✅" if is_available else "❌"
            print(f"  {status} {runtime}")
        print()
        
        if not available_runtimes.get('wx', False):
            print("❌ Error: wx runtime not found!")
            print("   Build it with: zig build -Doptimize=ReleaseFast")
            sys.exit(1)
        
        # Run benchmarks
        for benchmark in benchmarks:
            if not Path(benchmark).exists():
                print(f"⚠️  Skipping {benchmark} (not found)")
                continue
            
            print(f"📊 Benchmark: {Path(benchmark).name}")
            print("-" * 60)
            
            bench_results = {}
            
            for runtime in runtimes:
                if not available_runtimes[runtime]:
                    print(f"  ⏭️  {runtime:12s} - skipped (not available)")
                    continue
                
                exec_time, error = self.run_single(runtime, benchmark)
                
                if error:
                    print(f"  ❌ {runtime:12s} - {error[:50]}")
                    bench_results[runtime] = None
                else:
                    print(f"  ✅ {runtime:12s} - {self.format_time(exec_time)}")
                    bench_results[runtime] = exec_time
            
            # Store results
            self.results[benchmark] = bench_results
            
            # Show comparison
            if bench_results.get('wx'):
                print()
                wx_time = bench_results['wx']
                
                if bench_results.get('wasmer'):
                    ratio = bench_results['wasmer'] / wx_time
                    if ratio > 1:
                        print(f"    🏆 wx is {ratio:.2f}x FASTER than wasmer")
                    else:
                        print(f"    ⚠️  wx is {1/ratio:.2f}x slower than wasmer")
                
                if bench_results.get('wasmtime'):
                    ratio = bench_results['wasmtime'] / wx_time
                    if ratio > 1:
                        print(f"    🏆 wx is {ratio:.2f}x FASTER than wasmtime")
                    else:
                        print(f"    ⚠️  wx is {1/ratio:.2f}x slower than wasmtime")
            
            print()
        
        # Overall summary
        self.print_summary()
    
    def print_summary(self):
        """Print overall benchmark summary"""
        print()
        print("=" * 80)
        print("📈 OVERALL PERFORMANCE SUMMARY")
        print("=" * 80)
        print()
        
        wx_wins_wasmer = 0
        wx_wins_wasmtime = 0
        total_wasmer = 0
        total_wasmtime = 0
        
        wx_times = []
        wasmer_times = []
        wasmtime_times = []
        
        for benchmark, times in self.results.items():
            if times.get('wx'):
                wx_times.append(times['wx'])
                
                if times.get('wasmer'):
                    wasmer_times.append(times['wasmer'])
                    total_wasmer += 1
                    if times['wx'] < times['wasmer']:
                        wx_wins_wasmer += 1
                
                if times.get('wasmtime'):
                    wasmtime_times.append(times['wasmtime'])
                    total_wasmtime += 1
                    if times['wx'] < times['wasmtime']:
                        wx_wins_wasmtime += 1
        
        if total_wasmer > 0:
            print(f"🏆 wx wins vs Wasmer:   {wx_wins_wasmer}/{total_wasmer} benchmarks ({wx_wins_wasmer*100//total_wasmer}%)")
        
        if total_wasmtime > 0:
            print(f"🏆 wx wins vs Wasmtime: {wx_wins_wasmtime}/{total_wasmtime} benchmarks ({wx_wins_wasmtime*100//total_wasmtime}%)")
        
        print()
        
        # Average times
        if wx_times:
            wx_avg = sum(wx_times) / len(wx_times)
            print(f"📊 Average Execution Time:")
            print(f"  wx:       {self.format_time(wx_avg)}")
            
            if wasmer_times:
                wasmer_avg = sum(wasmer_times) / len(wasmer_times)
                ratio = wasmer_avg / wx_avg
                print(f"  wasmer:   {self.format_time(wasmer_avg)} ({ratio:.2f}x vs wx)")
            
            if wasmtime_times:
                wasmtime_avg = sum(wasmtime_times) / len(wasmtime_times)
                ratio = wasmtime_avg / wx_avg
                print(f"  wasmtime: {self.format_time(wasmtime_avg)} ({ratio:.2f}x vs wx)")
        
        print()
        
        # Final verdict
        total_wins = wx_wins_wasmer + wx_wins_wasmtime
        total_tests = total_wasmer + total_wasmtime
        
        if total_tests > 0:
            win_rate = (total_wins * 100) // total_tests
            
            if win_rate == 100:
                print("🎉 TOTAL VICTORY! wx dominates ALL benchmarks! 🏆")
            elif win_rate >= 80:
                print("🏆 EXCELLENT! wx wins the majority of benchmarks!")
            elif win_rate >= 50:
                print("⚡ COMPETITIVE! wx shows strong performance!")
            else:
                print("📊 RESULTS: wx is competitive but has room for improvement")
        
        print()

def main():
    # Find benchmark files
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent
    
    benchmark_files = []
    
    # Check bench/wasm directory
    bench_wasm_dir = script_dir / "wasm"
    if bench_wasm_dir.exists():
        benchmark_files.extend(sorted(bench_wasm_dir.glob("*.wasm")))
    
    # Check examples directory
    examples_dir = root_dir / "examples"
    if examples_dir.exists():
        for wasm in sorted(examples_dir.glob("*.wasm")):
            if wasm not in benchmark_files:
                benchmark_files.append(wasm)
    
    if not benchmark_files:
        print("❌ No benchmark WASM files found!")
        print("   Expected files in bench/wasm/ or examples/")
        sys.exit(1)
    
    # Convert to strings
    benchmarks = [str(f) for f in benchmark_files]
    
    # Run benchmarks
    runner = BenchmarkRunner(runs=5)
    runner.run_benchmarks(benchmarks, ['wx', 'wasmer', 'wasmtime'])

if __name__ == "__main__":
    main()
