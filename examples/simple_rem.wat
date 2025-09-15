(module
  (export "_start" (func $main))

  (func $main
    ;; Simple rem_s operation: 10 % 3
    i32.const 10
    i32.const 3
    i32.rem_s
    drop
  )
)