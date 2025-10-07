# WAZM

> _`Webassembly` Zig runtime_

[![Build](https://github.com/clpi/wx/actions/workflows/build.yml/badge.svg)](https://github.com/clpi/wx/actions/workflows/build.yml)
[![Docker](https://github.com/clpi/wx/actions/workflows/docker.yml/badge.svg)](https://github.com/clpi/wx/actions/workflows/docker.yml)
[![DockerHub](https://img.shields.io/docker/v/clpi/wx?label=dockerhub)](https://hub.docker.com/r/clpi/wx)

### Introduction

This repository contains `wx`, a WebAssembly runtime written in Zig with basic WASI support.

New: a WASI CLI workload `opcodes_cli.wasm` that exercises core WASM operations and can be run under `wx`, `wasmtime`, or `wasmer`. A simple benchmark harness is included.

### Installation

#### Docker

Pre-built Docker images are available on DockerHub and Quay.io:

```bash
# Pull from DockerHub
docker pull clpi/wx:latest

# Pull from Quay.io
docker pull quay.io/clpi/wx:latest

# Run a WASM file
docker run -v $(pwd):/workspace clpi/wx your-file.wasm
```

#### Build from source

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
