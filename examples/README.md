# WebAssembly Benchmark Examples

This directory contains WebAssembly benchmark files used to test the performance of the `wx` runtime against other runtimes like Wasmer and Wasmtime.

## Benchmarks

### Core Benchmarks

- **simple.wat/wasm** - Basic WebAssembly operations (add, function calls)
- **opcode_test_simple.wat/wasm** - Tests opcodes across i32, i64, f32, f64 types
- **arithmetic_bench.wat/wasm** - Intensive arithmetic loop (1M iterations)
- **compute_bench.wat/wasm** - Fibonacci computation benchmark
- **simple_bench.wat/wasm** - Factorial with function calls
- **comprehensive_bench.wat/wasm** - Multi-feature benchmark (memory, globals, control flow)

## Building from Source

To rebuild the WASM files from WAT source:

```bash
# Install wabt if not already installed
sudo apt-get install wabt

# Compile all WAT files
for f in *.wat; do
  wat2wasm "$f" -o "${f%.wat}.wasm"
done
```

## Running Benchmarks

See the main [benchmark suite documentation](../bench/README.md) for details on running the full benchmark suite.

Quick test with wx:

```bash
# Build wx
cd .. && zig build

# Run a benchmark
./zig-out/bin/wx examples/simple.wasm
```

## Performance Goals

The wx runtime aims to be **faster than both Wasmer and Wasmtime** on all benchmarks through:

- Pattern matching for computational hot spots
- Mathematical optimization of loops
- Zero-overhead interpreter dispatch
- Fast arithmetic operation handlers
- Optimized function call mechanisms
