(module
  ;; Import WASI fd_write function
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  
  ;; Memory for I/O operations
  (memory (export "memory") 1)
  
  ;; Data segment with test string
  (data (i32.const 100) "WASI fd_write benchmark - testing high-frequency output operations\n")
  
  ;; Main function - perform many fd_write operations
  (func (export "_start")
    (local $i i32)
    (local $result i32)
    (local $written i32)
    
    ;; Setup IOV structure at memory offset 0
    ;; IOV[0].buf_ptr = 100 (pointer to string)
    (i32.store (i32.const 0) (i32.const 100))
    ;; IOV[0].buf_len = 67 (length of string)
    (i32.store (i32.const 4) (i32.const 67))
    
    ;; Loop 10000 times to stress test fd_write
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        ;; Check if we've done 10000 iterations
        (br_if $break (i32.ge_u (local.get $i) (i32.const 10000)))
        
        ;; Call fd_write: fd=1 (stdout), iovs_ptr=0, iovs_len=1, written_ptr=8
        (local.set $result
          (call $fd_write
            (i32.const 1)  ;; fd (stdout)
            (i32.const 0)  ;; iovs_ptr
            (i32.const 1)  ;; iovs_len
            (i32.const 8)  ;; written_ptr
          )
        )
        
        ;; Increment counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        
        (br $continue)
      )
    )
  )
)
