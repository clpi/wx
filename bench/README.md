Benchmarks

- Compares wx vs wasmtime vs wasmer on the same WASI CLI workload.
- Runs the `opcodes_cli.wasm` with several subcommands and an `--all`-style workload.

Requirements

- `zig` to build `wx` and the WASI workload.
- `wasmtime` and/or `wasmer` in PATH (optional; results are skipped if missing).
- `hyperfine` (optional) for nicer statistics; falls back to `/usr/bin/time -p`.

Usage

- Build everything: `zig build && zig build opcodes-wasm`
- Compile WAT CLI (optional, preferred for broad engine compatibility):
  - `wat2wasm examples/opcodes_cli.wat -o examples/opcodes_cli.wasm`
  - For a minimal compatibility workload that avoids complex control flow for wx: `wat2wasm examples/opcodes_compat.wat -o examples/opcodes_compat.wasm`
- Run: `bench/run.sh`
  - Override workload via env var: `WX_WASM=examples/opcodes_compat.wasm bench/run.sh`
