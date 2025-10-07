(module
  ;; WASM4 hello world example
  ;; Memory map:
  ;; 0x04-0x13: PALETTE (4 x u32)
  ;; 0x14-0x15: DRAW_COLORS (u16)
  ;; 0x16-0x19: GAMEPAD1-4 (4 x u8)
  ;; 0xa0+: FRAMEBUFFER
  
  (import "env" "rect" (func $rect (param i32 i32 i32 i32)))
  (import "env" "text" (func $text (param i32 i32 i32)))
  (import "env" "trace" (func $trace (param i32)))
  
  (memory 1)
  (export "memory" (memory 0))
  
  ;; Store hello message at address 0x1000
  (data (i32.const 0x1000) "Hello WASM4!\00")
  (data (i32.const 0x1100) "WASM4 Initialized\00")
  
  (func $start (export "start")
    ;; Trace initialization message
    (call $trace (i32.const 0x1100))
    
    ;; Set draw colors: 0x1234 means:
    ;; Stroke: color 4, Fill: color 3, Pattern: colors 2,1
    i32.const 0x14  ;; DRAW_COLORS address
    i32.const 0x1234
    i32.store16
    
    ;; Draw a rectangle at (10, 10) with size (50, 30)
    (call $rect
      (i32.const 10)   ;; x
      (i32.const 10)   ;; y
      (i32.const 50)   ;; width
      (i32.const 30)   ;; height
    )
    
    ;; Draw text "Hello WASM4!" at (5, 5)
    (call $text
      (i32.const 0x1000)  ;; text pointer
      (i32.const 5)       ;; x
      (i32.const 5)       ;; y
    )
  )
  
  (func $update (export "update")
    ;; Game update function called every frame
    ;; For now, just draw the hello message again
    (call $text
      (i32.const 0x1000)
      (i32.const 10)
      (i32.const 50)
    )
  )
)
