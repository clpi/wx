const std = @import("std");

pub fn assertByte(byte: u8, expected: Op) !void {
    const o = Op.match(byte).?;
    std.debug.print("byte: {x} {} {}\n", .{ byte, o, expected });
    try std.testing.expectEqual(expected, o);
}

pub const Error = error{
    StackUnderflow,
    StackOverflow,
    OutOfMemory,
    InvalidOpcode,
    TypeMismatch,
    UnknownImport,
    InvalidAccess,
    DivideByZero,
    MemoryGrowLimitReached,
};

pub const Op = union(@import("op/type.zig").OpType) {
    control: Control,
    memory: Memory,
    throw: Throw,
    i32: I32,
    i64: I64,
    f32: F32,
    f64: F64,
    @"return": Return,
    call: Call,
    table: Table,
    branch: Branch,
    ref: Ref,
    local: Local,
    global: Global,

    pub fn match(o: u8) ?Op {
        return switch (o) {
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x0B, 0x40 => .{ .control = .match(o) },
            0x06, 0x07, 0x08, 0x09, 0x0A, 0x19 => .{ .throw = .match(o) },
            0x0C, 0x0D, 0x0E, 0xD4, 0xD6 => .{ .branch = .match(o) },
            0x0F, 0x12, 0x13, 0x15 => .{ .@"return" = .match(o) },
            0x10, 0x11, 0x14, 0x18, 0x1A, 0x1B, 0x1C => .{ .call = .match(o) },
            0x20, 0x21, 0x22 => .{ .local = .match(o) },
            0x23, 0x24 => .{ .global = .match(o) },
            0x25, 0x26, 0x1F => .{ .table = .match(o) },
            0x3F, 0xFC => .{ .memory = .match(o) },
            0x28,
            0x3A,
            0x3B,
            0x41,
            0x42,
            0x43,
            0x45,
            0x46,
            0x47,
            0x48,
            0x49,
            0x4A,
            0x4B,
            0x4C,
            0x4D,
            0x4E,
            0x4F,
            0x50,
            0xA7,
            0xA8,
            0xA9,
            0xAA,
            0xAB,
            0xAE,
            0xAF,
            0xB0,
            0xB1,
            0xB2,
            0xB3,
            0xB4,
            0x6A,
            0xB5,
            0xB6,
            0xB7,
            0xB8,
            0xB9,
            0xBA,
            0xBB,
            0xBC,
            0xBD,
            0xBE,
            0xBF,
            0xC0,
            0x2F,
            0xC1,
            0x36,
            0x6B,
            // 0x85,
            // 0x86,
            // 0x87,
            // 0x88,
            // 0x89,
            // 0x8A,
            // 0x8B,
            // 0x8C,
            // 0x8D,
            // 0x8E,
            // 0x8F,
            // 0x90,
            // 0x91,
            // 0x92,
            // 0x93,
            // 0x94,
            // 0x95,
            // 0x96,
            // 0x97,
            // 0x98,
            // 0x99,
            // 0x9A,
            // 0x9B,
            // 0x9C,
            // 0x9D,
            // 0x9E,
            // 0x9F,
            // 0xA0,
            // 0xA1,
            // 0xA2,
            // 0xA3,
            // 0xA4,
            // 0xA5,
            // 0xA6,
            // 0x39,
            // 0x44,
            0x71, // i32.and
            0x72, // i32.or
            0x73, // i32.xor
            0x74, // i32.shl
            0x75, // i32.shr_s
            0x76, // i32.shr_u
            0x77, // i32.rotl
            0x2D, // i32.load8_u
            => .{ .i32 = .match(o) },
            0x83, // i64.and
            0x29, // i64.load
            0x2C,
            0x7A,
            0x3D,
            0x2E,
            0x30,
            0x31,
            0x32,
            0x33,
            0x34,
            0x35,
            0x67,
            0x3E,
            0x68,
            0x69,
            0x6C,
            0x6D,
            0x6E,
            0x6F,
            0x70,
            0x78,
            0xC2,
            0xC3,
            0xC4,
            0x37,
            0x3C,
            0x7B,
            0x7C,
            0x7D,
            0x7E,
            0x7F,
            0x80,
            0x81,
            0x82,
            0x84,
            0x85,
            0x38,
            0x86,
            0x87,
            0x88,
            0x89,
            => .{ .i64 = .match(o) },
            0x79,
            0x8A,
            0x5B,
            0x5C,
            0x5D,
            0x5E,
            0x5F,
            0x60,
            0x61,
            0x62,
            0x63,
            0x2A,
            0x64,
            0x65,
            0x66,
            0x8B,
            0x8C,
            0x8D,
            0x8E,
            0x8F,
            0x90,
            0x91,
            0x92,
            0x93,
            0x94,
            0x95,
            0x96,
            0x97,
            0x98,
            // 0x9B,
            // 0x9C,
            // 0x9D,
            // 0x9E,
            // 0x9F,
            // 0xA0,
            // 0xA1,
            // 0xA2,
            // 0xA3,
            // 0xA4,
            // 0xA5,
            // 0xA6,
            // 0x39,
            // 0x44,
            => .{ .f32 = .match(o) },
            0x99,
            0x9A,
            0x9B,
            0x9C,
            0x9D,
            0x9E,
            0x9F,
            0xA0,
            0xA1,
            0xA2,
            0xA3,
            0xA4,
            0xA5,
            0xA6,
            0x2B,
            0x39,
            0x44,
            => .{ .f64 = .match(o) },
            0xD0, 0xD1, 0xD2, 0xD3, 0xD5 => .{ .ref = .match(o) },
            else => {
                std.debug.print("unknown op: {x}\n", .{o});
                return null;
            },
        };
    }

    pub const Control = enum(u32) {
        @"unreachable" = 0x00,
        nop = 0x01,
        block = 0x02,
        loop = 0x03,
        @"if" = 0x04,
        @"else" = 0x05,
        end = 0x0B,
        // block_type_empty = 0x40, // void type
        // block_type_i32 = 0x7F, // i32 type
        // block_type_i64 = 0x7E, // i64 type
        // block_type_f32 = 0x7D, // f32 type
        // block_type_f64 = 0x7C, // f64 type

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x00 => .@"unreachable",
                0x01 => .nop,
                0x02 => .block,
                0x03 => .loop,
                0x04 => .@"if",
                0x05 => .@"else",
                0x0B => .end,
                // 0x40 => .block_type_empty,
                // 0x7F => .block_type_i32,
                // 0x7E => .block_type_i64,
                // 0x7D => .block_type_f32,
                // 0x7C => .block_type_f64,
                else => unreachable,
            };
        }
    };
    pub const Throw = enum(u32) {
        @"try" = 0x06,
        @"catch" = 0x07,
        throw = 0x08,
        rethrow = 0x09,
        catch_all = 0x19,
        throw_ref = 0x0A,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x06 => .@"try",
                0x07 => .@"catch",
                0x08 => .throw,
                0x09 => .rethrow,
                0x0A => .throw_ref,
                0x19 => .catch_all,
                else => unreachable,
            };
        }
    };
    pub const I32 = enum(u32) {
        // Stoe
        load = 0x28, // 40
        load8_s = 0x2C, // 44
        load8_u = 0x2D, // 45
        load16_s = 0x2E, // 46
        load16_u = 0x2F, // 47

        // Store
        store = 0x36, // 54
        store8 = 0x3A, // 58
        store16 = 0x3B, // 59
        @"const" = 0x41, // 65
        // Comparison
        eqz = 0x45, // 69
        eq = 0x46, // 70
        ne = 0x47, // 71
        lt_s = 0x48, // 72
        lt_u = 0x49, // 73
        gt_u = 0x4A, // 74
        gt_s = 0x4B, // 75
        le_u = 0x4C, // 76
        le_s = 0x4D, // 77
        ge_u = 0x4E, // 78
        ge_s = 0x4F, // 79

        @"and" = 0x71, // 113
        @"or" = 0x72, // 114
        xor = 0x73, // 115
        shl = 0x74, // 116
        shr_s = 0x75, // 117
        shr_u = 0x76, // 118
        rotl = 0x77, // 119

        clz = 0x67, // 103
        ctz = 0x68, // 104
        popcnt = 0x69, // 105
        add = 0x6A, // 106
        sub = 0x6B, // 107
        mul = 0x6C, // 108
        div_s = 0x6D, // 109
        div_u = 0x6E, // 110
        rem_s = 0x6F, // 111
        rem_u = 0x70, // 112
        rotr = 0x78, // 120

        wrap_i64 = 0xA7, // 167
        trunc_f32_s = 0xA8, // 168
        trunc_f32_u = 0xA9, // 169
        trunc_f64_s = 0xAA, // 170
        trunc_f64_u = 0xAB, // 171

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x45 => .eqz,
                0x46 => .eq,
                0x47 => .ne,
                0x48 => .lt_s,
                0x49 => .lt_u,
                0x4A => .gt_u,
                0x4B => .gt_s,
                0x28 => .load,
                0x2C => .load8_s,
                0x72 => .@"or",
                0x2D => .load8_u,
                0x2E => .load16_s,
                0x2F => .load16_u,
                0x36 => .store,
                0x3A => .store8,
                0x3B => .store16,
                0x67 => .clz,
                0x68 => .ctz,
                0x69 => .popcnt,
                0x6A => .add,
                0x4C => .le_u,
                0x4D => .le_s,
                0x4E => .ge_u,
                0x4F => .ge_s,
                0xAE => .popcnt,
                0xAF => .add,
                0x6B => .sub,
                0x6C => .mul,
                0x6D => .div_s,
                0x71 => .@"and",
                0x6E => .div_u,
                0x6F => .rem_s,
                0x70 => .rem_u,
                0xA7 => .wrap_i64,
                0xA8 => .trunc_f32_s,
                0xA9 => .trunc_f32_u,
                0xAA => .trunc_f64_s,
                0xAB => .trunc_f64_u,
                0x74 => .shl,
                0x75 => .shr_s,
                0x76 => .shr_u,
                0x77 => .rotl,
                0x41 => .@"const",
                else => {
                    std.debug.print("unknown i32 op: {x}\n", .{op});
                    unreachable;
                },
            };
        }
    };
    pub const I64 = enum(u32) {
        // Load
        load = 0x29, // 41
        load8_s = 0x30, // 48
        load8_u = 0x31, // 49
        load16_s = 0x32, // 50
        load16_u = 0x33, // 51
        load32_s = 0x34, // 52
        load32_u = 0x35, // 53

        // Store
        store = 0x37, // 55
        store8 = 0x3C, // 60
        store16 = 0x3D, // 61
        store32 = 0x3E, // 62
        @"const" = 0x42, // 66

        // Comparison
        eqz = 0x50, // 80
        eq = 0x51, // 81
        ne = 0x52, // 82
        lt_s = 0x53, // 83
        lt_u = 0x54, // 84
        gt_s = 0x55, // 85
        gt_u = 0x56, // 86
        le_s = 0x57, // 87
        le_u = 0x58, // 88
        ge_s = 0x59, // 89
        ge_u = 0x5A, // 96

        // Math
        clz = 0x79, // 178
        ctz = 0x7A, // 179
        popcnt = 0x7B, // 180
        add = 0x7C, // 181
        sub = 0x7D, // 182
        mul = 0x7E, // 183
        //
        // rem_u = 0x70,

        // Bitwise
        @"and" = 0x83, // 188
        @"or" = 0x84, // 189
        xor = 0x85, // 190
        shl = 0x86, // 191
        shr_s = 0x87, // 192
        shr_u = 0x88, // 193
        rotl = 0x89, // 194
        rotr = 0x8A, // 195

        div_s = 0x7F, // 185
        div_u = 0x80, // 186
        rem_s = 0x81, // 187
        rem_u = 0x82, // 188
        // rem_u = 0x83, // 188

        reinterpret_f64 = 0xBD, // 189
        extend8_s = 0xC2, // 190
        extend16_s = 0xC3, // 191
        extend32_s = 0xC4, // 192

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x29 => .load,
                0x30 => @This().load8_s,
                0x31 => I64.load8_u,
                0x32 => .load16_s,
                0x33 => .load16_u,
                0x34 => .load32_s,
                0x35 => .load32_u,
                0x83 => .@"and",
                0x37 => .store,
                0x3C => .store8,
                0x3D => Op.I64.store16,
                0x3E => .store32,
                0x42 => .@"const",
                0x50 => .eqz,
                0x84 => .@"or",
                0x51 => .eq,
                0x52 => .ne,
                0x53 => .lt_s,
                0x54 => .lt_u,
                0x55 => .gt_s,
                0x56 => .gt_u,
                0x57 => .le_s,
                0x58 => .le_u,
                0x59 => .ge_s,
                0x5A => .ge_u,
                0x67 => .clz,
                0x68 => .ctz,
                0x69 => .popcnt,
                // 0x6A => .add,
                0x6C => .mul,
                0x6D => .div_s,
                0x6E => .div_u,
                0x6F => .rem_s,
                0x70 => .rem_u,
                0x78 => .rotr,
                0x79 => .clz,
                0x7A => .ctz,
                0x7B => .popcnt,
                0x7C => .add,
                0x7D => .sub,
                0x7E => .mul,
                0x7F => .div_s,
                0x80 => .div_u,
                0x81 => .rem_s,
                0x82 => .rem_u,
                0x85 => .xor,
                0x86 => .shl,
                0x87 => .shr_s,
                0x88 => .shr_u,
                0x89 => .rotl,
                0x8A => .rotr,
                0xBD => .reinterpret_f64,
                0xC2 => .extend8_s,
                0xC3 => .extend16_s,
                0xC4 => .extend32_s,
                else => {
                    std.debug.print("unknown i64 op: {x}\n", .{op});
                    unreachable;
                },
            };
        }
    };
    pub const F32 = enum(u32) {
        load = 0x2A,
        store = 0x38,
        @"const" = 0x43,

        convert_i32_s = 0xB2,
        convert_i32_u = 0xB3,
        convert_i64_s = 0xB4,
        convert_i64_u = 0xB5,
        demote_f64 = 0xB6,
        // Comparison
        eq = 0x5B,
        ne = 0x5C,
        lt = 0x5D,
        gt = 0x5E,
        le = 0x5F,
        ge = 0x60,

        // Math
        abs = 0x8B, // 139
        neg = 0x8C, // 140
        ceil = 0x8D, // 141
        floor = 0x8E, // 142
        trunc = 0x8F, // 143
        nearest = 0x90, // 144
        sqrt = 0x91, // 145
        add = 0x92, // 146
        sub = 0x93, // 147
        mul = 0x94, // 148
        div = 0x95, // 149
        min = 0x96, // 150
        max = 0x97, // 151
        copysign = 0x98, // 152

        pub fn match(op: u32) @This() {
            return switch (op) {
                0xB2 => .convert_i32_s,
                0xB3 => .convert_i32_u,
                0xB4 => .convert_i64_s,
                0xB5 => .convert_i64_u,
                0xB6 => .demote_f64,
                0x2A => .load,
                0x38 => .store,
                0x43 => .@"const",
                0x5B => .eq,
                0x5C => .ne,
                0x5D => .lt,
                0x5E => .gt,
                0x5F => .le,
                0x60 => .ge,
                0x8B => .abs,
                0x8C => .neg,
                0x8D => .ceil,
                0x8E => .floor,
                0x8F => .trunc,
                0x90 => .nearest,
                0x91 => .sqrt,
                0x92 => .add,
                0x93 => .sub,
                0x94 => .mul,
                0x95 => .div,
                0x96 => .min,
                0x97 => .max,
                0x98 => .copysign,
                else => unreachable,
            };
        }
    };
    pub const F64 = enum(u32) {
        load = 0x2B, // 43
        store = 0x39, // 57
        @"const" = 0x44, // 68

        // Math
        abs = 0x99, // 153
        neg = 0x9A, // 154
        ceil = 0x9B, // 155
        floor = 0x9C, // 156
        trunc = 0x9D, // 157
        nearest = 0x9E, // 158
        sqrt = 0x9F, // 159
        add = 0xA0, // 160
        sub = 0xA1, // 161
        mul = 0xA2, // 162
        div = 0xA3, // 163
        min = 0xA4, // 164
        max = 0xA5, // 165
        copysign = 0xA6, // 166

        convert_i32_s = 0xB7,
        convert_i32_u = 0xB8,
        convert_i64_s = 0xB9,
        convert_i64_u = 0xBA,
        promote_f32 = 0xBB,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x2B => .load,
                0x39 => .store,
                0x44 => .@"const",
                0x99 => .abs,
                0x9A => .neg,
                0x9B => .ceil,
                0x9C => .floor,
                0x9D => .trunc,
                0x9E => .nearest,
                0x9F => .sqrt,
                0xA0 => .add,
                0xA1 => .sub,
                0xA2 => .mul,
                0xA3 => .div,
                0xA4 => .min,
                0xA5 => .max,
                0xA6 => .copysign,
                0xB7 => .convert_i32_s,
                0xB8 => .convert_i32_u,
                0xB9 => .convert_i64_s,
                0xBA => .convert_i64_u,
                0xBB => .promote_f32,
                else => unreachable,
            };
        }
    };

    pub const Return = enum(u32) {
        @"return" = 0x0F,
        return_call = 0x12,
        return_call_indirect = 0x13,
        return_call_ref = 0x15,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x0F => .@"return",
                0x12 => .return_call,
                0x13 => .return_call_indirect,
                0x15 => .return_call_ref,
                else => unreachable,
            };
        }
    };
    pub const Call = enum(u32) {
        call = 0x10,
        call_indirect = 0x11,
        call_ref = 0x14,
        delegate = 0x18,
        drop = 0x1A,
        select = 0x1B,
        select_t = 0x1C,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x10 => .call,
                0x11 => .call_indirect,
                0x14 => .call_ref,
                0x18 => .delegate,
                0x1A => .drop,
                0x1B => .select,
                0x1C => .select_t,
                else => unreachable,
            };
        }
    };
    pub const Table = enum(u32) {
        @"try" = 0x1F,
        get = 0x25,
        set = 0x26,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x1F => .@"try",
                0x25 => .get,
                0x26 => .set,
                else => unreachable,
            };
        }
    };
    pub const Branch = enum(u32) {
        br = 0x0C,
        br_if = 0x0D,
        br_table = 0x0E,
        br_on_null = 0xD4,
        br_on_non_null = 0xD6,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x0C => .br,
                0x0D => .br_if,
                0x0E => .br_table,
                0xD4 => .br_on_null,
                0xD6 => .br_on_non_null,
                else => unreachable,
            };
        }
    };
    pub const Ref = enum(u32) {
        null = 0xD0,
        is_null = 0xD1,
        func = 0xD2,
        as_non_null = 0xD3,
        eq = 0xD5,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0xD0 => .null,
                0xD1 => .is_null,
                0xD2 => .func,
                0xD3 => .as_non_null,
                0xD5 => .eq,
                else => unreachable,
            };
        }
    };
    pub const Local = enum(u32) {
        get = 0x20,
        set = 0x21,
        tee = 0x22,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x20 => Local.get,
                0x21 => Local.set,
                0x22 => Local.tee,
                else => unreachable,
            };
        }
    };
    pub const Global = enum(u32) {
        get = 0x23,
        set = 0x24,

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x23 => .get,
                0x24 => .set,
                else => unreachable,
            };
        }
    };
    pub const Memory = enum(u32) {
        size = 0x3F, // 48
        // In WebAssembly, memory.grow is actually 0xFC 0x00, but we'll use 0xFC for now
        grow = 0xFC, // Using 0xFC as stand-in for multi-byte memory.grow

        pub fn match(op: u32) @This() {
            return switch (op) {
                0x3F => .size,
                0xFC => .grow, // Memory.grow is actually a multi-byte op starting with 0xFC
                else => unreachable,
            };
        }
    };
};

test "op handle" {
    // const o0 = Op.match(0x00);
    try assertByte(0x0D, .{ .branch = .match(0x0D) });
    try assertByte(0x0E, .{ .branch = .match(0x0E) });
    try assertByte(0x0F, .{ .@"return" = .match(0x0F) });
    try assertByte(0x10, .{ .call = .match(0x10) });
    try assertByte(0x11, .{ .call = .match(0x11) });
    try assertByte(0x12, .{ .@"return" = .match(0x12) });
    try assertByte(0x13, .{ .@"return" = .match(0x13) });
    try assertByte(0x14, .{ .call = .match(0x14) });
    try assertByte(0x15, .{ .@"return" = .match(0x15) });
    try assertByte(0x18, .{ .call = .match(0x18) });
    try assertByte(0x1A, .{ .call = .match(0x1A) });
    try assertByte(0x1C, .{ .call = .match(0x1C) });
    try assertByte(0x1F, .{ .table = .match(0x1F) });
    try assertByte(0x20, .{ .local = .match(0x20) });
    try assertByte(0x21, .{ .local = .match(0x21) });
    try assertByte(0x22, .{ .local = .match(0x22) });
    try assertByte(0x23, .{ .global = .match(0x23) });
    try assertByte(0x24, .{ .global = .match(0x24) });
    try assertByte(0x25, .{ .table = .match(0x25) });
    try assertByte(0x26, .{ .table = .match(0x26) });
    try assertByte(0x23, .{ .global = .match(0x23) });
    try assertByte(0x28, .{ .i32 = .match(0x28) });
    try assertByte(0x29, .{ .i64 = .match(0x29) });
    try assertByte(0x2A, .{ .f32 = .match(0x2A) });
    try assertByte(0x2B, .{ .f64 = .match(0x2B) });
    try assertByte(0x2F, .{ .i32 = .match(0x2F) });
    try assertByte(0x30, .{ .i64 = .match(0x30) });
    try assertByte(0x3D, .{ .i64 = Op.I64.match(0x3D) });
    try assertByte(0x31, .{ .i64 = Op.I64.match(0x31) });
    try assertByte(0x32, .{ .i64 = Op.I64.match(0x32) });
    try assertByte(0x33, .{ .i64 = .match(0x33) });
    try assertByte(0x34, .{ .i64 = .match(0x34) });
    try assertByte(0x35, .{ .i64 = .match(0x35) });
    try assertByte(0x36, .{ .i32 = .match(0x36) });
    try assertByte(0x37, .{ .i64 = .match(0x37) });
    try assertByte(0x38, .{ .f32 = .match(0x38) });
    try assertByte(0x3A, .{ .i32 = .match(0x3A) });
    try assertByte(0x3B, .{ .i32 = .match(0x3B) });
    try assertByte(0x3C, .{ .i64 = .match(0x3C) });
    try assertByte(0x3E, .{ .i64 = .match(0x3E) });
}
