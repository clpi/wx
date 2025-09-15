(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (export "memory" (memory 0))
  (export "_start" (func $main))

  (func $print (param $offset i32) (param $length i32)
    i32.const 512
    local.get $offset
    i32.store
    i32.const 516
    local.get $length
    i32.store
    i32.const 1
    i32.const 512
    i32.const 1
    i32.const 520
    call $fd_write
    drop
  )

  (func $main
    ;; Exact same test as in opcode_test.wasm
    i32.const 305419896
    i32.const 4
    i32.rotr
    i32.const -2128394905
    i32.eq
    if
      i32.const 0
      i32.const 16
      call $print
    else
      i32.const 16
      i32.const 16
      call $print
    end
  )

  (data (i32.const 0) "PASS: i32.rotr\0a")
  (data (i32.const 16) "FAIL: i32.rotr\0a")
)