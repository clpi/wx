(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 544) "OK\n")
  ;; Simple sequence of core ops with no branching beyond blocks/loops.
  (func $print_ok
    (i32.store (i32.const 512) (i32.const 544))
    (i32.store (i32.const 516) (i32.const 3))
    (drop (call $fd_write (i32.const 1) (i32.const 512) (i32.const 1) (i32.const 520)))
  )
  (func (export "_start")
    ;; i32 arithmetic
    (drop (i32.add (i32.const 5) (i32.const 7)))
    (drop (i32.mul (i32.const 3) (i32.const 9)))
    ;; i64 arithmetic
    (drop (i64.sub (i64.const 100) (i64.const 1)))
    ;; f32/f64 math
    (drop (f32.div (f32.const 9.0) (f32.const 2.0)))
    (drop (f64.add (f64.const 1.5) (f64.const 2.5)))
    ;; memory store/load
    (i32.store (i32.const 1024) (i32.const 0x11223344))
    (drop (i32.load (i32.const 1024)))
    ;; simple loop
    (local $n i32)
    (local $a i32)
    (local.set $n (i32.const 100))
    (local.set $a (i32.const 0))
    (block $B (loop $L
      (local.set $n (i32.sub (local.get $n) (i32.const 1)))
      (local.set $a (i32.add (local.get $a) (local.get $n)))
      (br_if $B (i32.eqz (local.get $n)))
      (br $L)
    ))
    (drop (local.get $a))
    (call $print_ok)
  )
)

