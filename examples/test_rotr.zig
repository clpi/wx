const std = @import("std");

pub fn main() void {
    const val: u32 = 305419896; // 0x12345678
    const rotate: u5 = 4;

    std.debug.print("Input: {} (0x{X})\n", .{ val, val });
    std.debug.print("Rotate by: {}\n", .{rotate});

    const result = std.math.rotr(u32, val, rotate);
    std.debug.print("Result: {} (0x{X})\n", .{ result, result });

    const result_signed = @as(i32, @bitCast(result));
    std.debug.print("As signed: {}\n", .{result_signed});
    std.debug.print("Expected: -2128394905\n", .{});
    std.debug.print("Match: {}\n", .{result_signed == -2128394905});
}