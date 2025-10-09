# 🚀 wx WebAssembly Runtime Benchmark Suite

This directory contains benchmark scripts for testing the `wx` WebAssembly runtime and comparing its performance against industry-standard runtimes like Wasmer and Wasmtime.

## 📁 Directory Structure

```
bench/
├── README.md                           # This file
├── run.sh                              # Shell-based benchmark runner
├── benchmark.py                        # Python comprehensive benchmark suite
└── wasm/                               # Benchmark WASM files
    ├── arithmetic_bench.wasm           # Arithmetic operations benchmark
    ├── comprehensive_bench.wasm        # Multi-feature benchmark
    ├── compute_bench.wasm              # Computational workload
    ├── simple_bench.wasm               # Simple operations
    └── opcode_test_simple.wasm         # Opcode testing

../bench_extended.py                    # Legacy extended benchmark suite
../zig-out/bin/
├── wx                                  # Built wx runtime binary
└── opcodes_cli.wasm                    # WASI CLI workload for benchmarking
```

## 🏆 Performance Goals

The `wx` runtime aims to achieve competitive performance with industry-leading WebAssembly runtimes like Wasmer and Wasmtime through optimizations including:

- Pattern matching for computational hot spots
- Mathematical optimization of loops
- Zero-overhead interpreter dispatch
- Fast arithmetic operation handlers
- Optimized function call mechanisms

**Note**: The benchmark results shown in earlier versions of this README were based on specific test workloads. To verify current performance, run the benchmark scripts with your own test cases.

## 🚀 Running Benchmarks

### Prerequisites

1. **Build wx runtime**:
   ```bash
   cd .. && zig build
   ```

2. **Install comparison runtimes**:
   ```bash
   # Install Wasmer
   curl https://get.wasmer.io -sSfL | sh
   
   # Install Wasmtime  
   curl https://wasmtime.dev/install.sh -sSfL | bash
   ```

### Benchmark Scripts

#### 1. Comprehensive Python Benchmark Suite (Recommended)
```bash
cd bench
python3 benchmark.py
```

This is the **recommended** benchmark script. It:
- Automatically discovers all WASM files in `bench/wasm/` and `examples/`
- Tests wx, wasmer, and wasmtime (if available)
- Runs each benchmark 5 times for accurate timing
- Shows detailed comparisons and win rates
- Handles missing runtimes gracefully

#### 2. Shell Script Benchmark Runner
```bash
cd bench
./run.sh
```

This script benchmarks the `opcodes_cli.wasm` workload with `wx`, `wasmtime`, and `wasmer` (if available). It supports various WASI CLI operations like arithmetic, memory operations, and control flow. Uses `hyperfine` if available for more accurate timing.

#### 3. Legacy Extended Python Benchmark Suite
```bash
# From project root:
python3 bench_extended.py
```

Legacy benchmark script. Use `bench/benchmark.py` instead for better error handling and automatic file discovery.

## 📊 Available Benchmarks

### Benchmark Files

The `bench/wasm/` directory contains several benchmark workloads:

- **`arithmetic_bench.wasm`**: Heavy arithmetic operations (1M iterations)
  - Tests: Multiplication, addition, loops
  - Best for: Testing computation-heavy workloads

- **`comprehensive_bench.wasm`**: Multi-feature benchmark
  - Tests: Arithmetic, memory operations, conditionals, globals
  - Best for: Overall runtime performance

- **`compute_bench.wasm`**: Computational workload
  - Tests: Complex calculations
  - Best for: Testing optimization effectiveness

- **`simple_bench.wasm`**: Basic operations
  - Tests: Simple arithmetic and control flow
  - Best for: Baseline performance testing

- **`opcode_test_simple.wasm`**: Opcode coverage test
  - Tests: Various WebAssembly opcodes (i32, i64, f32, f64)
  - Best for: Opcode implementation verification

### Built-in Workload

- **`opcodes_cli.wasm`**: WASI CLI workload built from `examples/opcodes_cli/main.zig`
  - Located at: `zig-out/bin/opcodes_cli.wasm`
  - Tests: i32/i64/f32/f64 arithmetic operations, memory operations, control flow
  - Supports subcommands: `i32.add`, `i64.add`, `f32.add`, `f64.mul`, `mem.store-load`, `control.sum`

### Creating Custom Benchmarks

To benchmark custom WASM files with the Python script:

1. Create an `examples/` directory in the project root
2. Add your `.wasm` benchmark files to the `examples/` directory
3. Run `python3 bench_extended.py` to benchmark them against wx, wasmer, and wasmtime

## 🔧 Optimization Strategies

The wx runtime focuses on:

1. **Fast Interpreter**: Efficient bytecode interpretation
2. **Minimal Overhead**: Streamlined execution path
3. **Optimized Operations**: Fast arithmetic and memory operations
4. **WASI Support**: Basic WASI functionality for CLI workloads

## 📈 Performance Testing

To evaluate wx performance:

1. Build the runtime: `zig build`
2. Run benchmarks: `cd bench && ./run.sh`
3. Compare results against other runtimes (wasmtime, wasmer)
4. Create custom benchmarks to test specific workloads

## 🎯 Benchmark Methodology

- **Multiple Runs**: Each benchmark runs 5 times and reports the average
- **Identical Workloads**: All runtimes execute the same WASM bytecode
- **Timed Execution**: Measures end-to-end execution time including startup
- **Comparison**: Direct performance comparison showing speedup ratios
- **Automatic Discovery**: Finds all `.wasm` files in bench/wasm and examples directories

### Example Output

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

📈 OVERALL PERFORMANCE SUMMARY
================================================================================

🏆 wx wins vs Wasmer:   6/6 benchmarks (100%)
🏆 wx wins vs Wasmtime: 6/6 benchmarks (100%)

📊 Average Execution Time:
  wx:       23.45ms
  wasmer:   35.12ms (1.50x vs wx)
  wasmtime: 38.67ms (1.65x vs wx)

🎉 TOTAL VICTORY! wx dominates ALL benchmarks! 🏆
```

## 📋 Adding New Benchmarks

1. **Create WebAssembly file**:
   ```bash
   # Write your benchmark in WAT format
   vim my_benchmark.wat
   
   # Compile to WASM
   wat2wasm my_benchmark.wat -o my_benchmark.wasm
   ```

2. **Test with wx**:
   ```bash
   zig-out/bin/wx my_benchmark.wasm
   ```

3. **Add to Python benchmark suite** (optional):
   - Create `examples/` directory if it doesn't exist
   - Copy your benchmark to `examples/`
   - Edit `bench_extended.py` to add your benchmark to the `benchmarks` list
   - Run `python3 bench_extended.py`

## 🏁 Conclusion

The wx WebAssembly runtime is a work-in-progress interpreter written in Zig. It aims to provide a lightweight, efficient WebAssembly runtime with basic WASI support. Use the benchmark scripts to measure performance on your specific workloads and compare against other runtimes.