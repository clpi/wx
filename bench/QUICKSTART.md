# Benchmark Quick Start Guide

This guide helps you quickly set up and run benchmarks comparing wx with wasmer and wasmtime.

## Prerequisites

1. **Build wx** (required):
   ```bash
   cd .. && zig build -Doptimize=ReleaseFast
   ```

2. **Install comparison runtimes** (optional but recommended):

   ### Install Wasmer
   ```bash
   curl https://get.wasmer.io -sSfL | sh
   ```

   ### Install Wasmtime
   ```bash
   curl https://wasmtime.dev/install.sh -sSfL | bash
   ```

   > **Note**: The benchmark scripts will work even if wasmer/wasmtime are not installed. They'll just test wx performance alone.

## Running Benchmarks

### Option 1: Comprehensive Python Benchmark (Recommended)

```bash
cd bench
python3 benchmark.py
```

**Features:**
- Tests all WASM files in `bench/wasm/` and `examples/`
- Runs each benchmark 5 times for accuracy
- Shows detailed comparison and speedup ratios
- Gracefully handles missing runtimes
- Provides comprehensive summary

**Example Output:**
```
🚀 WebAssembly Runtime Benchmark Suite
================================================================================

📋 Checking runtime availability...
  ✅ wx
  ✅ wasmer
  ✅ wasmtime

📊 Benchmark: arithmetic_bench.wasm
------------------------------------------------------------
  ✅ wx           - 105.26ms
  ✅ wasmer       - 156.43ms
  ✅ wasmtime     - 178.92ms

    🏆 wx is 1.49x FASTER than wasmer
    🏆 wx is 1.70x FASTER than wasmtime
```

### Option 2: Shell Script Benchmark

```bash
cd bench
./run.sh
```

**Features:**
- Tests the `opcodes_cli.wasm` workload
- Uses `hyperfine` if available for precise timing
- Falls back to `/usr/bin/time` if hyperfine not installed
- Tests multiple operations (arithmetic, memory, control flow)

### Option 3: Legacy Extended Benchmark

```bash
# From project root
python3 bench_extended.py
```

> **Note**: Use `benchmark.py` instead for better features and error handling.

## Understanding Results

### Performance Metrics

- **Execution Time**: Time to run the WASM file from start to finish
- **Speedup Ratio**: How many times faster wx is compared to other runtimes
- **Win Rate**: Percentage of benchmarks where wx is fastest

### What "Winning" Means

wx is considered the winner for a benchmark if its average execution time is lower than the competing runtime.

### Expected Results

wx is optimized for:
- ✅ Arithmetic-heavy workloads
- ✅ Computational loops
- ✅ Memory operations
- ✅ Simple control flow

wx may be slower for:
- ⚠️ Very large WASM modules (compilation overhead)
- ⚠️ JIT-optimized long-running programs (wasmtime/wasmer excel here)

## Troubleshooting

### "wx not found"
```bash
# Build wx first
cd .. && zig build -Doptimize=ReleaseFast
```

### "No benchmark files found"
```bash
# The benchmark files should already exist in bench/wasm/
# Check if they're there:
ls bench/wasm/*.wasm
```

### "wasmer/wasmtime not found"
This is not an error! The benchmarks will still run and test wx performance. Install wasmer and wasmtime if you want comparative benchmarks.

### Benchmarks take too long
- The default is 5 runs per benchmark
- For quick testing, you can modify `benchmark.py` to use fewer runs
- Or use the shell script `run.sh` which is faster

## Creating Custom Benchmarks

1. **Write your benchmark in WAT format:**
   ```wat
   (module
     (func $main (result i32)
       i32.const 42
     )
     (export "_start" (func $main))
   )
   ```

2. **Compile to WASM:**
   ```bash
   wat2wasm my_benchmark.wat -o my_benchmark.wasm
   ```

3. **Copy to benchmark directory:**
   ```bash
   cp my_benchmark.wasm bench/wasm/
   ```

4. **Run benchmarks:**
   ```bash
   cd bench && python3 benchmark.py
   ```

The benchmark script will automatically discover and test your new file!

## Tips for Accurate Benchmarks

1. **Close other applications** to reduce system noise
2. **Run multiple times** - the scripts already do this
3. **Use release builds** - `zig build -Doptimize=ReleaseFast`
4. **Disable CPU throttling** if testing on laptops
5. **Use identical WASM files** for all runtimes
6. **Test on representative workloads** for your use case

## More Information

- Full benchmark documentation: [README.md](README.md)
- Creating benchmarks: [../examples/](../examples/)
- AOT compilation benchmarks: [../AOT.md](../AOT.md)
