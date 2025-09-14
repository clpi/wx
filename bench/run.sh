#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "$0")/.." && pwd)"
wx_bin="$root_dir/zig-out/bin/wx"
# Prefer the WAT-based CLI if compiled; else use Zig-built WASI CLI
work_wasm="${WX_WASM:-$root_dir/examples/opcodes_cli.wasm}"

if [[ ! -f "$work_wasm" ]]; then
  if command -v wat2wasm >/dev/null 2>&1; then
    echo "Compiling examples/opcodes_cli.wat -> examples/opcodes_cli.wasm ..." >&2
    wat2wasm "$root_dir/examples/opcodes_cli.wat" -o "$root_dir/examples/opcodes_cli.wasm"
  else
    work_wasm="$root_dir/zig-out/bin/opcodes_cli.wasm"
  fi
fi

if [[ ! -x "$wx_bin" ]]; then
  echo "Building wx..." >&2
  zig build >/dev/null
fi

if [[ ! -f "$work_wasm" ]]; then
  echo "Building WASI workload (opcodes_cli.wasm)..." >&2
  zig build opcodes-wasm >/dev/null
fi

have_hyperfine=0
if command -v hyperfine >/dev/null 2>&1; then
  have_hyperfine=1
fi

have_wasmtime=0
if command -v wasmtime >/dev/null 2>&1; then
  have_wasmtime=1
fi

have_wasmer=0
if command -v wasmer >/dev/null 2>&1; then
  have_wasmer=1
fi

echo "Benchmarking with workload: $work_wasm"
echo "wx:        $wx_bin"
echo "wasmtime:  $([[ $have_wasmtime -eq 1 ]] && wasmtime --version || echo missing)"
echo "wasmer:    $([[ $have_wasmer -eq 1 ]] && wasmer --version || echo missing)"
echo

# Workload mode: normal (CLI with subcommands) or compat (no-arg WASM)
mode="${WX_MODE:-normal}"
if [[ "$mode" == "compat" ]]; then
  run_cmds=("")
else
  run_cmds=(
    "i32.add 1000000 2000000"
    "i64.add 100000000000 200000000000"
    "f32.add 3.14 2.71"
    "f64.mul 3.1415926535 2.7182818284"
    "mem.store-load 8 305419896"
    "control.sum 500000"  # sum 1..n workload
  )
fi

function bench_one() {
  local label="$1"; shift
  local cmdline=("$@")

  echo "== $label =="
  [[ -n "${cmdline[*]}" ]] && echo "  args: ${cmdline[*]}"

  if [[ $have_hyperfine -eq 1 ]]; then
    hyperfine -w 2 -r 5 \
      "$wx_bin $work_wasm ${WX_FLAGS:-} ${cmdline[*]}" \
      $([[ $have_wasmtime -eq 1 ]] && echo "wasmtime $work_wasm -- ${cmdline[*]}" || echo "") \
      $([[ $have_wasmer -eq 1 ]] && echo "wasmer run $work_wasm -- ${cmdline[*]}" || echo "")
  else
    echo "  (hyperfine not found; using /usr/bin/time -p, 3 iterations)"
    for i in 1 2 3; do
      echo "  Iter $i: wx"
      /usr/bin/time -p $wx_bin "$work_wasm" ${WX_FLAGS:-} ${cmdline[*]} >/dev/null || true
      if [[ $have_wasmtime -eq 1 ]]; then
        echo "  Iter $i: wasmtime"
        /usr/bin/time -p wasmtime "$work_wasm" -- ${cmdline[*]} >/dev/null || true
      fi
      if [[ $have_wasmer -eq 1 ]]; then
        echo "  Iter $i: wasmer"
        /usr/bin/time -p wasmer run "$work_wasm" -- ${cmdline[*]} >/dev/null || true
      fi
    done
  fi
  echo
}

if [[ "$mode" == "compat" ]]; then
  bench_one "run" ""
else
  for c in "${run_cmds[@]}"; do
    # split words safely
    IFS=' ' read -r -a parts <<< "$c"
    bench_one "${parts[0]}" "${parts[@]}"
  done
fi

echo "Done."
