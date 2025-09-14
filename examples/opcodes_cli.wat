(module
  ;; WASI imports
  (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "args_sizes_get" (func $args_sizes_get (param i32 i32) (result i32)))
  (import "wasi_snapshot_preview1" "args_get" (func $args_get (param i32 i32) (result i32)))

  (memory (export "memory") 2)

  ;; simple iovec at 512; write buffer starts at 544
  (data (i32.const 544) "OK\n")
  (data (i32.const 560) "Usage: opcodes-cli <cmd>\n")
  (data (i32.const 592) "i32.add|i64.add|f32.add|f64.mul|mem|loop|select|locals\n")
  (data (i32.const 704) "i32.add")
  (data (i32.const 720) "i64.add")
  (data (i32.const 736) "f32.add")
  (data (i32.const 752) "f64.mul")
  (data (i32.const 768) "mem")
  (data (i32.const 784) "loop")
  (data (i32.const 800) "select")
  (data (i32.const 816) "locals")

  (func $print (param $ptr i32) (param $len i32)
    (i32.store (i32.const 512) (local.get $ptr))
    (i32.store (i32.const 516) (local.get $len))
    (drop
      (call $fd_write
        (i32.const 1)
        (i32.const 512)
        (i32.const 1)
        (i32.const 520)
      )
    )
  )

  (func $str_eq (param $a i32) (param $alen i32) (param $b i32) (param $blen i32) (result i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    (if (result i32) (i32.ne (local.get $alen) (local.get $blen))
      (then (return (i32.const 0)))
    )
    (block $exit
      (loop $loop
        (br_if $exit (i32.ge_u (local.get $i) (local.get $alen)))
        (br_if $exit
          (i32.ne
            (i32.load8_u (i32.add (local.get $a) (local.get $i)))
            (i32.load8_u (i32.add (local.get $b) (local.get $i)))
          )
        )
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $loop)
      )
    )
    (i32.eq (local.get $i) (local.get $alen))
  )

  (func (export "_start")
    (local $argc i32)
    (local $argv_buf_sz i32)
    (local $argv i32)
    (local $argv_buf i32)
    (local $arg1_ptr i32)
    (local $arg1_len i32)

    ;; fetch args sizes
    (call $args_sizes_get (i32.const 0) (i32.const 4))
    drop
    (local.set $argc (i32.load (i32.const 0)))
    (local.set $argv_buf_sz (i32.load (i32.const 4)))

    ;; allocate argv pointers (argc * 4) at 1024 and argv_buf at 2048
    (local.set $argv (i32.const 1024))
    (local.set $argv_buf (i32.const 2048))
    (drop (call $args_get (local.get $argv) (local.get $argv_buf)))

    ;; need at least 2 args: prog and cmd
    (if (i32.lt_u (local.get $argc) (i32.const 2))
      (then
        (call $print (i32.const 560) (i32.const 24))
        (call $print (i32.const 592) (i32.const 64))
        (return)
      )
    )

    ;; argv[1]
    (local.set $arg1_ptr (i32.load (i32.add (local.get $argv) (i32.const 4))))
    ;; compute length up to NUL
    (local.set $arg1_len (i32.const 0))
    (block $exit
      (loop $L
        (br_if $exit (i32.eqz (i32.load8_u (i32.add (local.get $arg1_ptr) (local.get $arg1_len)))))
        (local.set $arg1_len (i32.add (local.get $arg1_len) (i32.const 1)))
        (br $L)
      )
    )

    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 704) (i32.const 7))
      (then
        ;; i32.add
        (drop (i32.add (i32.const 5) (i32.const 3)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )
    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 720) (i32.const 7))
      (then
        ;; i64.add
        (drop (i64.add (i64.const 9) (i64.const 33)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )
    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 736) (i32.const 7))
      (then
        ;; f32.add
        (drop (f32.add (f32.const 3.5) (f32.const 1.25)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )
    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 752) (i32.const 7))
      (then
        ;; f64.mul
        (drop (f64.mul (f64.const 2.0) (f64.const 8.0)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )

    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 768) (i32.const 3))
      (then
        ;; memory store/load
        (i32.store (i32.const 4096) (i32.const 0x11223344))
        (drop (i32.load (i32.const 4096)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )

    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 784) (i32.const 4))
      (then
        ;; loop with br_if
        (local $n i32)
        (local $acc i32)
        (local.set $n (i32.const 1000))
        (local.set $acc (i32.const 0))
        (block $B (loop $L
          (br_if $B (i32.eqz (local.get $n)))
          (local.set $n (i32.sub (local.get $n) (i32.const 1)))
          (local.set $acc (i32.add (local.get $acc) (local.get $n)))
          (br $L)
        ))
        (drop (local.get $acc))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )

    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 800) (i32.const 6))
      (then
        ;; select
        (drop (select (i32.const 1) (i32.const 2) (i32.const 1)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )

    (if (call $str_eq (local.get $arg1_ptr) (local.get $arg1_len) (i32.const 816) (i32.const 6))
      (then
        ;; locals get/set/tee
        (local $x i32)
        (local $y i32)
        (local.set $x (i32.const 3))
        (local.set $y (local.get $x))
        (local.set $y (i32.add (local.get $y) (i32.const 5)))
        (drop (i32.add (local.get $x) (local.get $y)))
        (call $print (i32.const 544) (i32.const 3))
        (return)
      )
    )

    (call $print (i32.const 560) (i32.const 24))
    (call $print (i32.const 592) (i32.const 64))
  )
)

