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
    ;; Test i32.rem_s: 10 % 3 should be 1
    i32.const 10
    i32.const 3
    i32.rem_s
    i32.const 1
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

  (data (i32.const 0) "PASS: i32.rem_s\0a")
  (data (i32.const 16) "FAIL: i32.rem_s\0a")
)