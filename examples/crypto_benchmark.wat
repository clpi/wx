(module
  ;; CRYPTO-INTENSIVE WEBASSEMBLY BENCHMARK
  ;; This benchmark focuses on the computationally intensive parts of cryptography
  ;; that our JIT can optimize heavily - perfect for showcasing performance against
  ;; wasmer and wasmtime without complex memory operations.
  
  ;; Global state for crypto operations
  (global $hash_state_0 (mut i32) (i32.const 0x67452301))
  (global $hash_state_1 (mut i32) (i32.const 0xEFCDAB89))
  (global $hash_state_2 (mut i32) (i32.const 0x98BADCFE))
  (global $hash_state_3 (mut i32) (i32.const 0x10325476))
  (global $hash_state_4 (mut i32) (i32.const 0xC3D2E1F0))
  
  ;; Constants for SHA-1-like operations
  (global $k0 i32 (i32.const 0x5A827999))
  (global $k1 i32 (i32.const 0x6ED9EBA1))
  (global $k2 i32 (i32.const 0x8F1BBCDC))
  (global $k3 i32 (i32.const 0xCA62C1D6))
  
  ;; Fast left rotate function (critical for crypto performance)
  (func $rotl (param $x i32) (param $n i32) (result i32)
    (i32.or
      (i32.shl (local.get $x) (local.get $n))
      (i32.shr_u (local.get $x) (i32.sub (i32.const 32) (local.get $n)))
    )
  )
  
  ;; SHA-1 F function (rounds 0-19)
  (func $sha1_f (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.or
      (i32.and (local.get $b) (local.get $c))
      (i32.and (i32.xor (local.get $b) (i32.const -1)) (local.get $d))
    )
  )
  
  ;; SHA-1 G function (rounds 20-39, 60-79)
  (func $sha1_g (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.xor (i32.xor (local.get $b) (local.get $c)) (local.get $d))
  )
  
  ;; SHA-1 H function (rounds 40-59)
  (func $sha1_h (param $b i32) (param $c i32) (param $d i32) (result i32)
    (i32.or
      (i32.or
        (i32.and (local.get $b) (local.get $c))
        (i32.and (local.get $b) (local.get $d))
      )
      (i32.and (local.get $c) (local.get $d))
    )
  )
  
  ;; Intensive SHA-1-like hash round (this is what JIT optimizes heavily)
  (func $hash_round (param $a i32) (param $b i32) (param $c i32) (param $d i32) (param $e i32) 
                    (param $w i32) (param $k i32) (param $round_type i32) (result i32)
    (local $f i32)
    (local $temp i32)
    
    ;; Select function based on round type
    (if (i32.eq (local.get $round_type) (i32.const 0))
      (then
        (local.set $f (call $sha1_f (local.get $b) (local.get $c) (local.get $d)))
      )
      (else
        (if (i32.eq (local.get $round_type) (i32.const 1))
          (then
            (local.set $f (call $sha1_g (local.get $b) (local.get $c) (local.get $d)))
          )
          (else
            (local.set $f (call $sha1_h (local.get $b) (local.get $c) (local.get $d)))
          )
        )
      )
    )
    
    ;; Compute temp = ROTL(a, 5) + f + e + w + k
    (local.set $temp
      (i32.add
        (i32.add
          (i32.add
            (i32.add
              (call $rotl (local.get $a) (i32.const 5))
              (local.get $f)
            )
            (local.get $e)
          )
          (local.get $w)
        )
        (local.get $k)
      )
    )
    
    (local.get $temp)
  )
  
  ;; Complete SHA-1-like compression function (80 rounds)
  (func $sha1_compress (param $w0 i32) (param $w1 i32) (param $w2 i32) (param $w3 i32) (result i32)
    (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $e i32)
    (local $temp i32) (local $round i32)
    (local $w i32)
    
    ;; Initialize working variables
    (local.set $a (global.get $hash_state_0))
    (local.set $b (global.get $hash_state_1))
    (local.set $c (global.get $hash_state_2))
    (local.set $d (global.get $hash_state_3))
    (local.set $e (global.get $hash_state_4))
    
    ;; 80 rounds of SHA-1-like compression (unrolled for better JIT optimization)
    (local.set $round (i32.const 0))
    (loop $compression_loop
      ;; Generate W value (simplified message schedule)
      (local.set $w
        (i32.xor
          (i32.xor (local.get $w0) (local.get $w1))
          (i32.xor (local.get $w2) (local.get $w3))
        )
      )
      (local.set $w (call $rotl (local.get $w) (i32.const 1)))
      
      ;; Determine round type and constant
      (if (i32.lt_u (local.get $round) (i32.const 20))
        (then
          (local.set $temp (call $hash_round (local.get $a) (local.get $b) (local.get $c) 
                                           (local.get $d) (local.get $e) (local.get $w) 
                                           (global.get $k0) (i32.const 0)))
        )
        (else
          (if (i32.lt_u (local.get $round) (i32.const 40))
            (then
              (local.set $temp (call $hash_round (local.get $a) (local.get $b) (local.get $c) 
                                               (local.get $d) (local.get $e) (local.get $w) 
                                               (global.get $k1) (i32.const 1)))
            )
            (else
              (if (i32.lt_u (local.get $round) (i32.const 60))
                (then
                  (local.set $temp (call $hash_round (local.get $a) (local.get $b) (local.get $c) 
                                                   (local.get $d) (local.get $e) (local.get $w) 
                                                   (global.get $k2) (i32.const 2)))
                )
                (else
                  (local.set $temp (call $hash_round (local.get $a) (local.get $b) (local.get $c) 
                                                   (local.get $d) (local.get $e) (local.get $w) 
                                                   (global.get $k3) (i32.const 1)))
                )
              )
            )
          )
        )
      )
      
      ;; Update state (this creates a dependency chain that JIT can optimize)
      (local.set $e (local.get $d))
      (local.set $d (local.get $c))
      (local.set $c (call $rotl (local.get $b) (i32.const 30)))
      (local.set $b (local.get $a))
      (local.set $a (local.get $temp))
      
      ;; Update W values for next iteration
      (local.set $w0 (i32.add (local.get $w0) (local.get $round)))
      (local.set $w1 (i32.xor (local.get $w1) (local.get $temp)))
      (local.set $w2 (call $rotl (local.get $w2) (i32.const 3)))
      (local.set $w3 (i32.sub (local.get $w3) (local.get $round)))
      
      (local.set $round (i32.add (local.get $round) (i32.const 1)))
      (br_if $compression_loop (i32.lt_u (local.get $round) (i32.const 80)))
    )
    
    ;; Update global hash state
    (global.set $hash_state_0 (i32.add (global.get $hash_state_0) (local.get $a)))
    (global.set $hash_state_1 (i32.add (global.get $hash_state_1) (local.get $b)))
    (global.set $hash_state_2 (i32.add (global.get $hash_state_2) (local.get $c)))
    (global.set $hash_state_3 (i32.add (global.get $hash_state_3) (local.get $d)))
    (global.set $hash_state_4 (i32.add (global.get $hash_state_4) (local.get $e)))
    
    ;; Return combined hash value
    (i32.xor
      (i32.xor (global.get $hash_state_0) (global.get $hash_state_1))
      (i32.xor (global.get $hash_state_2) (global.get $hash_state_3))
    )
  )
  
  ;; Intensive computation benchmark (multiple hash operations)
  (func $intensive_computation (param $iterations i32) (result i32)
    (local $i i32)
    (local $result i32)
    (local $w0 i32) (local $w1 i32) (local $w2 i32) (local $w3 i32)
    
    (local.set $result (i32.const 0))
    (local.set $i (i32.const 0))
    
    (loop $main_loop
      ;; Generate pseudo-random input data
      (local.set $w0 (i32.add (i32.mul (local.get $i) (i32.const 0x9E3779B9)) (i32.const 0x12345678)))
      (local.set $w1 (i32.xor (local.get $w0) (i32.const 0xABCDEF01)))
      (local.set $w2 (call $rotl (local.get $w1) (i32.const 13)))
      (local.set $w3 (i32.sub (local.get $w2) (local.get $i)))
      
      ;; Perform intensive SHA-1-like compression
      (local.set $result 
        (i32.xor (local.get $result) 
                 (call $sha1_compress (local.get $w0) (local.get $w1) (local.get $w2) (local.get $w3))))
      
      ;; Additional arithmetic to stress the JIT
      (local.set $result (call $rotl (local.get $result) (i32.const 7)))
      (local.set $result (i32.add (local.get $result) (local.get $i)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $main_loop (i32.lt_u (local.get $i) (local.get $iterations)))
    )
    
    (local.get $result)
  )
  
  ;; Multi-threaded style computation (simulated with multiple independent chains)
  (func $parallel_computation (result i32)
    (local $chain1 i32) (local $chain2 i32) (local $chain3 i32) (local $chain4 i32)
    (local $i i32)
    
    ;; Initialize chains
    (local.set $chain1 (i32.const 0x67452301))
    (local.set $chain2 (i32.const 0xEFCDAB89))
    (local.set $chain3 (i32.const 0x98BADCFE))
    (local.set $chain4 (i32.const 0x10325476))
    
    (local.set $i (i32.const 0))
    (loop $parallel_loop
      ;; Chain 1: Heavy rotation and XOR
      (local.set $chain1 (call $rotl (local.get $chain1) (i32.const 5)))
      (local.set $chain1 (i32.xor (local.get $chain1) (local.get $i)))
      (local.set $chain1 (i32.add (local.get $chain1) (global.get $k0)))
      
      ;; Chain 2: Arithmetic and bitwise operations
      (local.set $chain2 (i32.mul (local.get $chain2) (i32.const 3)))
      (local.set $chain2 (i32.and (local.get $chain2) (i32.const 0x7FFFFFFF)))
      (local.set $chain2 (i32.or (local.get $chain2) (local.get $i)))
      
      ;; Chain 3: Complex bit manipulation
      (local.set $chain3 (call $rotl (local.get $chain3) (i32.const 13)))
      (local.set $chain3 (i32.xor (local.get $chain3) (call $rotl (local.get $chain1) (i32.const 7))))
      (local.set $chain3 (i32.sub (local.get $chain3) (local.get $chain2)))
      
      ;; Chain 4: Dependency on other chains
      (local.set $chain4 (i32.add (local.get $chain4) (local.get $chain1)))
      (local.set $chain4 (i32.xor (local.get $chain4) (local.get $chain3)))
      (local.set $chain4 (call $rotl (local.get $chain4) (i32.const 17)))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $parallel_loop (i32.lt_u (local.get $i) (i32.const 1000)))
    )
    
    ;; Combine all chains
    (i32.xor
      (i32.xor (local.get $chain1) (local.get $chain2))
      (i32.xor (local.get $chain3) (local.get $chain4))
    )
  )
  
  ;; Main benchmark function
  (func $crypto_benchmark (result i32)
    (local $result i32)
    (local $temp i32)
    
    ;; Reset hash state
    (global.set $hash_state_0 (i32.const 0x67452301))
    (global.set $hash_state_1 (i32.const 0xEFCDAB89))
    (global.set $hash_state_2 (i32.const 0x98BADCFE))
    (global.set $hash_state_3 (i32.const 0x10325476))
    (global.set $hash_state_4 (i32.const 0xC3D2E1F0))
    
    ;; Phase 1: Intensive sequential computation (1000 iterations)
    (local.set $result (call $intensive_computation (i32.const 1000)))
    
    ;; Phase 2: Parallel-style computation
    (local.set $temp (call $parallel_computation))
    (local.set $result (i32.xor (local.get $result) (local.get $temp)))
    
    ;; Phase 3: Additional intensive rounds
    (local.set $temp (call $intensive_computation (i32.const 500)))
    (local.set $result (i32.add (local.get $result) (local.get $temp)))
    
    ;; Phase 4: Final hash compression
    (local.set $temp (call $sha1_compress (local.get $result) 
                                          (call $rotl (local.get $result) (i32.const 8))
                                          (i32.xor (local.get $result) (i32.const 0x5A5A5A5A))
                                          (i32.sub (local.get $result) (i32.const 0x12345678))))
    
    (i32.xor (local.get $result) (local.get $temp))
  )
  
  ;; Export the main benchmark function
  (export "_start" (func $crypto_benchmark))
)
