(module
  ;; Comprehensive WebAssembly benchmark testing multiple features:
  ;; - Complex arithmetic and bitwise operations
  ;; - Memory operations and data manipulation
  ;; - Function calls and recursion
  ;; - Control flow (loops, branches, conditionals)
  ;; - Local and global variable access
  ;; - Type conversions and comparisons

  ;; Global variables for state tracking
  (global $counter (mut i32) (i32.const 0))
  (global $accumulator (mut i64) (i64.const 0))

  ;; Memory for data operations (1 page = 64KB)
  (memory 1)

  ;; Fast mathematical operations function
  (func $math_ops (param $n i32) (result i32)
    (local $result i32)
    (local $temp i32)
    (local $i i32)
    
    (local.set $result (i32.const 1))
    (local.set $i (i32.const 0))
    
    ;; Complex arithmetic loop
    (loop $math_loop
      ;; result = result * (i + 3) + (i << 2) - (i & 7) + (i | 5)
      (local.set $temp 
        (i32.add 
          (i32.sub
            (i32.add
              (i32.mul 
                (local.get $result)
                (i32.add (local.get $i) (i32.const 3)))
              (i32.shl (local.get $i) (i32.const 2)))
            (i32.and (local.get $i) (i32.const 7)))
          (i32.or (local.get $i) (i32.const 5))))
      
      (local.set $result (local.get $temp))
      
      ;; Increment counter
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      
      ;; Continue if i < n
      (br_if $math_loop (i32.lt_s (local.get $i) (local.get $n)))
    )
    
    (local.get $result)
  )

  ;; Memory operations function
  (func $memory_ops (param $iterations i32) (result i32)
    (local $i i32)
    (local $addr i32)
    (local $value i32)
    (local $checksum i32)
    
    (local.set $i (i32.const 0))
    (local.set $checksum (i32.const 0))
    
    ;; Write pattern to memory
    (loop $write_loop
      (local.set $addr (i32.mul (local.get $i) (i32.const 4)))
      (local.set $value 
        (i32.add 
          (i32.mul (local.get $i) (i32.const 17))
          (i32.const 42)))
      
      ;; Store value to memory
      (i32.store (local.get $addr) (local.get $value))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $write_loop (i32.lt_s (local.get $i) (local.get $iterations)))
    )
    
    ;; Read back and compute checksum
    (local.set $i (i32.const 0))
    (loop $read_loop
      (local.set $addr (i32.mul (local.get $i) (i32.const 4)))
      (local.set $value (i32.load (local.get $addr)))
      
      ;; Add to checksum with bit manipulation
      (local.set $checksum 
        (i32.xor 
          (local.get $checksum)
          (i32.rotl (local.get $value) (i32.and (local.get $i) (i32.const 7)))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $read_loop (i32.lt_s (local.get $i) (local.get $iterations)))
    )
    
    (local.get $checksum)
  )

  ;; Recursive factorial with memoization pattern
  (func $factorial (param $n i32) (result i64)
    (local $result i64)
    
    ;; Base cases
    (if (i32.le_s (local.get $n) (i32.const 1))
      (then (return (i64.const 1)))
    )
    
    ;; For larger values, use iterative approach to avoid stack overflow
    (if (i32.gt_s (local.get $n) (i32.const 12))
      (then
        ;; Iterative factorial for large numbers
        (local.set $result (i64.const 1))
        (loop $fact_loop
          (local.set $result 
            (i64.mul (local.get $result) (i64.extend_i32_s (local.get $n))))
          (local.set $n (i32.sub (local.get $n) (i32.const 1)))
          (br_if $fact_loop (i32.gt_s (local.get $n) (i32.const 1)))
        )
        (return (local.get $result))
      )
    )
    
    ;; Recursive case for small numbers
    (i64.mul 
      (i64.extend_i32_s (local.get $n))
      (call $factorial (i32.sub (local.get $n) (i32.const 1))))
  )

  ;; Complex control flow function
  (func $control_flow (param $limit i32) (result i32)
    (local $i i32)
    (local $j i32)
    (local $result i32)
    (local $temp i32)
    
    (local.set $i (i32.const 0))
    (local.set $result (i32.const 0))
    
    ;; Nested loops with complex conditions
    (block $outer_exit
      (loop $outer_loop
        (local.set $j (i32.const 0))
        
        (block $inner_exit
          (loop $inner_loop
            ;; Complex condition with multiple branches
            (if (i32.eqz (i32.rem_s (local.get $j) (i32.const 3)))
              (then
                (local.set $temp (i32.add (local.get $i) (local.get $j)))
                (if (i32.gt_s (local.get $temp) (i32.const 50))
                  (then (br $inner_exit))
                )
                (local.set $result (i32.add (local.get $result) (local.get $temp)))
              )
              (else
                (if (i32.eqz (i32.rem_s (local.get $j) (i32.const 2)))
                  (then
                    (local.set $result 
                      (i32.sub (local.get $result) (local.get $j)))
                  )
                  (else
                    (local.set $result 
                      (i32.xor (local.get $result) (local.get $j)))
                  )
                )
              )
            )
            
            (local.set $j (i32.add (local.get $j) (i32.const 1)))
            (br_if $inner_loop (i32.lt_s (local.get $j) (i32.const 20)))
          )
        )
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br_if $outer_loop (i32.lt_s (local.get $i) (local.get $limit)))
      )
    )
    
    (local.get $result)
  )

  ;; Global state manipulation
  (func $global_ops (param $iterations i32) (result i64)
    (local $i i32)
    (local $temp i64)
    
    ;; Reset globals
    (global.set $counter (i32.const 0))
    (global.set $accumulator (i64.const 0))
    
    (local.set $i (i32.const 0))
    (loop $global_loop
      ;; Update counter
      (global.set $counter (i32.add (global.get $counter) (i32.const 1)))
      
      ;; Complex accumulator update
      (local.set $temp 
        (i64.add
          (global.get $accumulator)
          (i64.mul
            (i64.extend_i32_s (global.get $counter))
            (i64.extend_i32_s (local.get $i)))))
      
      (global.set $accumulator (local.get $temp))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $global_loop (i32.lt_s (local.get $i) (local.get $iterations)))
    )
    
    (global.get $accumulator)
  )

  ;; Type conversion and comparison intensive function
  (func $type_ops (param $n i32) (result f64)
    (local $i i32)
    (local $f32_val f32)
    (local $f64_val f64)
    (local $i64_val i64)
    
    (local.set $i (i32.const 0))
    (local.set $f64_val (f64.const 0.0))
    
    (loop $type_loop
      ;; Convert i32 to f32, do operations, convert back
      (local.set $f32_val (f32.convert_i32_s (local.get $i)))
      (local.set $f32_val (f32.mul (local.get $f32_val) (f32.const 1.5)))
      (local.set $f32_val (f32.add (local.get $f32_val) (f32.const 2.7)))
      
      ;; Convert f32 to f64 and accumulate
      (local.set $f64_val 
        (f64.add 
          (local.get $f64_val)
          (f64.promote_f32 (local.get $f32_val))))
      
      ;; i64 operations with conversions
      (local.set $i64_val (i64.extend_i32_s (local.get $i)))
      (local.set $i64_val (i64.mul (local.get $i64_val) (i64.const 7)))
      
      ;; Mix i64 and f64
      (local.set $f64_val 
        (f64.add 
          (local.get $f64_val)
          (f64.convert_i64_s (local.get $i64_val))))
      
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $type_loop (i32.lt_s (local.get $i) (local.get $n)))
    )
    
    (local.get $f64_val)
  )

  ;; Main comprehensive benchmark function
  (func $comprehensive_benchmark (result i32)
    (local $math_result i32)
    (local $memory_result i32)
    (local $factorial_result i64)
    (local $control_result i32)
    (local $global_result i64)
    (local $type_result f64)
    (local $final_result i32)
    
    ;; Run all benchmark components
    (local.set $math_result (call $math_ops (i32.const 1000)))
    (local.set $memory_result (call $memory_ops (i32.const 500)))
    (local.set $factorial_result (call $factorial (i32.const 10)))
    (local.set $control_result (call $control_flow (i32.const 25)))
    (local.set $global_result (call $global_ops (i32.const 200)))
    (local.set $type_result (call $type_ops (i32.const 100)))
    
    ;; Combine all results into final score
    (local.set $final_result 
      (i32.add
        (i32.add
          (i32.add 
            (local.get $math_result)
            (local.get $memory_result))
          (i32.add
            (i32.wrap_i64 (local.get $factorial_result))
            (local.get $control_result)))
        (i32.add
          (i32.wrap_i64 (local.get $global_result))
          (i32.trunc_f64_s (local.get $type_result)))))
    
    (local.get $final_result)
  )

  ;; Export the main benchmark function
  (export "_start" (func $comprehensive_benchmark))
)
