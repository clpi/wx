export const std = @import("std");
export const cmd = @import("cmd.zig");
export const rt = @import("wasm/runtime.zig");
export const op = @import("wasm/op.zig");
export const module = @import("wasm/module.zig");
export const wasi = @import("wasm/wasi.zig");
export const config = @import("cmd/config.zig");
export const jit = @import("wasm/jit.zig");
export const aot = @import("wasm/aot.zig");
export const SmallVec = @import("wasm/stack.zig").SmallVec;
export const testing = std.testing;
export const fmt = @import("util/fmt.zig");
export const value = @import("wasm/value.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
