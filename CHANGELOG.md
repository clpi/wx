# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Changelog and Contributing files
- GitHub Copilot instructions

## [0.0.0-alpha] - 2025-01-XX

### Added
- Initial WebAssembly runtime written in Zig
- Basic WASI support
- WASI CLI workload `opcodes_cli.wasm` that exercises core WASM operations
- Support for running WASM files with `wx` runtime
- Benchmark harness comparing `wx` vs `wasmtime` vs `wasmer`
- Extended benchmark suite (`bench_extended.py`)
- Support for i32/i64/f32/f64 arithmetic operations
- Memory operations support
- Control flow operations
- Command-line interface with help and version flags
- Debug output mode (`--debug`)
- JIT compilation flag (`--jit`)
- Example WASM files for testing
- Comprehensive benchmark suite with multiple workloads
- MIT License

### Features
- WebAssembly module loading and parsing
- WASM opcode execution
- Function calls and exports
- Memory management
- WASI syscall interface
- Multiple runtime comparisons

[Unreleased]: https://github.com/clpi/wx/compare/v0.0.0-alpha...HEAD
[0.0.0-alpha]: https://github.com/clpi/wx/releases/tag/v0.0.0-alpha
