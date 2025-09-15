(module
  ;; SIMPLE CRYPTO BENCHMARK - NO FUNCTION CALLS
  ;; This benchmark is designed to trigger wx's register-based execution
  ;; and should be significantly faster than the complex crypto benchmark

  ;; Main benchmark function - 1 million rounds of inline crypto operations
  (func $run_simple_crypto_benchmark (result i32)
    (local $i i32)
    (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $e i32)
    (local $temp i32) (local $f i32)

    ;; Initialize crypto state (SHA-1 initial values)
    (local.set $a (i32.const 0x67452301))
    (local.set $b (i32.const 0xEFCDAB89))
    (local.set $c (i32.const 0x98BADCFE))
    (local.set $d (i32.const 0x10325476))
    (local.set $e (i32.const 0xC3D2E1F0))

    (local.set $i (i32.const 0))

    ;; Main crypto loop - 1 million iterations of intensive crypto operations
    (loop $main_loop
      ;; Inline rotate left operation: ROTL(a, 5)
      (local.set $temp
        (i32.or
          (i32.shl (local.get $a) (i32.const 5))
          (i32.shr_u (local.get $a) (i32.const 27))
        )
      )

      ;; Inline F function: (b & c) | (~b & d)
      (local.set $f
        (i32.or
          (i32.and (local.get $b) (local.get $c))
          (i32.and
            (i32.xor (local.get $b) (i32.const 0xFFFFFFFF))
            (local.get $d)
          )
        )
      )

      ;; temp = ROTL(a, 5) + f + e + 0x5A827999
      (local.set $temp
        (i32.add
          (i32.add
            (i32.add (local.get $temp) (local.get $f))
            (local.get $e)
          )
          (i32.const 0x5A827999)
        )
      )

      ;; Update state variables (SHA-1 style)
      (local.set $e (local.get $d))
      (local.set $d (local.get $c))
      
      ;; c = ROTL(b, 30)
      (local.set $c
        (i32.or
          (i32.shl (local.get $b) (i32.const 30))
          (i32.shr_u (local.get $b) (i32.const 2))
        )
      )
      
      (local.set $b (local.get $a))
      (local.set $a (local.get $temp))

      ;; Additional crypto mixing operations
      (local.set $a (i32.xor (local.get $a) (local.get $i)))
      (local.set $b (i32.rotl (local.get $b) (i32.const 7)))
      (local.set $c (i32.xor (local.get $c) (local.get $a)))
      (local.set $d (i32.rotr (local.get $d) (i32.const 11)))
      (local.set $e (i32.add (local.get $e) (local.get $b)))

      ;; Increment counter
      (local.set $i (i32.add (local.get $i) (i32.const 1)))

      ;; Continue loop if i < 1000000
      (br_if $main_loop (i32.lt_s (local.get $i) (i32.const 1000000)))
    )

    ;; Return final hash state (combination of all variables)
    (i32.add
      (i32.add
        (i32.add (local.get $a) (local.get $b))
        (i32.add (local.get $c) (local.get $d))
      )
      (local.get $e)
    )
  )

  (export "_start" (func $run_simple_crypto_benchmark))
)
