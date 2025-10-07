(module
  ;; Import all WASI functions we support
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "args_sizes_get"
    (func $args_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "args_get"
    (func $args_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "environ_sizes_get"
    (func $environ_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "environ_get"
    (func $environ_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "fd_seek"
    (func $fd_seek (param i32 i64 i32 i32) (result i32)))
  
  ;; Memory for all operations
  (memory (export "memory") 2)
  
  ;; Data segment with test string
  (data (i32.const 1000) "Comprehensive WASI benchmark testing all features\n")
  
  ;; Helper function for fd_write
  (func $test_fd_write (param $iterations i32)
    (local $i i32)
    (local $result i32)
    
    ;; Setup IOV structure
    (i32.store (i32.const 0) (i32.const 1000))
    (i32.store (i32.const 4) (i32.const 51))
    
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        (br_if $break (i32.ge_u (local.get $i) (local.get $iterations)))
        
        (local.set $result
          (call $fd_write
            (i32.const 1)
            (i32.const 0)
            (i32.const 1)
            (i32.const 8)
          )
        )
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $continue)
      )
    )
  )
  
  ;; Helper function for args operations
  (func $test_args (param $iterations i32)
    (local $i i32)
    (local $result i32)
    
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        (br_if $break (i32.ge_u (local.get $i) (local.get $iterations)))
        
        (local.set $result
          (call $args_sizes_get (i32.const 20) (i32.const 24))
        )
        (local.set $result
          (call $args_get (i32.const 100) (i32.const 500))
        )
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $continue)
      )
    )
  )
  
  ;; Helper function for environ operations
  (func $test_environ (param $iterations i32)
    (local $i i32)
    (local $result i32)
    
    (local.set $i (i32.const 0))
    (block $break
      (loop $continue
        (br_if $break (i32.ge_u (local.get $i) (local.get $iterations)))
        
        (local.set $result
          (call $environ_sizes_get (i32.const 30) (i32.const 34))
        )
        (local.set $result
          (call $environ_get (i32.const 200) (i32.const 600))
        )
        
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $continue)
      )
    )
  )
  
  ;; Main function - comprehensive WASI test
  (func (export "_start")
    ;; Test each WASI feature multiple times
    (call $test_fd_write (i32.const 3000))
    (call $test_args (i32.const 2000))
    (call $test_environ (i32.const 2000))
    
    ;; Test fd_seek
    (drop
      (call $fd_seek
        (i32.const 1)
        (i64.const 0)
        (i32.const 0)
        (i32.const 40)
      )
    )
  )
)
