# WASM4 Examples

This directory contains example WASM4 cartridges demonstrating the WASM4 API implementation in wx.

## wasm4_test.wat

A comprehensive test of WASM4 drawing primitives including:
- Rectangle drawing
- Line drawing (diagonal, horizontal, vertical)
- Oval/circle drawing
- Text rendering
- Debug tracing

### Building

Compile the WAT file to WASM using wat2wasm (from WABT):

```bash
wat2wasm wasm4_test.wat -o wasm4_test.wasm
```

### Running

Run the compiled WASM module with wx runtime:

```bash
wx wasm4_test.wasm
```

## Creating Your Own WASM4 Cartridges

To create a WASM4 cartridge:

1. Import WASM4 functions from the `"env"` module
2. Export a 1-page memory (64KB)
3. Implement an `update` function that draws each frame
4. Optionally implement a `start` function for initialization

### Available Functions

See the main [WASM4.md](../WASM4.md) for full API documentation.

### Memory Layout

The WASM4 memory map is automatically initialized:
- `0x04`: PALETTE (4 colors)
- `0x14`: DRAW_COLORS
- `0x16-0x19`: GAMEPAD1-4
- `0x1a-0x1d`: MOUSE_X, MOUSE_Y
- `0x1e`: MOUSE_BUTTONS
- `0x1f`: SYSTEM_FLAGS
- `0xa0+`: FRAMEBUFFER (160x160, 2bpp)

Your cartridge data should start at higher addresses (e.g., 0x1000+) to avoid conflicts.
