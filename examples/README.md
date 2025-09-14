# WebAssembly Examples

This directory contains C examples that can be compiled to WebAssembly and run using the `wx` runtime.

## Examples

- **hello.c** - Simple "Hello World" program
- **math.c** - Basic arithmetic operations and factorial calculation  
- **fibonacci.c** - Fibonacci sequence generator
- **array.c** - Array operations (sum and print)
- **opcodes_cli.wat** - WASI CLI exercising core WASM opcodes (build with `wat2wasm`)

## Building Examples

To compile all examples to WASM:
```bash
make examples
```

To run a specific example:
```bash
make run-hello    # Run hello.wasm
make run-math     # Run math.wasm  
make run-fibonacci # Run fibonacci.wasm
make run-array    # Run array.wasm
# Using wx directly with the WAT-based CLI (after compiling with wat2wasm):
#   wat2wasm examples/opcodes_cli.wat -o examples/opcodes_cli.wasm
#   zig-out/bin/wx examples/opcodes_cli.wasm i32.add
```

To test all examples:
```bash
make test
```

## Requirements

- `emcc` (Emscripten compiler) for compiling C to WASM
- `wx` runtime (built using `zig build`)
