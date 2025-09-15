(module
  (func $fibonacci (param $n i32) (result i32)
    (local $a i32) (local $b i32) (local $i i32) (local $temp i32)

    ;; Handle base cases
    (if (i32.le_s (local.get $n) (i32.const 1))
      (then (return (local.get $n)))
    )

    ;; Initialize for iterative calculation
    (local.set $a (i32.const 0))
    (local.set $b (i32.const 1))
    (local.set $i (i32.const 2))

    ;; Loop to calculate fibonacci
    (loop $fib_loop
      (local.set $temp (i32.add (local.get $a) (local.get $b)))
      (local.set $a (local.get $b))
      (local.set $b (local.get $temp))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $fib_loop (i32.le_s (local.get $i) (local.get $n)))
    )

    (local.get $b)
  )

  (func $matrix_multiply (param $size i32) (result i32)
    (local $i i32) (local $j i32) (local $k i32)
    (local $sum i32) (local $product i32) (local $total i32)

    (local.set $i (i32.const 0))
    (loop $outer
      (local.set $j (i32.const 0))
      (loop $middle
        (local.set $sum (i32.const 0))
        (local.set $k (i32.const 0))
        (loop $inner
          ;; Simulate matrix multiplication with simple arithmetic
          (local.set $product (i32.mul
            (i32.add (local.get $i) (local.get $k))
            (i32.add (local.get $k) (local.get $j))
          ))
          (local.set $sum (i32.add (local.get $sum) (local.get $product)))
          (local.set $k (i32.add (local.get $k) (i32.const 1)))
          (br_if $inner (i32.lt_s (local.get $k) (local.get $size)))
        )
        (local.set $total (i32.add (local.get $total) (local.get $sum)))
        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $middle (i32.lt_s (local.get $j) (local.get $size)))
      )
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $outer (i32.lt_s (local.get $i) (local.get $size)))
    )

    (local.get $total)
  )

  (func $primes_count (param $limit i32) (result i32)
    (local $n i32) (local $count i32) (local $i i32) (local $is_prime i32)

    (local.set $n (i32.const 2))
    (local.set $count (i32.const 0))

    (loop $main_loop
      (local.set $is_prime (i32.const 1))
      (local.set $i (i32.const 2))

      ;; Check if n is prime
      (loop $check_loop
        (if (i32.eqz (i32.rem_s (local.get $n) (local.get $i)))
          (then (local.set $is_prime (i32.const 0)))
        )
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $check_loop
          (i32.and
            (local.get $is_prime)
            (i32.lt_s (i32.mul (local.get $i) (local.get $i)) (local.get $n))
          )
        )
      )

      (if (local.get $is_prime)
        (then (local.set $count (i32.add (local.get $count) (i32.const 1))))
      )

      (local.set $n (i32.add (local.get $n) (i32.const 1)))
      (br_if $main_loop (i32.le_s (local.get $n) (local.get $limit)))
    )

    (local.get $count)
  )

  (func $compute_intensive (param $iterations i32) (result i32)
    (local $i i32) (local $result i32)

    (local.set $i (i32.const 0))
    (loop $main
      ;; Mix of operations to stress different parts
      (local.set $result (i32.add (local.get $result)
        (call $fibonacci (i32.add (local.get $i) (i32.const 20)))
      ))
      (local.set $result (i32.add (local.get $result)
        (call $matrix_multiply (i32.const 8))
      ))
      (local.set $result (i32.add (local.get $result)
        (call $primes_count (i32.add (local.get $i) (i32.const 50)))
      ))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $main (i32.lt_s (local.get $i) (local.get $iterations)))
    )

    (local.get $result)
  )

  (export "compute_intensive" (func $compute_intensive))
  (export "fibonacci" (func $fibonacci))
  (export "matrix_multiply" (func $matrix_multiply))
  (export "primes_count" (func $primes_count))
)