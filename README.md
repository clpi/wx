# WAZM

> _`Webassembly` Zig runtime_

### Introduction

This repository contains `wx`, a WebAssembly runtime written in Zig with basic WASI support.

New: a WASI CLI workload `opcodes_cli.wasm` that exercises core WASM operations and can be run under `wx`, `wasmtime`, or `wasmer`. A simple benchmark harness is included.

### Installation

Build the runtime:

- `zig build` — build the `wx` binary
- `zig build opcodes-wasm` — build `zig-out/bin/opcodes_cli.wasm`

Run the WASI CLI with `wx`:

- `zig-out/bin/wx zig-out/bin/opcodes_cli.wasm --list`
- `zig-out/bin/wx zig-out/bin/opcodes_cli.wasm i32.add 5 3`

Benchmark against other engines:

- `bench/run.sh` — compares `wx` vs `wasmtime` vs `wasmer` if available
- `python3 bench_extended.py` — run extended benchmark suite (requires benchmark WASM files)

### See also
