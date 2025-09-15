const std = @import("std");
const cmd = @import("cmd.zig");
const rt = @import("wasm/runtime.zig");
const op = @import("wasm/op.zig");
const module = @import("wasm/module.zig");
const wasi = @import("wasm/wasi.zig");
const config = @import("cmd/config.zig");
const testing = std.testing;
const fmt = @import("util/fmt.zig");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}
