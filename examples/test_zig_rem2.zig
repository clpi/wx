const std = @import("std");

pub fn main() void {
    const a: i32 = 10;
    const b: i32 = 3;

    std.debug.print("Testing @rem({}, {})\n", .{ a, b });
    const result = @rem(a, b);
    std.debug.print("@rem({}, {}) = {}\n", .{ a, b, result });
    std.debug.print("Expected: 1, Got: {}, Match: {}\n", .{ result, result == 1 });
}