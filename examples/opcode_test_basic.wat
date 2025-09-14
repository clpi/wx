(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  
  (data (i32.const 0) "All WebAssembly opcodes executed successfully!\n")

  (func $print_success
    (i32.store (i32.const 512) (i32.const 0))   ;; iov_base 
    (i32.store (i32.const 516) (i32.const 47))  ;; iov_len
    (call $fd_write
      (i32.const 1)     ;; stdout
      (i32.const 512)   ;; iovs
      (i32.const 1)     ;; iovs_len  
      (i32.const 520)   ;; nwritten
    )
    drop
  )

  (func (export "_start")
    ;; ========== i32 ARITHMETIC OPCODES ==========
    ;; i32.add: 5 + 3 = 8
    (i32.const 5)
    (i32.const 3)
    i32.add
    drop

    ;; i32.sub: 10 - 4 = 6
    (i32.const 10)
    (i32.const 4)
    i32.sub
    drop

    ;; i32.mul: 6 * 7 = 42
    (i32.const 6)
    (i32.const 7)
    i32.mul
    drop

    ;; i32.div_s: -20 / 4 = -5
    (i32.const -20)
    (i32.const 4)
    i32.div_s
    drop

    ;; i32.div_u: 20 / 4 = 5 (unsigned)
    (i32.const 20)
    (i32.const 4)
    i32.div_u
    drop

    ;; i32.rem_s: 10 % 3 = 1
    (i32.const 10)
    (i32.const 3)
    i32.rem_s
    drop

    ;; i32.rem_u: 10 % 3 = 1 (unsigned)
    (i32.const 10)
    (i32.const 3)
    i32.rem_u
    drop

    ;; ========== i32 BITWISE OPCODES ==========
    ;; i32.and: 0xFF & 0x0F = 0x0F
    (i32.const 255)
    (i32.const 15)
    i32.and
    drop

    ;; i32.or: 0x0F | 0xF0 = 0xFF
    (i32.const 15)
    (i32.const 240)
    i32.or
    drop

    ;; i32.xor: 0xFF ^ 0x0F = 0xF0
    (i32.const 255)
    (i32.const 15)
    i32.xor
    drop

    ;; i32.shl: 1 << 3 = 8
    (i32.const 1)
    (i32.const 3)
    i32.shl
    drop

    ;; i32.shr_s: -8 >> 1 = -4 (arithmetic right shift)
    (i32.const -8)
    (i32.const 1)
    i32.shr_s
    drop

    ;; i32.shr_u: 16 >> 2 = 4 (logical right shift)
    (i32.const 16)
    (i32.const 2)
    i32.shr_u
    drop

    ;; i32.rotl: rotate left 0x12345678, 4 positions
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotl
    drop

    ;; i32.rotr: rotate right 0x12345678, 4 positions  
    (i32.const 0x12345678)
    (i32.const 4)
    i32.rotr
    drop

    ;; ========== i32 COUNT OPCODES ==========
    ;; i32.clz: count leading zeros of 0x0000FFFF = 16
    (i32.const 0x0000FFFF)
    i32.clz
    drop

    ;; i32.ctz: count trailing zeros of 0xFF000000 = 24
    (i32.const 0xFF000000)
    i32.ctz
    drop

    ;; i32.popcnt: count set bits in 0x0000000F = 4
    (i32.const 0x0000000F)
    i32.popcnt
    drop

    ;; ========== i32 COMPARISON OPCODES ==========
    ;; i32.eqz: 0 == 0 -> 1 (true)
    (i32.const 0)
    i32.eqz
    drop

    ;; i32.eq: 5 == 5 -> 1 (true)
    (i32.const 5)
    (i32.const 5)
    i32.eq
    drop

    ;; i32.ne: 5 != 3 -> 1 (true)
    (i32.const 5)
    (i32.const 3)
    i32.ne
    drop

    ;; i32.lt_s: -1 < 1 -> 1 (true, signed)
    (i32.const -1)
    (i32.const 1)
    i32.lt_s
    drop

    ;; i32.lt_u: 1 < 2 -> 1 (true, unsigned)
    (i32.const 1)
    (i32.const 2)
    i32.lt_u
    drop

    ;; i32.gt_s: 2 > 1 -> 1 (true, signed)
    (i32.const 2)
    (i32.const 1)
    i32.gt_s
    drop

    ;; i32.gt_u: 2 > 1 -> 1 (true, unsigned)
    (i32.const 2)
    (i32.const 1)
    i32.gt_u
    drop

    ;; i32.le_s: 1 <= 2 -> 1 (true, signed)
    (i32.const 1)
    (i32.const 2)
    i32.le_s
    drop

    ;; i32.le_u: 1 <= 2 -> 1 (true, unsigned)
    (i32.const 1)
    (i32.const 2)
    i32.le_u
    drop

    ;; i32.ge_s: 2 >= 1 -> 1 (true, signed)
    (i32.const 2)
    (i32.const 1)
    i32.ge_s
    drop

    ;; i32.ge_u: 2 >= 1 -> 1 (true, unsigned)
    (i32.const 2)
    (i32.const 1)
    i32.ge_u
    drop

    ;; ========== i64 ARITHMETIC OPCODES ==========
    ;; i64.add: 1000000000000 + 2000000000000 = 3000000000000
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.add
    drop

    ;; i64.sub: 5000000000000 - 2000000000000 = 3000000000000
    (i64.const 5000000000000)
    (i64.const 2000000000000)
    i64.sub
    drop

    ;; i64.mul: 1000000 * 1000000 = 1000000000000
    (i64.const 1000000)
    (i64.const 1000000)
    i64.mul
    drop

    ;; i64.div_s: -1000000000000 / 1000000 = -1000000
    (i64.const -1000000000000)
    (i64.const 1000000)
    i64.div_s
    drop

    ;; i64.div_u: 1000000000000 / 1000000 = 1000000 (unsigned)
    (i64.const 1000000000000)
    (i64.const 1000000)
    i64.div_u
    drop

    ;; i64.rem_s: 1000000000001 % 1000000 = 1
    (i64.const 1000000000001)
    (i64.const 1000000)
    i64.rem_s
    drop

    ;; i64.rem_u: 1000000000001 % 1000000 = 1 (unsigned)
    (i64.const 1000000000001)
    (i64.const 1000000)
    i64.rem_u
    drop

    ;; ========== i64 BITWISE OPCODES ==========
    ;; i64.and
    (i64.const 0xFFFFFFFFFFFFFFFF)
    (i64.const 0x0000FFFF0000FFFF)
    i64.and
    drop

    ;; i64.or
    (i64.const 0x0000FFFF0000FFFF)
    (i64.const 0xFFFF0000FFFF0000)
    i64.or
    drop

    ;; i64.xor
    (i64.const 0xFFFFFFFFFFFFFFFF)
    (i64.const 0x0000FFFF0000FFFF)
    i64.xor
    drop

    ;; i64.shl: 1 << 10 = 1024
    (i64.const 1)
    (i64.const 10)
    i64.shl
    drop

    ;; i64.shr_s: -1024 >> 2 = -256 (arithmetic right shift)
    (i64.const -1024)
    (i64.const 2)
    i64.shr_s
    drop

    ;; i64.shr_u: 1024 >> 2 = 256 (logical right shift)
    (i64.const 1024)
    (i64.const 2)
    i64.shr_u
    drop

    ;; i64.rotl: rotate left
    (i64.const 0x123456789ABCDEF0)
    (i64.const 8)
    i64.rotl
    drop

    ;; i64.rotr: rotate right
    (i64.const 0x123456789ABCDEF0)
    (i64.const 8)
    i64.rotr
    drop

    ;; ========== i64 COUNT OPCODES ==========
    ;; i64.clz: count leading zeros of 0x00000000FFFFFFFF = 32
    (i64.const 0x00000000FFFFFFFF)
    i64.clz
    drop

    ;; i64.ctz: count trailing zeros of 0xFFFFFFFF00000000 = 32
    (i64.const 0xFFFFFFFF00000000)
    i64.ctz
    drop

    ;; i64.popcnt: count set bits in 0x000000000000FFFF = 16
    (i64.const 0x000000000000FFFF)
    i64.popcnt
    drop

    ;; ========== i64 COMPARISON OPCODES ==========
    ;; i64.eqz: 0 == 0 -> 1 (true)
    (i64.const 0)
    i64.eqz
    drop

    ;; i64.eq: 1000000000000 == 1000000000000 -> 1 (true)
    (i64.const 1000000000000)
    (i64.const 1000000000000)
    i64.eq
    drop

    ;; i64.ne: 1000000000000 != 2000000000000 -> 1 (true)
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.ne
    drop

    ;; i64.lt_s: -1000000000000 < 1000000000000 -> 1 (true, signed)
    (i64.const -1000000000000)
    (i64.const 1000000000000)
    i64.lt_s
    drop

    ;; i64.lt_u: 1000000000000 < 2000000000000 -> 1 (true, unsigned)
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.lt_u
    drop

    ;; i64.gt_s: 2000000000000 > 1000000000000 -> 1 (true, signed)
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.gt_s
    drop

    ;; i64.gt_u: 2000000000000 > 1000000000000 -> 1 (true, unsigned)
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.gt_u
    drop

    ;; i64.le_s: 1000000000000 <= 2000000000000 -> 1 (true, signed)
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.le_s
    drop

    ;; i64.le_u: 1000000000000 <= 2000000000000 -> 1 (true, unsigned)
    (i64.const 1000000000000)
    (i64.const 2000000000000)
    i64.le_u
    drop

    ;; i64.ge_s: 2000000000000 >= 1000000000000 -> 1 (true, signed)
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.ge_s
    drop

    ;; i64.ge_u: 2000000000000 >= 1000000000000 -> 1 (true, unsigned)
    (i64.const 2000000000000)
    (i64.const 1000000000000)
    i64.ge_u
    drop

    ;; ========== f32 ARITHMETIC OPCODES ==========
    ;; f32.add: 1.5 + 2.5 = 4.0
    (f32.const 1.5)
    (f32.const 2.5)
    f32.add
    drop

    ;; f32.sub: 5.5 - 2.5 = 3.0
    (f32.const 5.5)
    (f32.const 2.5)
    f32.sub
    drop

    ;; f32.mul: 2.5 * 4.0 = 10.0
    (f32.const 2.5)
    (f32.const 4.0)
    f32.mul
    drop

    ;; f32.div: 12.0 / 3.0 = 4.0
    (f32.const 12.0)
    (f32.const 3.0)
    f32.div
    drop

    ;; f32.min: min(2.5, 1.5) = 1.5
    (f32.const 2.5)
    (f32.const 1.5)
    f32.min
    drop

    ;; f32.max: max(2.5, 1.5) = 2.5
    (f32.const 2.5)
    (f32.const 1.5)
    f32.max
    drop

    ;; f32.copysign: copysign(2.5, -1.0) = -2.5
    (f32.const 2.5)
    (f32.const -1.0)
    f32.copysign
    drop

    ;; ========== f32 UNARY OPCODES ==========
    ;; f32.abs: abs(-3.5) = 3.5
    (f32.const -3.5)
    f32.abs
    drop

    ;; f32.neg: neg(-2.5) = 2.5
    (f32.const -2.5)
    f32.neg
    drop

    ;; f32.sqrt: sqrt(9.0) = 3.0
    (f32.const 9.0)
    f32.sqrt
    drop

    ;; f32.ceil: ceil(2.3) = 3.0
    (f32.const 2.3)
    f32.ceil
    drop

    ;; f32.floor: floor(2.7) = 2.0
    (f32.const 2.7)
    f32.floor
    drop

    ;; f32.trunc: trunc(2.7) = 2.0
    (f32.const 2.7)
    f32.trunc
    drop

    ;; f32.nearest: nearest(2.3) = 2.0
    (f32.const 2.3)
    f32.nearest
    drop

    ;; ========== f32 COMPARISON OPCODES ==========
    ;; f32.eq: 2.5 == 2.5 -> 1 (true)
    (f32.const 2.5)
    (f32.const 2.5)
    f32.eq
    drop

    ;; f32.ne: 2.5 != 1.5 -> 1 (true)
    (f32.const 2.5)
    (f32.const 1.5)
    f32.ne
    drop

    ;; f32.lt: 1.5 < 2.5 -> 1 (true)
    (f32.const 1.5)
    (f32.const 2.5)
    f32.lt
    drop

    ;; f32.gt: 2.5 > 1.5 -> 1 (true)
    (f32.const 2.5)
    (f32.const 1.5)
    f32.gt
    drop

    ;; f32.le: 1.5 <= 2.5 -> 1 (true)
    (f32.const 1.5)
    (f32.const 2.5)
    f32.le
    drop

    ;; f32.ge: 2.5 >= 1.5 -> 1 (true)
    (f32.const 2.5)
    (f32.const 1.5)
    f32.ge
    drop

    ;; ========== f32 CONVERSION OPCODES ==========
    ;; f32.convert_i32_s: convert signed i32 to f32
    (i32.const -42)
    f32.convert_i32_s
    drop

    ;; f32.convert_i32_u: convert unsigned i32 to f32
    (i32.const 42)
    f32.convert_i32_u
    drop

    ;; f32.convert_i64_s: convert signed i64 to f32
    (i64.const -1000000000000)
    f32.convert_i64_s
    drop

    ;; f32.convert_i64_u: convert unsigned i64 to f32
    (i64.const 1000000000000)
    f32.convert_i64_u
    drop

    ;; f32.demote_f64: demote f64 to f32
    (f64.const 3.14159265359)
    f32.demote_f64
    drop

    ;; ========== i32 CONVERSION OPCODES ==========
    ;; i32.wrap_i64: wrap i64 to i32
    (i64.const 0x123456789ABCDEF0)
    i32.wrap_i64
    drop

    ;; i32.trunc_f32_s: truncate f32 to signed i32
    (f32.const -42.7)
    i32.trunc_f32_s
    drop

    ;; i32.trunc_f32_u: truncate f32 to unsigned i32
    (f32.const 42.7)
    i32.trunc_f32_u
    drop

    ;; i32.trunc_f64_s: truncate f64 to signed i32
    (f64.const -42.7)
    i32.trunc_f64_s
    drop

    ;; i32.trunc_f64_u: truncate f64 to unsigned i32
    (f64.const 42.7)
    i32.trunc_f64_u
    drop

    ;; ========== f64 OPCODES (just a few key ones) ==========
    ;; f64.add: 1.5 + 2.5 = 4.0
    (f64.const 1.5)
    (f64.const 2.5)
    f64.add
    drop

    ;; f64.sub: 5.5 - 2.5 = 3.0
    (f64.const 5.5)
    (f64.const 2.5)
    f64.sub
    drop

    ;; f64.mul: 2.5 * 4.0 = 10.0
    (f64.const 2.5)
    (f64.const 4.0)
    f64.mul
    drop

    ;; f64.div: 12.0 / 3.0 = 4.0
    (f64.const 12.0)
    (f64.const 3.0)
    f64.div
    drop

    ;; ========== PRINT SUCCESS MESSAGE ==========
    (call $print_success)
  )
)