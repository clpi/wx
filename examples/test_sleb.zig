const std = @import("std");

fn decodeSLEB32(bytes: []const u8) i32 {
    var result: u32 = 0;
    var shift: u8 = 0;
    var byte: u8 = 0;

    for (bytes) |b| {
        byte = b;
        const low = @as(u32, byte & 0x7F);
        result |= (low << @as(u5, @intCast(shift)));
        shift += 7;
        if (byte & 0x80 == 0) break;
    }

    // sign extend if needed
    if (shift < 32 and (byte & 0x40) != 0) {
        result |= (@as(u32, 0xFFFFFFFF) << @as(u5, @intCast(shift)));
    }

    return @as(i32, @bitCast(result));
}

pub fn main() void {
    const bytes = [_]u8{ 0xe7, 0x8a, 0x8d, 0x89, 0x78 };
    const result = decodeSLEB32(&bytes);

    std.debug.print("Bytes: ", .{});
    for (bytes) |b| {
        std.debug.print("0x{x:0>2} ", .{b});
    }
    std.debug.print("\n", .{});
    std.debug.print("Decoded: {d}\n", .{result});
    std.debug.print("Expected: -2128394905\n", .{});
    std.debug.print("Match: {}\n", .{result == -2128394905});
    std.debug.print("As hex: 0x{x:0>8}\n", .{@as(u32, @bitCast(result))});
}