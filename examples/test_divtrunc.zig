const std = @import("std");

pub fn main() void {
    const a: i32 = 10;
    const b: i32 = 3;

    std.debug.print("Testing divTrunc and remainder calculation\n", .{});
    std.debug.print("a = {d}, b = {d}\n", .{ a, b });

    const q = @divTrunc(a, b);
    std.debug.print("@divTrunc({d}, {d}) = {d}\n", .{ a, b, q });

    const remainder = a - q * b;
    std.debug.print("remainder = {d} - ({d} * {d}) = {d} - {d} = {d}\n", .{ a, q, b, a, q * b, remainder });

    const expected = 1;
    std.debug.print("Expected: {d}, Got: {d}, Match: {}\n", .{ expected, remainder, remainder == expected });
}