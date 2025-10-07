# TODO

This file tracks planned features, improvements, and known issues for the wx WebAssembly runtime.

## High Priority

### Core Runtime Features
- [ ] Complete WASI support
  - [ ] File system operations (fd_read, fd_write, fd_seek, etc.)
  - [ ] Environment variables access
  - [ ] Clock and time functions
  - [ ] Random number generation
  - [ ] Process management functions
- [ ] Implement missing WebAssembly opcodes
  - [ ] SIMD instructions (v128 operations)
  - [ ] Atomic operations (memory.atomic.*)
  - [ ] Reference types (ref.null, ref.is_null, etc.)
  - [ ] Bulk memory operations (memory.fill, memory.copy)
  - [ ] Table operations (table.get, table.set, table.grow)

### JIT Compilation
- [ ] Complete JIT compiler implementation
  - [ ] Handle all WebAssembly value types (i32, i64, f32, f64)
  - [ ] Implement control flow compilation (if/else, loops, br_table)
  - [ ] Add function call compilation
  - [ ] Implement proper register allocation
- [ ] Add runtime callback implementation (see src/wasm/jit.zig TODOs)
- [ ] Optimize hot path detection and compilation triggers
- [ ] Add inline caching for dynamic dispatch
- [ ] Profile-guided optimization support

### Memory Management
- [ ] Implement memory.grow operation correctly
- [ ] Add memory bounds checking optimization
- [ ] Support multiple memory instances (multi-memory proposal)
- [ ] Implement passive data segments properly (memory.init, data.drop)
- [ ] Add memory protection and sandboxing

## Medium Priority

### Performance Optimization
- [ ] Pattern matching for computational hot spots
- [ ] Mathematical optimization of loops
- [ ] Zero-overhead interpreter dispatch
- [ ] Fast arithmetic operation handlers
- [ ] Optimized function call mechanisms
- [ ] Reduce allocations in hot paths
- [ ] Add performance profiling tools
- [ ] Implement tiered compilation (interpreter → baseline JIT → optimized JIT)

### Testing & Quality
- [ ] Add comprehensive unit tests for all opcodes
- [ ] Create integration tests for WASI functions
- [ ] Add fuzzing support for module parsing
- [ ] Test against WebAssembly spec test suite
- [ ] Add regression tests for bug fixes
- [ ] Implement continuous benchmarking
- [ ] Add code coverage reporting

### Developer Experience
- [ ] Improve error messages and diagnostics
- [ ] Add debug logging levels
- [ ] Create developer documentation
- [ ] Add profiling output options
- [ ] Implement trace logging for execution
- [ ] Add interactive debugger support

## Low Priority

### Additional Features
- [ ] Support WebAssembly exceptions proposal
- [ ] Implement WebAssembly threads proposal
- [ ] Add streaming compilation support
- [ ] Support module linking proposal
- [ ] Implement WebAssembly Component Model
- [ ] Add AOT compilation mode

### Tooling
- [ ] Create WASM validation tool
- [ ] Add WASM disassembler
- [ ] Implement WASM optimizer
- [ ] Add profiling visualization tools
- [ ] Create benchmark comparison dashboard

### Documentation
- [ ] Write API documentation
- [ ] Create architecture guide
- [ ] Document JIT compilation strategy
- [ ] Add performance tuning guide
- [ ] Write contributor guidelines
- [ ] Add examples for common use cases

### Build & Distribution
- [ ] Add Windows build support
- [ ] Create macOS build pipeline
- [ ] Package for common package managers (homebrew, apt, etc.)
- [ ] Add Docker container
- [ ] Create static binary releases

## Known Issues

### Bugs
- [ ] Handle arguments properly in JIT compilation (src/wasm/jit.zig)
- [ ] Fix edge cases in module parsing
- [ ] Resolve memory leaks in long-running programs

### Limitations
- [ ] Limited WASI support (only basic operations)
- [ ] No multi-threading support
- [ ] No streaming compilation
- [ ] Limited error recovery

## Completed
<!-- Move completed items here with date -->
