const Color = @import("../util/fmt/color.zig");
const Log = @import("../util/fmt.zig").Log;
const print = @import("../util/fmt.zig").print;

pub const Error = error{
    InvalidType,
};

pub const Type = enum(u8) {
    i32 = 0x7F,
    i64 = 0x7E,
    f32 = 0x7D,
    f64 = 0x7C,
    v128 = 0x7B,
    funcref = 0x70,
    externref = 0x6F,
    block = 0x40,

    pub fn fromByte(byte: u8) Error!Type {
        var o = Log.op("Type", "fromByte");
        var e = Log.err("Type", "fromByte");
        o.log("Parsing type byte: 0x{X:0>2}", .{byte});
        return switch (byte) {
            0x7F => .i32,
            0x7E => .i64,
            0x7D => .f32,
            0x7C => .f64,
            0x7B => .v128,
            0x70 => .funcref,
            0x6F => .externref,
            0x40 => .block,
            else => {
                e.log("Invalid type byte: 0x{X:0>2}", .{byte});
                return Error.InvalidType;
            },
        };
    }
};

pub const Value = union(Type) {
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
    v128: [16]u8,
    funcref: ?usize,
    externref: ?*anyopaque,
    block: void,
};
