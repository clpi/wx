# WASM4 Support in wx

## Overview

wx now supports [WASM4](https://wasm4.org/), a fantasy console for making small games with WebAssembly. This implementation provides the WASM4 API allowing you to run WASM4 cartridges in the wx runtime.

## Features

### Memory Map

The WASM4 memory layout is automatically initialized when a WASM4 module is loaded:

- `0x04-0x13`: PALETTE - 4 colors (4 x u32)
- `0x14-0x15`: DRAW_COLORS - drawing colors (u16)
- `0x16`: GAMEPAD1 - player 1 gamepad state (u8)
- `0x17`: GAMEPAD2 - player 2 gamepad state (u8)
- `0x18`: GAMEPAD3 - player 3 gamepad state (u8)
- `0x19`: GAMEPAD4 - player 4 gamepad state (u8)
- `0x1a-0x1b`: MOUSE_X - mouse X position (i16)
- `0x1c-0x1d`: MOUSE_Y - mouse Y position (i16)
- `0x1e`: MOUSE_BUTTONS - mouse button state (u8)
- `0x1f`: SYSTEM_FLAGS - system flags (u8)
- `0x20`: NETPLAY - netplay state (u8)
- `0xa0+`: FRAMEBUFFER - 160x160 display (6400 bytes, 2 bits per pixel)

### Supported API Functions

All WASM4 functions are imported from the `"env"` module:

#### Drawing Functions

- **`blit(sprite: ptr, x: i32, y: i32, width: u32, height: u32, flags: u32)`**
  - Copies pixels to the framebuffer
  - Flags: `BLIT_1BPP`, `BLIT_2BPP`, `BLIT_FLIP_X`, `BLIT_FLIP_Y`, `BLIT_ROTATE`

- **`blitSub(sprite: ptr, x: i32, y: i32, width: u32, height: u32, src_x: u32, src_y: u32, stride: u32, flags: u32)`**
  - Copies a subregion within a larger sprite atlas to the framebuffer

- **`line(x1: i32, y1: i32, x2: i32, y2: i32)`**
  - Draws a line between two points

- **`hline(x: i32, y: i32, len: u32)`**
  - Draws a horizontal line

- **`vline(x: i32, y: i32, len: u32)`**
  - Draws a vertical line

- **`oval(x: i32, y: i32, width: u32, height: u32)`**
  - Draws an oval (or circle)

- **`rect(x: i32, y: i32, width: u32, height: u32)`**
  - Draws a rectangle

- **`text(text: ptr, x: i32, y: i32)`**
  - Draws text using the built-in font

#### Audio Functions

- **`tone(frequency: u32, duration: u32, volume: u32, flags: u32)`**
  - Plays a sound tone

#### Persistent Storage

- **`diskr(dest: ptr, size: u32) -> u32`**
  - Reads from persistent storage
  - Returns number of bytes read

- **`diskw(src: ptr, size: u32) -> u32`**
  - Writes to persistent storage
  - Returns number of bytes written

#### Debug Functions

- **`trace(text: ptr)`**
  - Writes a message to the debug console

- **`tracef(format: ptr, args: ptr)`**
  - Writes a formatted message to the debug console

## Usage

### Enabling WASM4 Support

To run a WASM4 cartridge, you need to enable WASM4 support in the runtime:

```zig
const Runtime = @import("wasm/runtime.zig");

// Create runtime
var runtime = try Runtime.init(allocator);
defer runtime.deinit();

// Enable WASM4
try runtime.setupWASM4();

// Load and run your WASM4 module
var module = try runtime.loadModule(wasm_bytes);
try runtime.execute();
```

### Creating a WASM4 Cartridge

Here's a minimal WASM4 cartridge in WebAssembly Text Format (WAT):

```wat
(module
  (import "env" "rect" (func $rect (param i32 i32 i32 i32)))
  (import "env" "text" (func $text (param i32 i32 i32)))
  
  (memory 1)
  (export "memory" (memory 0))
  
  (data (i32.const 0x1000) "Hello WASM4!\00")
  
  (func $update (export "update")
    ;; Draw a rectangle
    (call $rect
      (i32.const 10)   ;; x
      (i32.const 10)   ;; y
      (i32.const 50)   ;; width
      (i32.const 30)   ;; height
    )
    
    ;; Draw text
    (call $text
      (i32.const 0x1000)  ;; text pointer
      (i32.const 5)       ;; x
      (i32.const 5)       ;; y
    )
  )
)
```

Compile with:
```bash
wat2wasm your_cartridge.wat -o your_cartridge.wasm
```

Run with wx:
```bash
wx your_cartridge.wasm
```

## Constants

### Gamepad Buttons
- `BUTTON_1 = 1`
- `BUTTON_2 = 2`
- `BUTTON_LEFT = 16`
- `BUTTON_RIGHT = 32`
- `BUTTON_UP = 64`
- `BUTTON_DOWN = 128`

### Mouse Buttons
- `MOUSE_LEFT = 1`
- `MOUSE_RIGHT = 2`
- `MOUSE_MIDDLE = 4`

### System Flags
- `SYSTEM_PRESERVE_FRAMEBUFFER = 1`
- `SYSTEM_HIDE_GAMEPAD_OVERLAY = 2`

### Blit Flags
- `BLIT_1BPP = 0` - 1 bit per pixel
- `BLIT_2BPP = 1` - 2 bits per pixel (default)
- `BLIT_FLIP_X = 2` - Flip sprite horizontally
- `BLIT_FLIP_Y = 4` - Flip sprite vertically
- `BLIT_ROTATE = 8` - Rotate sprite 90° clockwise

## Examples

See `examples/wasm4_hello.wat` for a complete example.

## Implementation Status

### Completed
- ✅ Memory map initialization
- ✅ Import function stubs for all WASM4 API functions
- ✅ Integration with runtime import handler
- ✅ Debug tracing support

### In Progress
- 🚧 Framebuffer rendering
- 🚧 Drawing primitives (rect, line, oval, etc.)
- 🚧 Sprite blitting
- 🚧 Text rendering with built-in font

### Planned
- ⏳ Audio synthesis
- ⏳ Gamepad input handling
- ⏳ Mouse input handling
- ⏳ Persistent storage (disk I/O)
- ⏳ Frame-based execution model
- ⏳ Display output (SDL2/terminal)

## Resources

- [WASM4 Official Documentation](https://wasm4.org/docs/)
- [WASM4 Memory Map](https://wasm4.org/docs/reference/memory)
- [WASM4 API Reference](https://wasm4.org/docs/reference/functions)
- [WASM4 GitHub](https://github.com/aduros/wasm4)

## License

WASM4 support in wx follows the same license as the wx project.
