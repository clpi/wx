const std = @import("std");

pub const reset = "\x1b[0m";
pub const red = "\x1b[31m";
pub const green = "\x1b[32m";
pub const yellow = "\x1b[33m";
pub const blue = "\x1b[34m";
pub const magenta = "\x1b[35m";
pub const cyan = "\x1b[36m";
pub const white = "\x1b[37m";
pub const bold = "\x1b[1m";
pub const dim = "\x1b[2m";
pub const italic = "\x1b[3m";
pub const underline = "\x1b[4m";
pub const blink = "\x1b[5m";
pub const inverse = "\x1b[7m";
pub const strike = "\x1b[9m";
pub const bg_black = "\x1b[40m";
pub const bg_red = "\x1b[41m";
pub const bg_green = "\x1b[42m";
pub const bg_yellow = "\x1b[43m";
pub const bg_blue = "\x1b[44m";
pub const bg_magenta = "\x1b[45m";
pub const bg_cyan = "\x1b[46m";
pub const bg_white = "\x1b[47m";

pub const Colors = enum(u8) {
    reset = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
};

pub const Position = enum(u8) {
    fg = 3,
    bg = 4,
};

pub const Col = union(enum) {
    bg: Colors,
    fg: Colors,
};

pub fn format(comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(std.heap.page_allocator, fmt, args) catch "Error formatting string";
}

pub fn print(comptime fmt: []const u8, args: anytype, color: []const u8) void {
    var buf: [1024]u8 = undefined;
    const printed = std.fmt.bufPrint(buf[0..], fmt, args) catch "Error formatting string";
    std.debug.print("{s}{s}{s}\n", .{ color, printed, reset });
}
