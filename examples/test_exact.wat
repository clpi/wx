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
    ;; Test exact same computation as in opcode_test.wasm
    ;; For rem_s: 10 rem_s 3 should equal 1
    i32.const 10
    i32.const 3
    i32.rem_s
    ;; Now we have the result on stack, let's test it equals 1
    i32.const 1
    i32.eq
    ;; Print result directly
    if
      i32.const 0
      i32.const 11
      call $print
    else
      i32.const 11
      i32.const 11
      call $print
    end

    ;; For rotr: 305419896 rotr 4 should equal -2128394905
    i32.const 305419896
    i32.const 4
    i32.rotr
    i32.const -2128394905
    i32.eq
    if
      i32.const 22
      i32.const 11
      call $print
    else
      i32.const 33
      i32.const 11
      call $print
    end
  )

  (data (i32.const 0) "rem_s: PASS")
  (data (i32.const 11) "rem_s: FAIL")
  (data (i32.const 22) "rotr: PASS\0a")
  (data (i32.const 33) "rotr: FAIL\0a")
)