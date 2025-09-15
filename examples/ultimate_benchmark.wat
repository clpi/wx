(module
  ;; Import WASI functions for I/O testing
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))

  ;; Memory for testing memory-intensive operations
  (memory (export "memory") 64)

  ;; Global variables for state testing
  (global $counter (mut i32) (i32.const 0))
  (global $accumulator (mut i64) (i64.const 0))

  ;; Ultra-intensive arithmetic benchmark - factorial with deep recursion
  (func $factorial (export "factorial") (param $n i32) (result i32)
    (if (result i32) (i32.lt_s (local.get $n) (i32.const 2))
      (then (i32.const 1))
      (else
        (i32.mul
          (local.get $n)
          (call $factorial (i32.sub (local.get $n) (i32.const 1)))
        )
      )
    )
  )

  ;; Fibonacci with memoization to test function call overhead
  (func $fibonacci (export "fibonacci") (param $n i32) (result i32)
    (local $a i32)
    (local $b i32)
    (local $temp i32)
    (local $i i32)

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

  ;; Crypto-style hash function with bitwise operations
  (func $sha256_round (export "sha256_round") (param $iterations i32) (result i32)
    (local $a i32)
    (local $b i32)
    (local $c i32)
    (local $d i32)
    (local $i i32)

    (local.set $a (i32.const 0x6a09e667))
    (local.set $b (i32.const 0xbb67ae85))
    (local.set $c (i32.const 0x3c6ef372))
    (local.set $d (i32.const 0xa54ff53a))

    (loop $hash_loop
      ;; Complex bitwise operations similar to SHA-256
      (local.set $a (i32.xor
        (local.get $a)
        (i32.rotl (local.get $b) (i32.const 7))
      ))
      (local.set $b (i32.add
        (local.get $b)
        (i32.rotr (local.get $c) (i32.const 11))
      ))
      (local.set $c (i32.and
        (local.get $c)
        (i32.shl (local.get $d) (i32.const 3))
      ))
      (local.set $d (i32.or
        (local.get $d)
        (i32.shr_u (local.get $a) (i32.const 5))
      ))

      ;; More complex transformations
      (local.set $a (i32.add (local.get $a) (i32.const 0x428a2f98)))
      (local.set $b (i32.xor (local.get $b) (i32.const 0x71374491)))
      (local.set $c (i32.mul (local.get $c) (i32.const 23)))
      (local.set $d (i32.rem_u (local.get $d) (i32.const 65537)))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $hash_loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )

    (i32.xor (i32.xor (local.get $a) (local.get $b)) (i32.xor (local.get $c) (local.get $d)))
  )

  ;; Memory-intensive operations - matrix multiplication simulation
  (func $matrix_multiply (export "matrix_multiply") (param $size i32) (result i32)
    (local $i i32)
    (local $j i32)
    (local $k i32)
    (local $sum i32)
    (local $offset_a i32)
    (local $offset_b i32)
    (local $offset_c i32)

    ;; Initialize matrices in memory
    (local.set $i (i32.const 0))
    (loop $init_loop
      (i32.store (local.get $i) (i32.add (local.get $i) (i32.const 1)))
      (i32.store
        (i32.add (i32.const 4096) (local.get $i))
        (i32.mul (local.get $i) (i32.const 2))
      )
      (local.set $i (i32.add (local.get $i) (i32.const 4)))
      (br_if $init_loop (i32.lt_u (local.get $i) (i32.mul (local.get $size) (i32.const 16))))
    )

    ;; Matrix multiplication
    (local.set $i (i32.const 0))
    (loop $outer_loop
      (local.set $j (i32.const 0))
      (loop $middle_loop
        (local.set $sum (i32.const 0))
        (local.set $k (i32.const 0))
        (loop $inner_loop
          (local.set $offset_a (i32.add
            (i32.mul (local.get $i) (local.get $size))
            (local.get $k)
          ))
          (local.set $offset_b (i32.add
            (i32.const 4096)
            (i32.add
              (i32.mul (local.get $k) (local.get $size))
              (local.get $j)
            )
          ))

          (local.set $sum (i32.add
            (local.get $sum)
            (i32.mul
              (i32.load (i32.mul (local.get $offset_a) (i32.const 4)))
              (i32.load (i32.mul (local.get $offset_b) (i32.const 4)))
            )
          ))

          (local.set $k (i32.add (local.get $k) (i32.const 1)))
          (br_if $inner_loop (i32.lt_u (local.get $k) (local.get $size)))
        )

        (local.set $offset_c (i32.add
          (i32.const 8192)
          (i32.mul
            (i32.add (i32.mul (local.get $i) (local.get $size)) (local.get $j))
            (i32.const 4)
          )
        ))
        (i32.store (local.get $offset_c) (local.get $sum))

        (local.set $j (i32.add (local.get $j) (i32.const 1)))
        (br_if $middle_loop (i32.lt_u (local.get $j) (local.get $size)))
      )
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $outer_loop (i32.lt_u (local.get $i) (local.get $size)))
    )

    (i32.load (i32.const 8192))
  )

  ;; Control flow intensive - prime number sieve
  (func $sieve_of_eratosthenes (export "sieve_of_eratosthenes") (param $limit i32) (result i32)
    (local $i i32)
    (local $j i32)
    (local $prime_count i32)
    (local $offset i32)

    ;; Initialize sieve array (1 = prime, 0 = composite)
    (local.set $i (i32.const 2))
    (loop $init_sieve
      (i32.store8 (local.get $i) (i32.const 1))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $init_sieve (i32.le_u (local.get $i) (local.get $limit)))
    )

    ;; Sieve algorithm
    (local.set $i (i32.const 2))
    (loop $sieve_loop
      (if (i32.load8_u (local.get $i))
        (then
          ;; Mark multiples as composite
          (local.set $j (i32.mul (local.get $i) (local.get $i)))
          (loop $mark_composites
            (if (i32.le_u (local.get $j) (local.get $limit))
              (then
                (i32.store8 (local.get $j) (i32.const 0))
                (local.set $j (i32.add (local.get $j) (local.get $i)))
                (br $mark_composites)
              )
            )
          )
        )
      )
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $sieve_loop (i32.le_u (i32.mul (local.get $i) (local.get $i)) (local.get $limit)))
    )

    ;; Count primes
    (local.set $i (i32.const 2))
    (local.set $prime_count (i32.const 0))
    (loop $count_primes
      (if (i32.load8_u (local.get $i))
        (then (local.set $prime_count (i32.add (local.get $prime_count) (i32.const 1))))
      )
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $count_primes (i32.le_u (local.get $i) (local.get $limit)))
    )

    (local.get $prime_count)
  )

  ;; Floating point intensive benchmark
  (func $mandelbrot (export "mandelbrot") (param $iterations i32) (result f64)
    (local $x f64)
    (local $y f64)
    (local $zx f64)
    (local $zy f64)
    (local $zx2 f64)
    (local $zy2 f64)
    (local $i i32)
    (local $escape_count i32)
    (local $px i32)
    (local $py i32)

    (local.set $py (i32.const 0))
    (loop $y_loop
      (local.set $y (f64.sub
        (f64.mul
          (f64.div (f64.convert_i32_s (local.get $py)) (f64.const 50.0))
          (f64.const 2.0)
        )
        (f64.const 1.0)
      ))

      (local.set $px (i32.const 0))
      (loop $x_loop
        (local.set $x (f64.sub
          (f64.mul
            (f64.div (f64.convert_i32_s (local.get $px)) (f64.const 50.0))
            (f64.const 2.0)
          )
          (f64.const 1.0)
        ))

        (local.set $zx (f64.const 0.0))
        (local.set $zy (f64.const 0.0))
        (local.set $i (i32.const 0))

        (loop $mandel_loop
          (local.set $zx2 (f64.mul (local.get $zx) (local.get $zx)))
          (local.set $zy2 (f64.mul (local.get $zy) (local.get $zy)))

          (if (f64.lt (f64.add (local.get $zx2) (local.get $zy2)) (f64.const 4.0))
            (then
              (local.set $zy (f64.add
                (f64.mul (f64.const 2.0) (f64.mul (local.get $zx) (local.get $zy)))
                (local.get $y)
              ))
              (local.set $zx (f64.add
                (f64.sub (local.get $zx2) (local.get $zy2))
                (local.get $x)
              ))
              (local.set $i (i32.add (local.get $i) (i32.const 1)))
              (if (i32.lt_u (local.get $i) (local.get $iterations))
                (then (br $mandel_loop))
              )
            )
          )
        )

        (if (i32.eq (local.get $i) (local.get $iterations))
          (then (local.set $escape_count (i32.add (local.get $escape_count) (i32.const 1))))
        )

        (local.set $px (i32.add (local.get $px) (i32.const 1)))
        (br_if $x_loop (i32.lt_u (local.get $px) (i32.const 100)))
      )

      (local.set $py (i32.add (local.get $py) (i32.const 1)))
      (br_if $y_loop (i32.lt_u (local.get $py) (i32.const 100)))
    )

    (f64.convert_i32_s (local.get $escape_count))
  )

  ;; Branch prediction killer - random branching
  (func $branch_torture (export "branch_torture") (param $iterations i32) (result i32)
    (local $i i32)
    (local $state i32)
    (local $result i32)
    (local $branch_count i32)

    (local.set $state (i32.const 12345))

    (loop $torture_loop
      ;; Linear congruential generator for pseudo-randomness
      (local.set $state (i32.rem_u
        (i32.add (i32.mul (local.get $state) (i32.const 1103515245)) (i32.const 12345))
        (i32.const 2147483647)
      ))

      ;; Unpredictable branching pattern
      (if (i32.rem_u (local.get $state) (i32.const 2))
        (then
          (local.set $result (i32.add (local.get $result) (i32.const 1)))
          (local.set $branch_count (i32.add (local.get $branch_count) (i32.const 1)))
          (if (i32.rem_u (local.get $state) (i32.const 3))
            (then
              (local.set $result (i32.mul (local.get $result) (i32.const 2)))
              (if (i32.rem_u (local.get $state) (i32.const 5))
                (then (local.set $result (i32.sub (local.get $result) (i32.const 3))))
                (else (local.set $result (i32.add (local.get $result) (i32.const 7))))
              )
            )
            (else
              (local.set $result (i32.xor (local.get $result) (i32.const 0xAAAA)))
            )
          )
        )
        (else
          (local.set $result (i32.sub (local.get $result) (i32.const 1)))
          (if (i32.rem_u (local.get $state) (i32.const 7))
            (then
              (local.set $result (i32.shl (local.get $result) (i32.const 1)))
              (if (i32.rem_u (local.get $state) (i32.const 11))
                (then (local.set $result (i32.or (local.get $result) (i32.const 0x5555))))
                (else (local.set $result (i32.and (local.get $result) (i32.const 0x3333))))
              )
            )
            (else
              (local.set $result (i32.rotr (local.get $result) (i32.const 3)))
            )
          )
        )
      )

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $torture_loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )

    (i32.add (local.get $result) (local.get $branch_count))
  )

  ;; Global variable stress test
  (func $global_stress (export "global_stress") (param $iterations i32) (result i64)
    (local $i i32)

    (loop $global_loop
      (global.set $counter (i32.add (global.get $counter) (i32.const 1)))
      (global.set $accumulator (i64.add
        (global.get $accumulator)
        (i64.extend_i32_s (global.get $counter))
      ))

      (if (i32.rem_u (global.get $counter) (i32.const 100))
        (then
          (global.set $accumulator (i64.mul (global.get $accumulator) (i64.const 2)))
        )
        (else
          (global.set $accumulator (i64.div_s (global.get $accumulator) (i64.const 3)))
        )
      )

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $global_loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )

    (global.get $accumulator)
  )

  ;; Combined mega-benchmark that tests everything
  (func $ultimate_benchmark (export "ultimate_benchmark") (param $scale i32) (result i32)
    (local $result i32)
    (local $temp i32)
    (local $flt_result f64)

    ;; Run all benchmarks with scaling factor
    (local.set $temp (call $factorial (i32.add (local.get $scale) (i32.const 10))))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))

    (local.set $temp (call $fibonacci (i32.mul (local.get $scale) (i32.const 5))))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))

    (local.set $temp (call $sha256_round (i32.mul (local.get $scale) (i32.const 1000))))
    (local.set $result (i32.xor (local.get $result) (local.get $temp)))

    (local.set $temp (call $matrix_multiply (i32.add (local.get $scale) (i32.const 8))))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))

    (local.set $temp (call $sieve_of_eratosthenes (i32.mul (local.get $scale) (i32.const 100))))
    (local.set $result (i32.mul (local.get $result) (local.get $temp)))

    (local.set $flt_result (call $mandelbrot (i32.add (local.get $scale) (i32.const 50))))
    (local.set $result (i32.add (local.get $result) (i32.trunc_f64_s (local.get $flt_result))))

    (local.set $temp (call $branch_torture (i32.mul (local.get $scale) (i32.const 10000))))
    (local.set $result (i32.xor (local.get $result) (local.get $temp)))

    (local.set $result (i32.add
      (local.get $result)
      (i32.wrap_i64 (call $global_stress (i32.mul (local.get $scale) (i32.const 1000))))
    ))

    (local.get $result)
  )

  ;; Simple entry point for compatibility testing
  (func $_start (export "_start")
    (drop (call $ultimate_benchmark (i32.const 1)))
  )
)