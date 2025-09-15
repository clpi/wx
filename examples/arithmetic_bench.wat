(module
  (func $compute (export "_start")
    (local $i i32)
    (local $sum i32)
    (local $temp i32)

    ;; Initialize variables
    (local.set $i (i32.const 0))
    (local.set $sum (i32.const 0))

    ;; Loop 1000000 times
    (block $exit
      (loop $loop
        ;; if i >= 1000000 break
        (i32.ge_u (local.get $i) (i32.const 1000000))
        (br_if $exit)

        ;; Arithmetic operations
        (local.set $temp
          (i32.add
            (i32.mul (local.get $i) (i32.const 3))
            (i32.const 42)))

        (local.set $sum
          (i32.add (local.get $sum) (local.get $temp)))

        ;; Increment counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))

        ;; Continue loop
        (br $loop)
      )
    )
  )
)