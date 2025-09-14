(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  
  ;; Test result strings
  (data (i32.const 0) "PASS: ")
  (data (i32.const 6) "FAIL: ")
  (data (i32.const 12) "i32.add\n")
  (data (i32.const 20) "i32.sub\n")
  (data (i32.const 28) "i32.mul\n")
  (data (i32.const 36) "i32.div_s\n")
  (data (i32.const 46) "i32.div_u\n")
  (data (i32.const 56) "i32.rem_s\n")
  (data (i32.const 66) "i32.rem_u\n")
  (data (i32.const 76) "i32.and\n")
  (data (i32.const 84) "i32.or\n")
  (data (i32.const 91) "i32.xor\n")
  (data (i32.const 99) "i32.shl\n")
  (data (i32.const 107) "i32.shr_s\n")
  (data (i32.const 117) "i32.shr_u\n")
  (data (i32.const 127) "i32.rotl\n")
  (data (i32.const 136) "i32.rotr\n")
  (data (i32.const 145) "i32.clz\n")
  (data (i32.const 153) "i32.ctz\n")
  (data (i32.const 161) "i32.popcnt\n")
  (data (i32.const 172) "i32.eqz\n")
  (data (i32.const 180) "i32.eq\n")
  (data (i32.const 187) "i32.ne\n")
  (data (i32.const 194) "i32.lt_s\n")
  (data (i32.const 203) "i32.lt_u\n")
  (data (i32.const 212) "i32.gt_s\n")
  (data (i32.const 221) "i32.gt_u\n")
  (data (i32.const 230) "i32.le_s\n")
  (data (i32.const 239) "i32.le_u\n")
  (data (i32.const 248) "i32.ge_s\n")
  (data (i32.const 257) "i32.ge_u\n")
  (data (i32.const 266) "i64.add\n")
  (data (i32.const 274) "i64.sub\n")
  (data (i32.const 282) "i64.mul\n")
  (data (i32.const 290) "i64.clz\n")
  (data (i32.const 298) "i64.ctz\n")
  (data (i32.const 306) "i64.popcnt\n")
  (data (i32.const 317) "f32.add\n")
  (data (i32.const 325) "f32.sub\n")
  (data (i32.const 333) "f32.mul\n")
  (data (i32.const 341) "f32.div\n")
  (data (i32.const 349) "f32.abs\n")
  (data (i32.const 357) "f32.neg\n")
  (data (i32.const 365) "f32.sqrt\n")
  (data (i32.const 374) "f32.ceil\n")
  (data (i32.const 383) "f32.floor\n")
  (data (i32.const 393) "All tests completed!\n")

  ;; Print function helper
  (func $print (param $offset i32) (param $length i32)
    ;; Setup iovec for fd_write
    (i32.store (i32.const 512) (local.get $offset))  ;; iov_base
    (i32.store (i32.const 516) (local.get $length))  ;; iov_len
    
    ;; Call fd_write(stdout, iovs, iovs_len, nwritten)
    (call $fd_write
      (i32.const 1)     ;; stdout
      (i32.const 512)   ;; iovs
      (i32.const 1)     ;; iovs_len
      (i32.const 520)   ;; nwritten
    )
    drop
  )

  ;; Print PASS message
  (func $print_pass (param $test_offset i32) (param $test_length i32)
    (call $print (i32.const 0) (i32.const 6))  ;; "PASS: "
    (call $print (local.get $test_offset) (local.get $test_length))
  )

  ;; Print FAIL message
  (func $print_fail (param $test_offset i32) (param $test_length i32)
    (call $print (i32.const 6) (i32.const 6))  ;; "FAIL: "
    (call $print (local.get $test_offset) (local.get $test_length))
  )

  ;; Test i32 arithmetic operations
  (func $test_i32_arithmetic
    ;; Test i32.add: 5 + 3 = 8
    (i32.const 5)
    (i32.const 3)
    i32.add
    (i32.const 8)
    i32.eq
    (if
      (then (call $print_pass (i32.const 12) (i32.const 8)))
      (else (call $print_fail (i32.const 12) (i32.const 8)))
    )

    ;; Test i32.sub: 10 - 4 = 6
    (i32.const 10)
    (i32.const 4)
    i32.sub
    (i32.const 6)
    i32.eq
    (if
      (then (call $print_pass (i32.const 20) (i32.const 8)))
      (else (call $print_fail (i32.const 20) (i32.const 8)))
    )

    ;; Test i32.mul: 6 * 7 = 42
    (i32.const 6)
    (i32.const 7)
    i32.mul
    (i32.const 42)
    i32.eq
    (if
      (then (call $print_pass (i32.const 28) (i32.const 8)))
      (else (call $print_fail (i32.const 28) (i32.const 8)))
    )

    ;; Test i32.div_s: -10 / 2 = -5
    (i32.const -10)
    (i32.const 2)
    i32.div_s
    (i32.const -5)
    i32.eq
    (if
      (then (call $print_pass (i32.const 36) (i32.const 10)))
      (else (call $print_fail (i32.const 36) (i32.const 10)))
    )

    ;; Test i32.rem_s: 10 % 3 = 1
    (i32.const 10)
    (i32.const 3)
    i32.rem_s
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 56) (i32.const 10)))
      (else (call $print_fail (i32.const 56) (i32.const 10)))
    )
  )

  ;; Test i32 bitwise operations
  (func $test_i32_bitwise
    ;; Test i32.and: 0xFF & 0x0F = 0x0F (255 & 15 = 15)
    (i32.const 255)
    (i32.const 15)
    i32.and
    (i32.const 15)
    i32.eq
    (if
      (then (call $print_pass (i32.const 76) (i32.const 8)))
      (else (call $print_fail (i32.const 76) (i32.const 8)))
    )

    ;; Test i32.or: 0x0F | 0xF0 = 0xFF (15 | 240 = 255)
    (i32.const 15)
    (i32.const 240)
    i32.or
    (i32.const 255)
    i32.eq
    (if
      (then (call $print_pass (i32.const 84) (i32.const 7)))
      (else (call $print_fail (i32.const 84) (i32.const 7)))
    )

    ;; Test i32.xor: 0xFF ^ 0x0F = 0xF0 (255 ^ 15 = 240)
    (i32.const 255)
    (i32.const 15)
    i32.xor
    (i32.const 240)
    i32.eq
    (if
      (then (call $print_pass (i32.const 91) (i32.const 8)))
      (else (call $print_fail (i32.const 91) (i32.const 8)))
    )

    ;; Test i32.shl: 1 << 3 = 8
    (i32.const 1)
    (i32.const 3)
    i32.shl
    (i32.const 8)
    i32.eq
    (if
      (then (call $print_pass (i32.const 99) (i32.const 8)))
      (else (call $print_fail (i32.const 99) (i32.const 8)))
    )

    ;; Test i32.shr_u: 16 >> 2 = 4
    (i32.const 16)
    (i32.const 2)
    i32.shr_u
    (i32.const 4)
    i32.eq
    (if
      (then (call $print_pass (i32.const 117) (i32.const 10)))
      (else (call $print_fail (i32.const 117) (i32.const 10)))
    )

    ;; Test i32.rotl: rotate left 0x12345678, 4 positions  
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotl
    (i32.const 0x23456781)
    i32.eq
    (if
      (then (call $print_pass (i32.const 127) (i32.const 9)))
      (else (call $print_fail (i32.const 127) (i32.const 9)))
    )

    ;; Test i32.rotr: rotate right 0x12345678, 4 positions
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotr
    (i32.const 0x81234567)
    i32.eq
    (if
      (then (call $print_pass (i32.const 136) (i32.const 9)))
      (else (call $print_fail (i32.const 136) (i32.const 9)))
    )
  )

  ;; Test i32 count operations  
  (func $test_i32_count
    ;; Test i32.clz: count leading zeros of 0x0000FFFF = 16
    (i32.const 0x0000FFFF)
    i32.clz
    (i32.const 16)
    i32.eq
    (if
      (then (call $print_pass (i32.const 145) (i32.const 8)))
      (else (call $print_fail (i32.const 145) (i32.const 8)))
    )

    ;; Test i32.ctz: count trailing zeros of 0xFF000000 = 24
    (i32.const 0xFF000000)
    i32.ctz
    (i32.const 24)
    i32.eq
    (if
      (then (call $print_pass (i32.const 153) (i32.const 8)))
      (else (call $print_fail (i32.const 153) (i32.const 8)))
    )

    ;; Test i32.popcnt: count set bits in 0x0000000F = 4  
    (i32.const 0x0000000F)
    i32.popcnt
    (i32.const 4)
    i32.eq
    (if
      (then (call $print_pass (i32.const 161) (i32.const 11)))
      (else (call $print_fail (i32.const 161) (i32.const 11)))
    )
  )

  ;; Test i32 comparison operations
  (func $test_i32_comparisons
    ;; Test i32.eqz: 0 == 0 -> true
    (i32.const 0)
    i32.eqz
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 172) (i32.const 8)))
      (else (call $print_fail (i32.const 172) (i32.const 8)))
    )

    ;; Test i32.eq: 5 == 5 -> true
    (i32.const 5)
    (i32.const 5)
    i32.eq
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 180) (i32.const 7)))
      (else (call $print_fail (i32.const 180) (i32.const 7)))
    )

    ;; Test i32.ne: 5 != 3 -> true
    (i32.const 5)
    (i32.const 3)
    i32.ne
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 187) (i32.const 7)))
      (else (call $print_fail (i32.const 187) (i32.const 7)))
    )

    ;; Test i32.lt_s: -1 < 1 -> true
    (i32.const -1)
    (i32.const 1)
    i32.lt_s
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 194) (i32.const 9)))
      (else (call $print_fail (i32.const 194) (i32.const 9)))
    )

    ;; Test i32.gt_u: 4294967295 > 1 -> true (unsigned comparison)
    (i32.const -1)  ;; This is 4294967295 as unsigned
    (i32.const 1)
    i32.gt_u
    (i32.const 1)
    i32.eq
    (if
      (then (call $print_pass (i32.const 221) (i32.const 9)))
      (else (call $print_fail (i32.const 221) (i32.const 9)))
    )
  )

  ;; Test i64 operations
  (func $test_i64_operations
    ;; Test i64.add: 1000000000000 + 2000000000000 = 3000000000000
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.add
    (i64.const 3000000000000)
    i64.eq
    (if
      (then (call $print_pass (i32.const 266) (i32.const 8)))
      (else (call $print_fail (i32.const 266) (i32.const 8)))
    )

    ;; Test i64.sub: 5000000000000 - 2000000000000 = 3000000000000
    (i64.const 5000000000000)
    (i64.const 2000000000000)
    i64.sub
    (i64.const 3000000000000)
    i64.eq
    (if
      (then (call $print_pass (i32.const 274) (i32.const 8)))
      (else (call $print_fail (i32.const 274) (i32.const 8)))
    )

    ;; Test i64.mul: 1000000 * 1000000 = 1000000000000
    (i64.const 1000000)
    (i64.const 1000000)
    i64.mul
    (i64.const 1000000000000)
    i64.eq
    (if
      (then (call $print_pass (i32.const 282) (i32.const 8)))
      (else (call $print_fail (i32.const 282) (i32.const 8)))
    )

    ;; Test i64.clz: count leading zeros of 0x00000000FFFFFFFF = 32
    (i64.const 0x00000000FFFFFFFF)
    i64.clz
    (i64.const 32)
    i64.eq
    (if
      (then (call $print_pass (i32.const 290) (i32.const 8)))
      (else (call $print_fail (i32.const 290) (i32.const 8)))
    )

    ;; Test i64.popcnt: count set bits in 0x000000000000FFFF = 16
    (i64.const 0x000000000000FFFF)
    i64.popcnt
    (i64.const 16)
    i64.eq
    (if
      (then (call $print_pass (i32.const 306) (i32.const 11)))
      (else (call $print_fail (i32.const 306) (i32.const 11)))
    )
  )

  ;; Test f32 operations
  (func $test_f32_operations
    ;; Test f32.add: 1.5 + 2.5 = 4.0
    (f32.const 1.5)
    (f32.const 2.5)
    f32.add
    (f32.const 4.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 317) (i32.const 8)))
      (else (call $print_fail (i32.const 317) (i32.const 8)))
    )

    ;; Test f32.sub: 5.5 - 2.5 = 3.0
    (f32.const 5.5)
    (f32.const 2.5)
    f32.sub
    (f32.const 3.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 325) (i32.const 8)))
      (else (call $print_fail (i32.const 325) (i32.const 8)))
    )

    ;; Test f32.mul: 2.5 * 4.0 = 10.0
    (f32.const 2.5)
    (f32.const 4.0)
    f32.mul
    (f32.const 10.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 333) (i32.const 8)))
      (else (call $print_fail (i32.const 333) (i32.const 8)))
    )

    ;; Test f32.div: 12.0 / 3.0 = 4.0
    (f32.const 12.0)
    (f32.const 3.0)
    f32.div
    (f32.const 4.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 341) (i32.const 8)))
      (else (call $print_fail (i32.const 341) (i32.const 8)))
    )

    ;; Test f32.abs: abs(-3.5) = 3.5
    (f32.const -3.5)
    f32.abs
    (f32.const 3.5)
    f32.eq
    (if
      (then (call $print_pass (i32.const 349) (i32.const 8)))
      (else (call $print_fail (i32.const 349) (i32.const 8)))
    )

    ;; Test f32.neg: -(-2.5) = 2.5
    (f32.const -2.5)
    f32.neg
    (f32.const 2.5)
    f32.eq
    (if
      (then (call $print_pass (i32.const 357) (i32.const 8)))
      (else (call $print_fail (i32.const 357) (i32.const 8)))
    )

    ;; Test f32.sqrt: sqrt(9.0) = 3.0
    (f32.const 9.0)
    f32.sqrt
    (f32.const 3.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 365) (i32.const 9)))
      (else (call $print_fail (i32.const 365) (i32.const 9)))
    )

    ;; Test f32.ceil: ceil(2.3) = 3.0
    (f32.const 2.3)
    f32.ceil
    (f32.const 3.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 374) (i32.const 9)))
      (else (call $print_fail (i32.const 374) (i32.const 9)))
    )

    ;; Test f32.floor: floor(2.7) = 2.0
    (f32.const 2.7)
    f32.floor
    (f32.const 2.0)
    f32.eq
    (if
      (then (call $print_pass (i32.const 383) (i32.const 10)))
      (else (call $print_fail (i32.const 383) (i32.const 10)))
    )
  )

  ;; Main entry point
  (func (export "_start")
    ;; Run all test suites
    (call $test_i32_arithmetic)
    (call $test_i32_bitwise)  
    (call $test_i32_count)
    (call $test_i32_comparisons)
    (call $test_i64_operations)
    (call $test_f32_operations)
    
    ;; Print completion message
    (call $print (i32.const 393) (i32.const 21))
  )
)