(module
  ;; Import WASI functions for environment variable handling
  (import "wasi_snapshot_preview1" "environ_sizes_get"
    (func $environ_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "environ_get"
    (func $environ_get (param i32 i32) (result i32)))
  
  ;; Memory for environment variables
  (memory (export "memory") 2)
  
  ;; Main function - test environment variable operations
  (func (export "_start")
    (local $i i32)
    (local $result i32)
    
    ;; Loop 8000 times to stress test environ operations
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        (br_if $break (i32.ge_u (local.get $i) (i32.const 8000)))
        
        ;; Call environ_sizes_get
        (local.set $result
          (call $environ_sizes_get
            (i32.const 0)      ;; environ_count_ptr
            (i32.const 4)      ;; environ_buf_size_ptr
          )
        )
        
        ;; Call environ_get
        (local.set $result
          (call $environ_get
            (i32.const 100)    ;; environ_ptr
            (i32.const 500)    ;; environ_buf_ptr
          )
        )
        
        ;; Increment counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        
        (br $continue)
      )
    )
  )
)
