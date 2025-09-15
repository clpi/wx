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

  (func $main (local $result i32)
    ;; Step 1: Test if rem_s returns correct value
    i32.const 10
    i32.const 3
    i32.rem_s
    ;; Save result for later
    local.tee $result
    ;; Compare to 1
    i32.const 1
    i32.eq
    if
      i32.const 0
      i32.const 14
      call $print
    else
      i32.const 14
      i32.const 14
      call $print
    end

    ;; Step 2: Also test if the result is 0 (to see what it actually is)
    local.get $result
    i32.const 0
    i32.eq
    if
      i32.const 28
      i32.const 16
      call $print
    else
      i32.const 44
      i32.const 16
      call $print
    end
  )
  (data (i32.const 0) "rem_s == 1: OK")
  (data (i32.const 14) "rem_s != 1: NO")
  (data (i32.const 28) "rem_s == 0: YES")
  (data (i32.const 44) "rem_s != 0: NO\0a\0a")
)