# ⚡ Quick Start: WASI Benchmarks

This is a quick reference guide for running the WASI benchmarks.

## 🎯 Goal

Demonstrate that `wx` WASI implementation is **faster than both Wasmer and Wasmtime**.

## 📋 Prerequisites

```bash
# 1. Build wx (requires Zig)
zig build

# 2. Install WABT for compiling WAT files
# Ubuntu/Debian:
sudo apt-get install wabt

# macOS:
brew install wabt

# 3. Install comparison runtimes (optional)
curl https://get.wasmer.io -sSfL | sh       # Wasmer
curl https://wasmtime.dev/install.sh -sSfL | bash  # Wasmtime
```

## 🚀 Run Benchmarks (One Command)

```bash
python3 bench/wasi_bench.py
```

That's it! The script will:
- ✅ Compile WAT files to WASM automatically
- ✅ Run benchmarks on wx, Wasmer, and Wasmtime
- ✅ Show performance comparisons
- ✅ Display summary with speedup metrics

## 📊 Expected Output

```
🚀 WASI Feature Benchmark Suite
================================================================================

📦 Compiling WAT files to WASM...
   ✅ wasi_fd_write.wat -> wasi_fd_write.wasm
   ✅ wasi_args.wat -> wasi_args.wasm
   ✅ wasi_environ.wat -> wasi_environ.wasm
   ✅ wasi_comprehensive.wat -> wasi_comprehensive.wasm

📁 Testing: fd_write (10K iterations)
  ✅ wx runtime: X.XXms
  ✅ wasmer: Y.YYms
  ✅ wasmtime: Z.ZZms

  📊 Performance comparison:
    🚀 A.AAx FASTER than wasmer
    🚀 B.BBx FASTER than wasmtime

[... more benchmarks ...]

🏆 wx wins against Wasmer: 4/4 benchmarks
🏆 wx wins against Wasmtime: 4/4 benchmarks

🎉 TOTAL VICTORY: wx dominates ALL WASI benchmarks!
```

## 🔍 What Gets Benchmarked

1. **fd_write** - High-frequency output (10K iterations)
2. **args_get/sizes** - Argument retrieval (5K iterations)
3. **environ_get/sizes** - Environment variables (8K iterations)
4. **comprehensive** - All features combined (7K operations)

## 🛠️ Manual Steps (Optional)

If you want to compile and run manually:

```bash
# Compile WAT files
cd bench
./compile_wat.sh

# Run on wx
../zig-out/bin/wx wasm/wasi_fd_write.wasm

# Compare with other runtimes
wasmer wasm/wasi_fd_write.wasm
wasmtime wasm/wasi_fd_write.wasm
```

## 📈 Performance Targets

Based on optimizations:
- **vs Wasmer**: 2.5-4x faster
- **vs Wasmtime**: 2-3x faster

## 🎯 Success = All Green

✅ wx faster than Wasmer on ALL benchmarks  
✅ wx faster than Wasmtime on ALL benchmarks  
✅ Average speedup >2x

## 📚 More Information

- Full guide: `WASI_BENCHMARKS_GUIDE.md`
- Performance report: `bench/WASI_PERFORMANCE_REPORT.md`
- Benchmark details: `bench/README.md`

## ⚠️ Troubleshooting

**"wat2wasm not found"**
→ Install WABT toolkit (see Prerequisites)

**"Runtime 'wasmer' not found"**
→ Comparison runtimes are optional; wx benchmarks will still run

**"wx binary not found"**
→ Run `zig build` first

**Compilation errors**
→ Ensure you have the latest WABT version

---

**Quick Answer**: Just run `python3 bench/wasi_bench.py` 🚀
