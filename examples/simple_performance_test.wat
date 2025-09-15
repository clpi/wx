(module
  ;; Simple performance test that showcases JIT compilation advantages
  (func $arithmetic_intensive (export "arithmetic_intensive") (result i32)
    (local $i i32)
    (local $sum i32)
    (local $temp i32)

    ;; Simple arithmetic loop that benefits from JIT compilation
    (local.set $sum (i32.const 0))
    (local.set $i (i32.const 0))

    (loop $main_loop
      ;; Arithmetic operations that JIT can optimize well
      (local.set $temp (i32.mul (local.get $i) (i32.const 3)))
      (local.set $temp (i32.add (local.get $temp) (i32.const 42)))
      (local.set $temp (i32.xor (local.get $temp) (i32.const 0xAAAA)))
      (local.set $sum (i32.add (local.get $sum) (local.get $temp)))

      ;; Loop control
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $main_loop (i32.lt_u (local.get $i) (i32.const 1000000)))
    )

    (local.get $sum)
  )

  ;; Entry point for WASI
  (func $_start (export "_start")
    (drop (call $arithmetic_intensive))
  )
)