(module
  (func $compute (export "_start")
    (local $i i32)
    (local $j i32)
    (local $sum i32)
    (local $temp i32)

    ;; Initialize variables
    (local.set $i (i32.const 0))
    (local.set $sum (i32.const 0))

    ;; Outer loop 10000 times
    (block $exit_outer
      (loop $loop_outer
        ;; if i >= 10000 break
        (i32.ge_u (local.get $i) (i32.const 10000))
        (br_if $exit_outer)

        ;; Inner loop 100 times
        (local.set $j (i32.const 0))
        (block $exit_inner
          (loop $loop_inner
            ;; if j >= 100 break
            (i32.ge_u (local.get $j) (i32.const 100))
            (br_if $exit_inner)

            ;; Complex arithmetic operations
            (local.set $temp
              (i32.add
                (i32.mul
                  (i32.add (local.get $i) (local.get $j))
                  (i32.const 3))
                (i32.sub
                  (i32.mul (local.get $i) (i32.const 2))
                  (local.get $j))))

            (local.set $sum
              (i32.add (local.get $sum) (local.get $temp)))

            ;; Increment inner counter
            (local.set $j (i32.add (local.get $j) (i32.const 1)))

            ;; Continue inner loop
            (br $loop_inner)
          )
        )

        ;; Increment outer counter
        (local.set $i (i32.add (local.get $i) (i32.const 1)))

        ;; Continue outer loop
        (br $loop_outer)
      )
    )
  )
)