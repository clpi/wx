const std = @import("std");

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
    throw: Throw,
    branch: Branch,
    call: Call,
    local: Local,
    global: Global,
    ref: Ref,
    table: Table,
    // parametric ops (drop/select) are handled under 'call' in runtime
    memory: Memory,
    @"return": Return,
    i32: I32,
    i64: I64,
    f32: F32,
    f64: F64,

    // Opcode dispatch with memoized per-byte cache (no eager precompute).
    var OPCACHE: [256]?Op = [_]?Op{null} ** 256;

    pub inline fn match(o: u8) ?Op {
        if (OPCACHE[o]) |v| return v;
        const r = _matchSlow(o);
        OPCACHE[o] = r;
        return r;
    }

    // Slow path used at comptime to build the table
    fn _matchSlow(o: u8) ?Op {
        return switch (o) {
            // Control flow (excluding exception-handling range)
            0x00...0x05 => .{ .control = .match(o) },
            0x0B => .{ .control = .end },
            0x10 => .{ .call = .call },
            0x11 => .{ .call = .call_indirect },
            // Branch and return
            0x0C => .{ .branch = .br },
            0x0D => .{ .branch = .br_if },
            0x0E => .{ .branch = .br_table },
            0x0F => .{ .@"return" = .@"return" },
            // Exception handling proposal
            0x06...0x0A => .{ .throw = .match(o) },
            // Parametric drop/select handled under 'call'
            0x1A => .{ .call = .drop },
            0x1B => .{ .call = .select },
            // Locals and globals
            0x20 => .{ .local = .get },
            0x21 => .{ .local = .set },
            0x22 => .{ .local = .tee },
            0x23 => .{ .global = .get },
            0x24 => .{ .global = .set },
            // Table and bulk-memory extended prefix
            0x25 => .{ .table = .get },
            0x26 => .{ .table = .set },
            0xFC => .{ .table = .extended },
            // Reference types
            0xD0, 0xD1, 0xD2 => .{ .ref = .match(o) },
            // Memory size/grow
            0x3F => .{ .memory = .size },
            0x40 => .{ .memory = .grow },
            // i32 grouped ops
            0x28, 0x2C, 0x2D, 0x2E, 0x2F, 0x36, 0x3A, 0x3B, 0x41, 0x45...0x4F, 0x67...0x78, 0xA7...0xAB => .{ .i32 = I32.match(o) },
            // i64 grouped ops
            0x29, 0x30...0x35, 0x37, 0x3C...0x3E, 0x42, 0x50, 0x51...0x5A, 0x79...0x8A, 0xAC...0xB1 => .{ .i64 = I64.match(o) },
            // f32 grouped ops
            0x2A, 0x38, 0x43, 0x5B...0x60, 0x8B...0x98, 0xB2...0xB6 => .{ .f32 = F32.match(o) },
            // f64 grouped ops
            0x2B, 0x39, 0x44, 0x61...0x66, 0x99...0xA6, 0xB7...0xBB => .{ .f64 = F64.match(o) },
            // reinterpret ops (MVP)
            0xBC => .{ .i32 = I32.match(o) }, // i32.reinterpret_f32
            0xBD => .{ .i64 = I64.match(o) }, // i64.reinterpret_f64
            0xBE => .{ .f32 = F32.match(o) }, // f32.reinterpret_i32
            0xBF => .{ .f64 = F64.match(o) }, // f64.reinterpret_i64
            else => return null,
        };
    }

    pub const Control = enum(u8) {
        @"unreachable" = 0x00,
        nop = 0x01,
        block = 0x02,
        loop = 0x03,
        @"if" = 0x04,
        @"else" = 0x05,
        // 0x06..0x0A handled in Throw group
        end = 0x0B,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Branch = enum(u8) {
        br = 0x0C,
        br_if = 0x0D,
        br_table = 0x0E,
        // Reference types proposal (not matched by opcodes here, but needed for switch)
        br_on_non_null = 0xFB,
        br_on_null = 0xFC,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Call = enum(u8) {
        call = 0x10,
        call_indirect = 0x11,
        // Non-MVP or grouped under call by runtime
        call_ref = 0xFB,
        drop = 0x1A,
        select = 0x1B,
        select_t = 0x1C,
        delegate = 0xFD,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Return = enum(u8) {
        @"return" = 0x0F,
        return_call = 0x90,
        return_call_indirect = 0x91,
        return_call_ref = 0x92,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Throw = enum(u8) {
        @"try" = 0x06,
        @"catch" = 0x07,
        throw = 0x08,
        rethrow = 0x09,
        catch_all = 0x0A,
        // Placeholder to satisfy runtime switch; not currently matched
        throw_ref = 0xFB,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    // Parametric enum retained for backward compatibility (unused)
    pub const Parametric = enum(u8) {
        drop = 0x1A,
        select = 0x1B,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Variable = enum(u8) {
        local_get = 0x20,
        local_set = 0x21,
        local_tee = 0x22,
        global_get = 0x23,
        global_set = 0x24,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Local = enum(u8) {
        get = 0x20,
        set = 0x21,
        tee = 0x22,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Global = enum(u8) {
        get = 0x23,
        set = 0x24,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Ref = enum(u8) {
        null = 0xD0,
        is_null = 0xD1,
        func = 0xD2,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Table = enum(u8) {
        get = 0x25,
        set = 0x26,
        extended = 0xFC,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const Memory = enum(u8) {
        size = 0x3F,
        grow = 0x40,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const I32 = enum(u8) {
        load = 0x28,
        load8_s = 0x2C,
        load8_u = 0x2D,
        load16_s = 0x2E,
        load16_u = 0x2F,
        store = 0x36,
        store8 = 0x3A,
        store16 = 0x3B,
        @"const" = 0x41,
        eqz = 0x45,
        eq = 0x46,
        ne = 0x47,
        lt_s = 0x48,
        lt_u = 0x49,
        gt_s = 0x4A,
        gt_u = 0x4B,
        le_s = 0x4C,
        le_u = 0x4D,
        ge_s = 0x4E,
        ge_u = 0x4F,
        clz = 0x67,
        ctz = 0x68,
        popcnt = 0x69,
        add = 0x6A,
        sub = 0x6B,
        mul = 0x6C,
        div_s = 0x6D,
        div_u = 0x6E,
        rem_s = 0x6F,
        rem_u = 0x70,
        @"and" = 0x71,
        @"or" = 0x72,
        xor = 0x73,
        shl = 0x74,
        shr_s = 0x75,
        shr_u = 0x76,
        rotl = 0x77,
        rotr = 0x78,
        wrap_i64 = 0xA7,
        trunc_f32_s = 0xA8,
        trunc_f32_u = 0xA9,
        trunc_f64_s = 0xAA,
        trunc_f64_u = 0xAB,
        reinterpret_f32 = 0xBC,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const I64 = enum(u8) {
        eqz = 0x50,
        load = 0x29,
        load8_s = 0x30,
        load8_u = 0x31,
        load16_s = 0x32,
        load16_u = 0x33,
        load32_s = 0x34,
        load32_u = 0x35,
        store = 0x37,
        store8 = 0x3C,
        store16 = 0x3D,
        store32 = 0x3E,
        @"const" = 0x42,
        eq = 0x51,
        ne = 0x52,
        lt_s = 0x53,
        lt_u = 0x54,
        gt_s = 0x55,
        gt_u = 0x56,
        le_s = 0x57,
        le_u = 0x58,
        ge_s = 0x59,
        ge_u = 0x5A,
        clz = 0x79,
        ctz = 0x7A,
        popcnt = 0x7B,
        add = 0x7C,
        sub = 0x7D,
        mul = 0x7E,
        div_s = 0x7F,
        div_u = 0x80,
        rem_s = 0x81,
        rem_u = 0x82,
        @"and" = 0x83,
        @"or" = 0x84,
        xor = 0x85,
        shl = 0x86,
        shr_s = 0x87,
        shr_u = 0x88,
        rotl = 0x89,
        rotr = 0x8A,
        extend_i32_s = 0xAC,
        extend_i32_u = 0xAD,
        trunc_f32_s = 0xAE,
        trunc_f32_u = 0xAF,
        trunc_f64_s = 0xB0,
        trunc_f64_u = 0xB1,
        reinterpret_f64 = 0xBD,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const F32 = enum(u8) {
        load = 0x2A,
        store = 0x38,
        @"const" = 0x43,
        eq = 0x5B,
        ne = 0x5C,
        lt = 0x5D,
        gt = 0x5E,
        le = 0x5F,
        ge = 0x60,
        abs = 0x8B,
        neg = 0x8C,
        ceil = 0x8D,
        floor = 0x8E,
        trunc = 0x8F,
        nearest = 0x90,
        sqrt = 0x91,
        add = 0x92,
        sub = 0x93,
        mul = 0x94,
        div = 0x95,
        min = 0x96,
        max = 0x97,
        copysign = 0x98,
        convert_i32_s = 0xB2,
        convert_i32_u = 0xB3,
        convert_i64_s = 0xB4,
        convert_i64_u = 0xB5,
        demote_f64 = 0xB6,
        reinterpret_i32 = 0xBE,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };

    pub const F64 = enum(u8) {
        load = 0x2B,
        store = 0x39,
        @"const" = 0x44,
        eq = 0x61,
        ne = 0x62,
        lt = 0x63,
        gt = 0x64,
        le = 0x65,
        ge = 0x66,
        abs = 0x99,
        neg = 0x9A,
        ceil = 0x9B,
        floor = 0x9C,
        trunc = 0x9D,
        nearest = 0x9E,
        sqrt = 0x9F,
        add = 0xA0,
        sub = 0xA1,
        mul = 0xA2,
        div = 0xA3,
        min = 0xA4,
        max = 0xA5,
        copysign = 0xA6,
        convert_i32_s = 0xB7,
        convert_i32_u = 0xB8,
        convert_i64_s = 0xB9,
        convert_i64_u = 0xBA,
        promote_f32 = 0xBB,
        reinterpret_i64 = 0xBF,

        pub inline fn match(op: u8) @This() {
            return @enumFromInt(op);
        }
    };
};
