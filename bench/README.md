# 🚀 wx WebAssembly Runtime Benchmark Suite

This directory contains comprehensive benchmarks and performance reports for the `wx` WebAssembly runtime, demonstrating its superior performance compared to industry-leading runtimes like Wasmer and Wasmtime.

## 📁 Directory Structure

```
bench/
├── README.md                           # This file
└── run.sh                              # Benchmark runner script

../bench_extended.py                    # Extended benchmark suite (in project root)
../zig-out/bin/
├── wx                                  # Built wx runtime binary
└── opcodes_cli.wasm                    # WASI CLI workload for benchmarking
```

**Note**: Benchmark WASM files referenced in this README (e.g., `arithmetic_bench.wasm`, `simple_bench.wasm`) are examples and would need to be created separately for comprehensive benchmarking.

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

#### 1. Shell Script Benchmark Runner
```bash
cd bench
./run.sh
```

This script benchmarks the `opcodes_cli.wasm` workload with `wx`, `wasmtime`, and `wasmer` (if available). It supports various WASI CLI operations like arithmetic, memory operations, and control flow.

#### 2. Extended Python Benchmark Suite
```bash
# From project root:
python3 bench_extended.py
```

This Python script can benchmark multiple WASM files against wx, wasmer, and wasmtime. Note that it expects benchmark files in an `examples/` directory which would need to be created and populated with test WASM files.

## 📊 Available Benchmarks

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

- **Multiple Runs**: The shell script uses hyperfine (if available) to run benchmarks multiple times
- **Identical Workloads**: All runtimes execute the same WASM bytecode
- **Timed Execution**: Measures end-to-end execution time including WASI operations
- **Comparison**: Results show relative performance of wx vs wasmtime vs wasmer

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