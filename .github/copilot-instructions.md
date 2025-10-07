# GitHub Copilot Instructions for wx

This file provides context and guidelines for GitHub Copilot when assisting with the wx WebAssembly runtime project.

## Project Overview

**wx** is a WebAssembly runtime written in Zig with basic WASI support. It's designed to be lightweight, efficient, and capable of executing WASM modules with WASI syscall support.

## Key Technologies

- **Language**: Zig (version 0.15.1)
- **Target**: WebAssembly (WASM) with WASI support
- **Build System**: Zig build system (`build.zig`)
- **Testing**: Zig's built-in test framework

## Project Goals

1. **Performance**: Aim to be competitive with or faster than Wasmtime and Wasmer
2. **Simplicity**: Keep the codebase clean and maintainable
3. **Correctness**: Properly implement WebAssembly and WASI specifications
4. **Minimal dependencies**: Rely primarily on Zig's standard library

## Code Style Guidelines

### Zig-Specific

- Use 4 spaces for indentation (never tabs)
- Follow Zig naming conventions:
  - `camelCase` for variables and functions
  - `PascalCase` for types and structs
  - `SCREAMING_SNAKE_CASE` for constants
- Prefer explicit error handling with `try` and `catch`
- Use `defer` for cleanup operations
- Leverage Zig's compile-time features when appropriate

### Comments

- Use `///` for public API documentation
- Use `//` for inline comments
- Document complex algorithms and non-obvious behavior
- Keep comments concise and up-to-date with code changes

### Error Handling

- Define custom error sets for different failure modes
- Propagate errors up the call stack with `try`
- Only catch errors when you can meaningfully handle them
- Include context in error messages for debugging

## Architecture

### Main Components

1. **Parser** (`src/parser.zig` or similar):
   - Parses WASM binary format
   - Validates module structure
   - Extracts sections (types, functions, memory, etc.)

2. **Runtime** (`src/runtime.zig` or similar):
   - Manages execution state
   - Executes WASM opcodes
   - Handles function calls and returns
   - Manages value and call stacks

3. **Memory** (`src/memory.zig` or similar):
   - Linear memory implementation
   - Bounds checking
   - Load/store operations

4. **WASI** (`src/wasi.zig` or similar):
   - WASI syscall implementation
   - File descriptor management
   - I/O operations

5. **Main** (`src/main.zig`):
   - CLI argument parsing
   - Module loading and initialization
   - Entry point execution

### Data Structures

- **Module**: Represents a parsed WASM module
- **Runtime**: Execution context with stack and memory
- **Value**: Tagged union for WASM values (i32, i64, f32, f64)
- **Function**: Function definition with type and body

## Common Patterns

### Memory Allocation

```zig
// Use appropriate allocator based on context
const allocator = std.heap.c_allocator;  // For main execution
const allocator = std.testing.allocator;  // For tests

// Always free allocated memory
defer allocator.free(buffer);
```

### Error Handling

```zig
// Define error sets
const RuntimeError = error{
    StackUnderflow,
    InvalidOpcode,
    MemoryOutOfBounds,
};

// Propagate errors
pub fn execute(self: *Runtime) !void {
    const value = try self.stack.pop();
    // ...
}
```

### Testing

```zig
test "opcode execution" {
    const allocator = std.testing.allocator;
    var runtime = try Runtime.init(allocator);
    defer runtime.deinit();
    
    // Test execution
    try runtime.executeOpcode(0x6A); // i32.add
    
    // Verify results
    try std.testing.expectEqual(@as(i32, 42), runtime.stack.peek());
}
```

## Benchmarking

- Use `bench/run.sh` for quick comparisons with other runtimes
- Use `bench_extended.py` for comprehensive benchmarking
- Focus on optimizing hot paths (opcode execution, stack operations)
- Profile before optimizing

## WASM Opcode Implementation

When implementing opcodes:

1. **Validate stack state**: Ensure sufficient values are available
2. **Perform operation**: Execute the opcode's semantics
3. **Update stack**: Push results back onto the stack
4. **Handle errors**: Catch overflow, division by zero, etc.

Example pattern:

```zig
0x6A => { // i32.add
    const b = try self.stack.pop_i32();
    const a = try self.stack.pop_i32();
    const result = a +% b;  // Wrapping add
    try self.stack.push_i32(result);
}
```

## WASI Implementation

When implementing WASI syscalls:

1. **Check parameters**: Validate pointers and sizes
2. **Perform operation**: Execute the syscall
3. **Return status**: Return errno or success
4. **Update state**: Modify runtime state as needed

## Performance Considerations

- **Minimize allocations**: Reuse buffers where possible
- **Inline hot functions**: Use `inline` for small, frequently called functions
- **Avoid unnecessary copies**: Use slices and pointers
- **Batch operations**: Process multiple items at once when possible
- **Profile regularly**: Use `bench/run.sh` to compare performance

## Testing Strategy

1. **Unit tests**: Test individual functions and components
2. **Integration tests**: Test with real WASM files in `examples/`
3. **Benchmark tests**: Verify performance doesn't regress
4. **Edge cases**: Test boundary conditions and error paths

## Common Tasks

### Adding a New Opcode

1. Find the opcode byte in the WASM spec
2. Add a case to the opcode switch statement
3. Implement the opcode semantics
4. Add a test case
5. Update documentation if necessary

### Adding a WASI Syscall

1. Look up the syscall number and signature
2. Implement the function in the WASI module
3. Add error handling for invalid parameters
4. Test with a WASI program that uses the syscall

### Optimizing Performance

1. Profile with benchmarks to find hot spots
2. Optimize the critical path
3. Measure the improvement
4. Ensure tests still pass
5. Update benchmark results

## Dependencies

- **Zig standard library**: Primary dependency
- **No external dependencies**: Keep the project self-contained
- **Build tools**: Only Zig's build system

## Build Commands

```bash
# Build runtime
zig build

# Build WASI CLI workload
zig build opcodes-wasm

# Run tests
zig build test

# Run the runtime
./zig-out/bin/wx <wasm-file>

# Benchmark
bash bench/run.sh
```

## Debugging Tips

- Use `--debug` flag for verbose output
- Add `std.debug.print()` statements for tracing
- Check `last_opcode` and `last_pos` in runtime for error location
- Use `zig build -freference-trace` for detailed build errors

## Resources

- [WebAssembly Specification](https://webassembly.github.io/spec/)
- [WASI Documentation](https://github.com/WebAssembly/WASI)
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)

## Questions and Context

When suggesting code:

- **Prefer clarity over cleverness**: Make code easy to understand
- **Follow existing patterns**: Look at similar code in the project
- **Consider performance**: This is a runtime, speed matters
- **Test thoroughly**: Runtime bugs are hard to track down
- **Document assumptions**: Explain non-obvious decisions

## Version Information

- Current version: 0.0.0-alpha
- Semantic versioning: MAJOR.MINOR.PATCH-PRERELEASE
- Update `build.zig` version when releasing

---

This document helps GitHub Copilot provide better, more contextual assistance for the wx project.
