(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (export "memory" (memory 0))
  (export "_start" (func $main))

  (func $print_i32 (param $val i32)
    ;; Convert i32 to string representation and print
    i32.const 1000
    local.get $val
    i32.store
    i32.const 1
    i32.const 1000
    i32.const 1
    i32.const 1004
    call $fd_write
    drop
  )

  (func $main
    ;; Test the exact same values as in opcode_test.wasm
    ;; rem_s test: 10 % 3 should be 1
    i32.const 10
    i32.const 3
    i32.rem_s
    call $print_i32

    ;; Print expected value 1
    i32.const 1
    call $print_i32

    ;; rotr test: 305419896 rotr 4 should be -2128394905
    i32.const 305419896
    i32.const 4
    i32.rotr
    call $print_i32

    ;; Print expected value -2128394905
    i32.const -2128394905
    call $print_i32
  )
)