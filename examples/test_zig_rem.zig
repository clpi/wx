const std = @import("std");

pub fn main() void {
    const a: i32 = 10;
    const b: i32 = 3;

    std.debug.print("Testing a={}, b={}\n", .{ a, b });

    const q = @divTrunc(a, b);
    const result = a - q * b;

    std.debug.print("@divTrunc({}, {}) = {}\n", .{ a, b, q });
    std.debug.print("result = {} - {} * {} = {}\n", .{ a, q, b, result });
    std.debug.print("Expected: 1, Got: {}, Match: {}\n", .{ result, result == 1 });
}