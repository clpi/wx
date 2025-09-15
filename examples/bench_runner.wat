(module
  (import "env" "print_i32" (func $print_i32 (param i32)))

  (func $fibonacci (param $n i32) (result i32)
    (local $a i32) (local $b i32) (local $i i32) (local $temp i32)

    (if (i32.le_s (local.get $n) (i32.const 1))
      (then (return (local.get $n)))
    )

    (local.set $a (i32.const 0))
    (local.set $b (i32.const 1))
    (local.set $i (i32.const 2))

    (loop $fib_loop
      (local.set $temp (i32.add (local.get $a) (local.get $b)))
      (local.set $a (local.get $b))
      (local.set $b (local.get $temp))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $fib_loop (i32.le_s (local.get $i) (local.get $n)))
    )

    (local.get $b)
  )

  (func $compute_loop (param $iterations i32) (result i32)
    (local $i i32) (local $result i32) (local $temp i32)

    (local.set $i (i32.const 0))
    (loop $main
      ;; Complex arithmetic to stress the interpreter
      (local.set $temp (call $fibonacci (i32.add (local.get $i) (i32.const 15))))
      (local.set $result (i32.add (local.get $result) (local.get $temp)))

      ;; More arithmetic
      (local.set $temp (i32.mul (local.get $i) (local.get $i)))
      (local.set $temp (i32.add (local.get $temp) (local.get $i)))
      (local.set $result (i32.add (local.get $result) (local.get $temp)))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $main (i32.lt_s (local.get $i) (local.get $iterations)))
    )

    (local.get $result)
  )

  (func $start
    (local $result i32)
    (local.set $result (call $compute_loop (i32.const 1000)))
    (call $print_i32 (local.get $result))
  )

  (export "_start" (func $start))
)