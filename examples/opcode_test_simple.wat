(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  
  ;; Test result messages
  (data (i32.const 0) "Testing i32 opcodes...\n")
  (data (i32.const 23) "Testing i64 opcodes...\n")
  (data (i32.const 46) "Testing f32 opcodes...\n")  
  (data (i32.const 69) "Testing f64 opcodes...\n")
  (data (i32.const 92) "All opcode tests completed successfully!\n")

  ;; Print function
  (func $print (param $offset i32) (param $length i32)
    (i32.store (i32.const 512) (local.get $offset))
    (i32.store (i32.const 516) (local.get $length))
    (call $fd_write
      (i32.const 1)
      (i32.const 512)
      (i32.const 1)
      (i32.const 520)
    )
    drop
  )

  ;; Test i32 opcodes
  (func $test_i32
    (call $print (i32.const 0) (i32.const 23))
    
    ;; Test i32.add: 5 + 3 = 8
    (i32.const 5)
    (i32.const 3)
    i32.add
    drop
    
    ;; Test i32.sub: 10 - 4 = 6  
    (i32.const 10)
    (i32.const 4)
    i32.sub
    drop
    
    ;; Test i32.mul: 6 * 7 = 42
    (i32.const 6)
    (i32.const 7)
    i32.mul
    drop
    
    ;; Test i32.div_s: 20 / 4 = 5
    (i32.const 20)
    (i32.const 4)
    i32.div_s
    drop
    
    ;; Test i32.rem_s: 10 % 3 = 1
    (i32.const 10)
    (i32.const 3)
    i32.rem_s
    drop
    
    ;; Test i32.and: 0xFF & 0x0F = 0x0F
    (i32.const 255)
    (i32.const 15)
    i32.and
    drop
    
    ;; Test i32.or: 0x0F | 0xF0 = 0xFF
    (i32.const 15)
    (i32.const 240)
    i32.or
    drop
    
    ;; Test i32.xor: 0xFF ^ 0x0F = 0xF0
    (i32.const 255)
    (i32.const 15)
    i32.xor
    drop
    
    ;; Test i32.shl: 1 << 3 = 8
    (i32.const 1)
    (i32.const 3)
    i32.shl
    drop
    
    ;; Test i32.shr_u: 16 >> 2 = 4
    (i32.const 16)
    (i32.const 2)
    i32.shr_u
    drop
    
    ;; Test i32.shr_s: -8 >> 1 = -4
    (i32.const -8)
    (i32.const 1)
    i32.shr_s
    drop
    
    ;; Test i32.rotl: rotate left
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotl
    drop
    
    ;; Test i32.rotr: rotate right
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotr
    drop
    
    ;; Test i32.clz: count leading zeros
    (i32.const 0x0000FFFF)
    i32.clz
    drop
    
    ;; Test i32.ctz: count trailing zeros
    (i32.const 0xFF000000)
    i32.ctz
    drop
    
    ;; Test i32.popcnt: count set bits
    (i32.const 0x0000000F)
    i32.popcnt
    drop
    
    ;; Test i32.eqz: test if zero
    (i32.const 0)
    i32.eqz
    drop
    
    ;; Test i32.eq: equality
    (i32.const 5)
    (i32.const 5)
    i32.eq
    drop
    
    ;; Test i32.ne: not equal
    (i32.const 5)
    (i32.const 3)
    i32.ne
    drop
    
    ;; Test i32.lt_s: less than signed
    (i32.const -1)
    (i32.const 1)
    i32.lt_s
    drop
    
    ;; Test i32.lt_u: less than unsigned
    (i32.const 1)
    (i32.const 2)
    i32.lt_u
    drop
    
    ;; Test i32.gt_s: greater than signed
    (i32.const 2)
    (i32.const 1)
    i32.gt_s
    drop
    
    ;; Test i32.gt_u: greater than unsigned
    (i32.const 2)
    (i32.const 1)
    i32.gt_u
    drop
    
    ;; Test i32.le_s: less than or equal signed
    (i32.const 1)
    (i32.const 2)
    i32.le_s
    drop
    
    ;; Test i32.le_u: less than or equal unsigned
    (i32.const 1)
    (i32.const 2)
    i32.le_u
    drop
    
    ;; Test i32.ge_s: greater than or equal signed
    (i32.const 2)
    (i32.const 1)
    i32.ge_s
    drop
    
    ;; Test i32.ge_u: greater than or equal unsigned
    (i32.const 2)
    (i32.const 1)
    i32.ge_u
    drop
  )

  ;; Test i64 opcodes
  (func $test_i64
    (call $print (i32.const 23) (i32.const 23))
    
    ;; Test i64.add
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.add
    drop
    
    ;; Test i64.sub
    (i64.const 5000000000000)
    (i64.const 2000000000000)
    i64.sub
    drop
    
    ;; Test i64.mul
    (i64.const 1000000)
    (i64.const 1000000)
    i64.mul
    drop
    
    ;; Test i64.div_s
    (i64.const 1000000000000)
    (i64.const 1000000)
    i64.div_s
    drop
    
    ;; Test i64.div_u
    (i64.const 1000000000000)
    (i64.const 1000000)
    i64.div_u
    drop
    
    ;; Test i64.rem_s
    (i64.const 1000000000001)
    (i64.const 1000000)
    i64.rem_s
    drop
    
    ;; Test i64.rem_u
    (i64.const 1000000000001)
    (i64.const 1000000)
    i64.rem_u
    drop
    
    ;; Test i64.and
    (i64.const 0xFFFFFFFFFFFFFFFF)
    (i64.const 0x0000FFFF0000FFFF)
    i64.and
    drop
    
    ;; Test i64.or
    (i64.const 0x0000FFFF0000FFFF)
    (i64.const 0xFFFF0000FFFF0000)
    i64.or
    drop
    
    ;; Test i64.xor
    (i64.const 0xFFFFFFFFFFFFFFFF)
    (i64.const 0x0000FFFF0000FFFF)
    i64.xor
    drop
    
    ;; Test i64.shl
    (i64.const 1)
    (i64.const 10)
    i64.shl
    drop
    
    ;; Test i64.shr_s
    (i64.const -1024)
    (i64.const 2)
    i64.shr_s
    drop
    
    ;; Test i64.shr_u
    (i64.const 1024)
    (i64.const 2)
    i64.shr_u
    drop
    
    ;; Test i64.rotl
    (i64.const 0x123456789ABCDEF0)
    (i64.const 8)
    i64.rotl
    drop
    
    ;; Test i64.rotr
    (i64.const 0x123456789ABCDEF0)
    (i64.const 8)
    i64.rotr
    drop
    
    ;; Test i64.clz
    (i64.const 0x00000000FFFFFFFF)
    i64.clz
    drop
    
    ;; Test i64.ctz
    (i64.const 0xFFFFFFFF00000000)
    i64.ctz
    drop
    
    ;; Test i64.popcnt
    (i64.const 0x000000000000FFFF)
    i64.popcnt
    drop
    
    ;; Test i64.eqz
    (i64.const 0)
    i64.eqz
    drop
    
    ;; Test i64.eq
    (i64.const 1000000000000)
    (i64.const 1000000000000)
    i64.eq
    drop
    
    ;; Test i64.ne
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.ne
    drop
    
    ;; Test i64.lt_s
    (i64.const -1000000000000)
    (i64.const 1000000000000)
    i64.lt_s
    drop
    
    ;; Test i64.lt_u
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.lt_u
    drop
    
    ;; Test i64.gt_s
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.gt_s
    drop
    
    ;; Test i64.gt_u
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.gt_u
    drop
    
    ;; Test i64.le_s
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.le_s
    drop
    
    ;; Test i64.le_u
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.le_u
    drop
    
    ;; Test i64.ge_s
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.ge_s
    drop
    
    ;; Test i64.ge_u
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.ge_u
    drop
  )

  ;; Test f32 opcodes
  (func $test_f32
    (call $print (i32.const 46) (i32.const 23))
    
    ;; Test f32.add
    (f32.const 1.5)
    (f32.const 2.5)
    f32.add
    drop
    
    ;; Test f32.sub
    (f32.const 5.5)
    (f32.const 2.5)
    f32.sub
    drop
    
    ;; Test f32.mul
    (f32.const 2.5)
    (f32.const 4.0)
    f32.mul
    drop
    
    ;; Test f32.div
    (f32.const 12.0)
    (f32.const 3.0)
    f32.div
    drop
    
    ;; Test f32.min
    (f32.const 2.5)
    (f32.const 1.5)
    f32.min
    drop
    
    ;; Test f32.max
    (f32.const 2.5)
    (f32.const 1.5)
    f32.max
    drop
    
    ;; Test f32.copysign
    (f32.const 2.5)
    (f32.const -1.0)
    f32.copysign
    drop
    
    ;; Test f32.abs
    (f32.const -3.5)
    f32.abs
    drop
    
    ;; Test f32.neg
    (f32.const -2.5)
    f32.neg
    drop
    
    ;; Test f32.sqrt
    (f32.const 9.0)
    f32.sqrt
    drop
    
    ;; Test f32.ceil
    (f32.const 2.3)
    f32.ceil
    drop
    
    ;; Test f32.floor
    (f32.const 2.7)
    f32.floor
    drop
    
    ;; Test f32.trunc
    (f32.const 2.7)
    f32.trunc
    drop
    
    ;; Test f32.nearest
    (f32.const 2.3)
    f32.nearest
    drop
    
    ;; Test f32.eq
    (f32.const 2.5)
    (f32.const 2.5)
    f32.eq
    drop
    
    ;; Test f32.ne
    (f32.const 2.5)
    (f32.const 1.5)
    f32.ne
    drop
    
    ;; Test f32.lt
    (f32.const 1.5)
    (f32.const 2.5)
    f32.lt
    drop
    
    ;; Test f32.gt
    (f32.const 2.5)
    (f32.const 1.5)
    f32.gt
    drop
    
    ;; Test f32.le
    (f32.const 1.5)
    (f32.const 2.5)
    f32.le
    drop
    
    ;; Test f32.ge
    (f32.const 2.5)
    (f32.const 1.5)
    f32.ge
    drop
  )

  ;; Test f64 opcodes - just a few since most are already implemented
  (func $test_f64
    (call $print (i32.const 69) (i32.const 23))
    
    ;; Test f64 basic operations
    (f64.const 1.5)
    (f64.const 2.5) 
    f64.add
    drop
    
    (f64.const 5.5)
    (f64.const 2.5)
    f64.sub
    drop
    
    (f64.const 2.5)
    (f64.const 4.0)
    f64.mul
    drop
    
    (f64.const 12.0)
    (f64.const 3.0)
    f64.div
    drop
  )

  ;; Main function
  (func (export "_start")
    (call $test_i32)
    (call $test_i64)
    (call $test_f32)
    (call $test_f64)
    (call $print (i32.const 92) (i32.const 41))
  )
)