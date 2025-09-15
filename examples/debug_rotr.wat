(module
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory 1)
  (export "memory" (memory 0))
  (export "_start" (func $main))

  (func $main
    ;; Put 305419896 and 4 on stack and call rotr
    i32.const 305419896
    i32.const 4
    i32.rotr
    ;; Result should be -2128394905
    drop
  )
)