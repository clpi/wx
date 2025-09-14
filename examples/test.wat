(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)
  (data (i32.const 0) "Hello, WebAssembly!\n")
  
  (func (export "_start")
    ;; Create iovec structure at offset 100
    (i32.store (i32.const 100) (i32.const 0))    ;; iov_base = 0 (start of string)
    (i32.store (i32.const 104) (i32.const 20))   ;; iov_len = 20 (length of string)
    
    ;; Call fd_write(stdout, iovs, iovs_len, nwritten)
    (call $fd_write
      (i32.const 1)   ;; fd = stdout
      (i32.const 100) ;; iovs pointer  
      (i32.const 1)   ;; iovs_len = 1
      (i32.const 108) ;; nwritten pointer
    )
    drop ;; ignore return value
  )
)