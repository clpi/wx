(module
  ;; Import WASM4 functions
  (import "env" "rect" (func $rect (param i32 i32 i32 i32)))
  (import "env" "line" (func $line (param i32 i32 i32 i32)))
  (import "env" "hline" (func $hline (param i32 i32 i32)))
  (import "env" "vline" (func $vline (param i32 i32 i32)))
  (import "env" "oval" (func $oval (param i32 i32 i32 i32)))
  (import "env" "text" (func $text (param i32 i32 i32)))
  (import "env" "trace" (func $trace (param i32)))
  
  ;; Memory (1 page = 64KB, required for WASM4)
  (memory 1)
  (export "memory" (memory 0))
  
  ;; Store test string in memory
  (data (i32.const 0x1000) "WASM4 Test!\00")
  (data (i32.const 0x1020) "Drawing primitives work!\00")
  
  ;; Update function (called every frame by WASM4)
  (func $update (export "update")
    ;; Trace message
    (call $trace (i32.const 0x1000))
    
    ;; Draw a rectangle (x=10, y=10, width=50, height=30)
    (call $rect
      (i32.const 10)
      (i32.const 10)
      (i32.const 50)
      (i32.const 30)
    )
    
    ;; Draw a line (x1=70, y1=10, x2=140, y2=50)
    (call $line
      (i32.const 70)
      (i32.const 10)
      (i32.const 140)
      (i32.const 50)
    )
    
    ;; Draw horizontal line (x=10, y=60, len=80)
    (call $hline
      (i32.const 10)
      (i32.const 60)
      (i32.const 80)
    )
    
    ;; Draw vertical line (x=100, y=60, len=50)
    (call $vline
      (i32.const 100)
      (i32.const 60)
      (i32.const 50)
    )
    
    ;; Draw an oval (x=10, y=80, width=60, height=40)
    (call $oval
      (i32.const 10)
      (i32.const 80)
      (i32.const 60)
      (i32.const 40)
    )
    
    ;; Draw text (text_ptr=0x1020, x=5, y=130)
    (call $text
      (i32.const 0x1020)
      (i32.const 5)
      (i32.const 130)
    )
  )
  
  ;; Start function (optional, called once at startup)
  (func $start (export "start")
    (call $trace (i32.const 0x1020))
  )
)
