(module
  ;; Import WASI functions for argument handling
  (import "wasi_snapshot_preview1" "args_sizes_get"
    (func $args_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "args_get"
    (func $args_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  
  ;; Memory for arguments
  (memory (export "memory") 2)
  
  ;; Main function - test argument retrieval performance
  (func (export "_start")
    (local $i i32)
    (local $argc i32)
    (local $argv_buf_size i32)
    (local $result i32)
    
    ;; Loop 5000 times to stress test args operations
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        (br_if $break (i32.ge_u (local.get $i) (i32.const 5000)))
        
        ;; Call args_sizes_get to get argument count and buffer size
        (local.set $result
          (call $args_sizes_get
            (i32.const 0)      ;; argc_ptr
            (i32.const 4)      ;; argv_buf_size_ptr
          )
        )
        
        ;; Load argc and argv_buf_size
        (local.set $argc (i32.load (i32.const 0)))
        (local.set $argv_buf_size (i32.load (i32.const 4)))
        
        ;; Call args_get to retrieve actual arguments
        (local.set $result
          (call $args_get
            (i32.const 100)    ;; argv_ptr
            (i32.const 500)    ;; argv_buf_ptr
          )
        )
        
        ;; Increment counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        
        (br $continue)
      )
    )
  )
)
