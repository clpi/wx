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
    ;; First, test basic arithmetic to see if stack works
    i32.const 5
    i32.const 3
    i32.add
    i32.const 8
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

    ;; Then test rem_s
    i32.const 10
    i32.const 3
    i32.rem_s
    local.set $result

    ;; Check what we actually got
    local.get $result
    i32.const 0
    i32.eq
    if
      i32.const 32
      i32.const 16
      call $print
    end

    local.get $result
    i32.const 1
    i32.eq
    if
      i32.const 48
      i32.const 16
      call $print
    end

    local.get $result
    i32.const -1
    i32.eq
    if
      i32.const 64
      i32.const 16
      call $print
    end
  )

  (data (i32.const 0) "Basic add: PASS\0a")
  (data (i32.const 16) "Basic add: FAIL\0a")
  (data (i32.const 32) "rem_s is 0\0a\0a\0a\0a\0a")
  (data (i32.const 48) "rem_s is 1\0a\0a\0a\0a\0a")
  (data (i32.const 64) "rem_s is -1\0a\0a\0a\0a")
)