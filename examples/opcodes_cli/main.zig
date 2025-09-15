const std = @import("std");

const Cmd = struct {
    name: []const u8,
    desc: []const u8,
    run: *const fn (it: *std.process.ArgIterator) anyerror!void,
};

fn write(_w: anytype, comptime fmt: []const u8, args: anytype) !void {
    _ = _w;
    // Use std.debug.print for compatibility across Zig versions and WASI
    std.debug.print(fmt, args);
}

fn parseInt(comptime T: type, it: *std.process.ArgIterator) !T {
    const s = it.next() orelse return error.MissingArgument;
    return try std.fmt.parseInt(T, s, 0);
}

// Small helper buffer to drive specific load/store opcodes
fn buf8() *[64]u8 {
    var s: [64]u8 = undefined;
    @memset(&s, 0);
    return &s;
}

// Numeric ops (i32)
fn cmd_i32_add(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const r = a + b; // i32.add
    try write({}, "{d}\n", .{r});
}

fn cmd_i32_and(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const b: u32 = @bitCast(try parseInt(i32, it));
    const r = a & b; // i32.and
    try write({}, "{d}\n", .{@as(i32, @bitCast(r))});
}

fn cmd_i32_shl(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const s: u5 = @intCast(try parseInt(u8, it) % 32);
    const r = a << s; // i32.shl
    try write({}, "{d}\n", .{@as(i32, @bitCast(r))});
}

fn cmd_i32_clz(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const r: u32 = @clz(a); // i32.clz
    try write({}, "{d}\n", .{r});
}

fn cmd_i32_ctz(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const r: u32 = @ctz(a); // i32.ctz
    try write({}, "{d}\n", .{r});
}

fn cmd_i32_popcnt(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const r: u32 = @popCount(a); // i32.popcnt
    try write({}, "{d}\n", .{r});
}

fn cmd_i32_div(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const qs = @divTrunc(a, b);
    const qu: i32 = @bitCast(@divFloor(@as(u32, @bitCast(a)), @as(u32, @bitCast(b))));
    try write({}, "{d} {d}\n", .{ qs, qu });
}

fn cmd_i32_rem(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const rs = @rem(a, b);
    const ru: i32 = @bitCast(@mod(@as(u32, @bitCast(a)), @as(u32, @bitCast(b))));
    try write({}, "{d} {d}\n", .{ rs, ru });
}

fn cmd_i32_rot_shr(it: *std.process.ArgIterator) !void {
    const a: u32 = @bitCast(try parseInt(i32, it));
    const s: u5 = @intCast(try parseInt(u8, it) % 32);
    const rotl = std.math.rotl(u32, a, s);
    const rotr = std.math.rotr(u32, a, s);
    const shr_u = a >> s;
    const shr_s: i32 = @bitCast(@as(i32, @bitCast(a)) >> @intCast(s));
    try write({}, "{d} {d} {d} {d}\n", .{ rotl, rotr, shr_u, shr_s });
}

fn cmd_i32_cmp(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const eqz: i32 = @intFromBool(a == 0);
    const eq: i32 = @intFromBool(a == b);
    const ne: i32 = @intFromBool(a != b);
    const lt_s: i32 = @intFromBool(a < b);
    const gt_s: i32 = @intFromBool(a > b);
    const le_s: i32 = @intFromBool(a <= b);
    const ge_s: i32 = @intFromBool(a >= b);
    const lt_u: i32 = @intFromBool(@as(u32, @bitCast(a)) < @as(u32, @bitCast(b)));
    const gt_u: i32 = @intFromBool(@as(u32, @bitCast(a)) > @as(u32, @bitCast(b)));
    const le_u: i32 = @intFromBool(@as(u32, @bitCast(a)) <= @as(u32, @bitCast(b)));
    const ge_u: i32 = @intFromBool(@as(u32, @bitCast(a)) >= @as(u32, @bitCast(b)));
    try write({}, "{d} {d} {d} {d} {d} {d} {d} {d} {d} {d} {d}\n", .{ eqz, eq, ne, lt_s, gt_s, le_s, ge_s, lt_u, gt_u, le_u, ge_u });
}

fn cmd_i32_mem(it: *std.process.ArgIterator) !void {
    var b = buf8();
    const off: usize = @intCast(try parseInt(u8, it));
    const v: i32 = try parseInt(i32, it);
    b[off] = @intCast(v & 0xFF); // store8
    std.mem.writeInt(u16, b[off..][0..2], @intCast(v & 0xFFFF), .little); // store16
    std.mem.writeInt(i32, b[off..][0..4], v, .little); // store32
    const l8u: u8 = b[off];
    const l8s: i8 = @bitCast(b[off]);
    const l16u: u16 = std.mem.readInt(u16, b[off..][0..2], .little);
    const l16s: i16 = std.mem.readInt(i16, b[off..][0..2], .little);
    const l32: i32 = std.mem.readInt(i32, b[off..][0..4], .little);
    try write({}, "{d} {d} {d} {d} {d}\n", .{ l8u, l8s, l16u, l16s, l32 });
}

// i64 ops
fn cmd_i64_add(it: *std.process.ArgIterator) !void {
    const a: i64 = try parseInt(i64, it);
    const b: i64 = try parseInt(i64, it);
    const r = a + b; // i64.add
    try write({}, "{d}\n", .{r});
}

fn cmd_i64_alu(it: *std.process.ArgIterator) !void {
    const a: i64 = try parseInt(i64, it);
    const b: i64 = try parseInt(i64, it);
    const add = a +% b;
    const sub = a -% b;
    const mul = a *% b;
    const clz: i64 = @intCast(@clz(@as(u64, @bitCast(a))));
    const ctz: i64 = @intCast(@ctz(@as(u64, @bitCast(a))));
    const pop: i64 = @intCast(@popCount(@as(u64, @bitCast(a))));
    try write({}, "{d} {d} {d} {d} {d} {d}\n", .{ add, sub, mul, clz, ctz, pop });
}

fn cmd_i64_divrem(it: *std.process.ArgIterator) !void {
    const a: i64 = try parseInt(i64, it);
    const b: i64 = try parseInt(i64, it);
    const qs = @divTrunc(a, b);
    const qu: i64 = @intCast(@divFloor(@as(u64, @bitCast(a)), @as(u64, @bitCast(b))));
    const rs = @rem(a, b);
    const ru: i64 = @intCast(@mod(@as(u64, @bitCast(a)), @as(u64, @bitCast(b))));
    try write({}, "{d} {d} {d} {d}\n", .{ qs, qu, rs, ru });
}

fn cmd_i64_rot_shr(it: *std.process.ArgIterator) !void {
    const a: u64 = @bitCast(try parseInt(i64, it));
    const s: u6 = @intCast(try parseInt(u8, it) % 64);
    const rotl = std.math.rotl(u64, a, s);
    const rotr = std.math.rotr(u64, a, s);
    const shr_u = a >> s;
    const shr_s: i64 = @bitCast(@as(i64, @bitCast(a)) >> @intCast(s));
    try write({}, "{d} {d} {d} {d}\n", .{ rotl, rotr, shr_u, shr_s });
}

fn cmd_i64_mem(it: *std.process.ArgIterator) !void {
    var b = buf8();
    const off: usize = @intCast(try parseInt(u8, it));
    const v: i64 = try parseInt(i64, it);
    b[off] = @intCast(v & 0xFF);
    std.mem.writeInt(u16, b[off..][0..2], @intCast(v & 0xFFFF), .little);
    std.mem.writeInt(u32, b[off..][0..4], @intCast(v & 0xFFFF_FFFF), .little);
    std.mem.writeInt(i64, b[off..][0..8], v, .little);
    const l8u: u8 = b[off];
    const l8s: i8 = @bitCast(b[off]);
    const l16u: u16 = std.mem.readInt(u16, b[off..][0..2], .little);
    const l16s: i16 = std.mem.readInt(i16, b[off..][0..2], .little);
    const l32u: u32 = std.mem.readInt(u32, b[off..][0..4], .little);
    const l32s: i32 = std.mem.readInt(i32, b[off..][0..4], .little);
    const l64: i64 = std.mem.readInt(i64, b[off..][0..8], .little);
    try write({}, "{d} {d} {d} {d} {d} {d} {d}\n", .{ l8u, l8s, l16u, l16s, l32u, l32s, l64 });
}

// f32 ops
fn cmd_f32_add(it: *std.process.ArgIterator) !void {
    const a_str = it.next() orelse return error.MissingArgument;
    const b_str = it.next() orelse return error.MissingArgument;
    const a = try std.fmt.parseFloat(f32, a_str);
    const b = try std.fmt.parseFloat(f32, b_str);
    const r: f32 = a + b; // f32.add
    try write({}, "{d:.6}\n", .{r});
}

fn cmd_f32_unary(it: *std.process.ArgIterator) !void {
    const a = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingArgument);
    const abs = @abs(a);
    const neg = -a;
    const ceilv = @ceil(a);
    const floorv = @floor(a);
    const truncv = @trunc(a);
    const nearestv = @round(a);
    const sqrtv = @sqrt(@abs(a));
    try write({}, "{d} {d} {d} {d} {d} {d} {d}\n", .{ abs, neg, ceilv, floorv, truncv, nearestv, sqrtv });
}

fn cmd_f32_bin_cmp(it: *std.process.ArgIterator) !void {
    const a = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingArgument);
    const b = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingArgument);
    const add = a + b;
    const sub = a - b;
    const mul = a * b;
    const div = a / b;
    const minv = @min(a, b);
    const maxv = @max(a, b);
    const copys = std.math.copysign(a, b);
    const eq: i32 = @intFromBool(a == b);
    const ne: i32 = @intFromBool(a != b);
    const lt: i32 = @intFromBool(a < b);
    const gt: i32 = @intFromBool(a > b);
    const le: i32 = @intFromBool(a <= b);
    const ge: i32 = @intFromBool(a >= b);
    try write({}, "{d} {d} {d} {d} {d} {d} {d} {d} {d} {d} {d}\n", .{ add, sub, mul, div, minv, maxv, copys, eq, ne, lt, gt + le + ge });
}

fn cmd_f32_convert(it: *std.process.ArgIterator) !void {
    const i = try parseInt(i32, it);
    const u = try parseInt(u32, it);
    const s_from_i32: f32 = @floatFromInt(i);
    const u_from_u32: f32 = @floatFromInt(u);
    const i64v = try parseInt(i64, it);
    const u64v = try parseInt(u64, it);
    const s_from_i64: f32 = @floatFromInt(i64v);
    const u_from_u64: f32 = @floatFromInt(u64v);
    const f64v = try std.fmt.parseFloat(f64, it.next() orelse return error.MissingArgument);
    const dem: f32 = @floatCast(f64v);
    try write({}, "{d} {d} {d} {d} {d}\n", .{ s_from_i32, u_from_u32, s_from_i64, u_from_u64, dem });
}

// f64 ops
fn cmd_f64_mul(it: *std.process.ArgIterator) !void {
    const a_str = it.next() orelse return error.MissingArgument;
    const b_str = it.next() orelse return error.MissingArgument;
    const a = try std.fmt.parseFloat(f64, a_str);
    const b = try std.fmt.parseFloat(f64, b_str);
    const r: f64 = a * b; // f64.mul
    try write({}, "{d:.12}\n", .{r});
}

fn cmd_f64_unary(it: *std.process.ArgIterator) !void {
    const a = try std.fmt.parseFloat(f64, it.next() orelse return error.MissingArgument);
    const abs = @abs(a);
    const neg = -a;
    const ceilv = @ceil(a);
    const floorv = @floor(a);
    const truncv = @trunc(a);
    const nearestv = @round(a);
    const sqrtv = @sqrt(@abs(a));
    try write({}, "{d} {d} {d} {d} {d} {d} {d}\n", .{ abs, neg, ceilv, floorv, truncv, nearestv, sqrtv });
}

fn cmd_f64_bin_cmp(it: *std.process.ArgIterator) !void {
    const a = try std.fmt.parseFloat(f64, it.next() orelse return error.MissingArgument);
    const b = try std.fmt.parseFloat(f64, it.next() orelse return error.MissingArgument);
    const add = a + b;
    const sub = a - b;
    const mul = a * b;
    const div = a / b;
    const minv = @min(a, b);
    const maxv = @max(a, b);
    const copys = std.math.copysign(a, b);
    const eq: i32 = @intFromBool(a == b);
    const ne: i32 = @intFromBool(a != b);
    const lt: i32 = @intFromBool(a < b);
    const gt: i32 = @intFromBool(a > b);
    const le: i32 = @intFromBool(a <= b);
    const ge: i32 = @intFromBool(a >= b);
    try write({}, "{d} {d} {d} {d} {d} {d} {d} {d} {d} {d} {d}\n", .{ add, sub, mul, div, minv, maxv, copys, eq, ne, lt, gt + le + ge });
}

fn cmd_f64_convert(it: *std.process.ArgIterator) !void {
    const i = try parseInt(i32, it);
    const u = try parseInt(u32, it);
    const s_from_i32: f64 = @floatFromInt(i);
    const u_from_u32: f64 = @floatFromInt(u);
    const i64v = try parseInt(i64, it);
    const u64v = try parseInt(u64, it);
    const s_from_i64: f64 = @floatFromInt(i64v);
    const u_from_u64: f64 = @floatFromInt(u64v);
    const f32v = try std.fmt.parseFloat(f32, it.next() orelse return error.MissingArgument);
    const prom: f64 = @floatCast(f32v);
    try write({}, "{d} {d} {d} {d} {d}\n", .{ s_from_i32, u_from_u32, s_from_i64, u_from_u64, prom });
}

fn cmd_select_t(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const cond: i32 = try parseInt(i32, it);
    const r = if (cond != 0) a else b;
    try write({}, "{d}\n", .{r});
}

fn cmd_mem_size_grow(_: *std.process.ArgIterator) !void {
    var big: [65536]u8 = undefined;
    @memset(&big, 0x5A);
    try write({}, "OK\n", .{});
}

// Memory load/store demonstration using linear memory emulation via a slice
fn cmd_mem_store_load(it: *std.process.ArgIterator) !void {
    // allocate a small buffer; wasm lowers to memory ops
    var buf: [64]u8 = undefined;
    @memset(&buf, 0);
    const off: usize = @intCast(try parseInt(u8, it));
    const v: u32 = try parseInt(u32, it);
    // store32 (little endian)
    std.mem.writeInt(u32, buf[off..][0..4], v, .little);
    // load32
    const got = std.mem.readInt(u32, buf[off..][0..4], .little);
    try write({}, "{d}\n", .{got});
}

// Control flow: block/loop/br/br_if
fn cmd_control_loop_sum(it: *std.process.ArgIterator) !void {
    var n: i32 = try parseInt(i32, it);
    var acc: i32 = 0;
    // while loop; should lower to loop/br_if
    while (n > 0) : (n -= 1) {
        acc += n;
    }
    try write({}, "{d}\n", .{acc});
}

// Parametric: drop/select equivalent
fn cmd_select_like(it: *std.process.ArgIterator) !void {
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    const c: i32 = try parseInt(i32, it);
    const r = if (c != 0) a else b; // models select
    try write({}, "{d}\n", .{r});
}

// Locals get/set/tee are naturally used throughout; demonstrate explicitly
fn cmd_locals_demo(it: *std.process.ArgIterator) !void {
    _ = it; // no input
    const x: i32 = 3; // local.set
    var y: i32 = x; // local.get -> local.set
    const z: i32 = blk: { // tee modeled by assigning and using value
        y += 5; // local.get + add + local.set
        break :blk y; // local.get
    };
    try write({}, "{d}\n", .{x + y + z});
}

// Simple table-like indirect call by manual dispatch (not guaranteed to lower to call_indirect)
fn fn_add(a: i32, b: i32) i32 {
    return a + b;
}
fn fn_sub(a: i32, b: i32) i32 {
    return a - b;
}

fn cmd_dispatch(it: *std.process.ArgIterator) !void {
    const which = it.next() orelse return error.MissingArgument;
    const a: i32 = try parseInt(i32, it);
    const b: i32 = try parseInt(i32, it);
    var res: i32 = 0;
    if (std.mem.eql(u8, which, "add")) {
        res = fn_add(a, b);
    } else if (std.mem.eql(u8, which, "sub")) {
        res = fn_sub(a, b);
    } else return error.InvalidArgument;
    try write({}, "{d}\n", .{res});
}

fn usage(w: anytype, prog: []const u8, cmds: []const Cmd) !void {
    try write(w, "opcodes-cli (WASI)\n", .{});
    try write(w, "Usage: {s} <command> [args]\n\n", .{prog});
    try write(w, "Commands:\n", .{});
    for (cmds) |c| {
        try write(w, "  {s:18} {s}\n", .{ c.name, c.desc });
    }
    try write(w, "\nExamples:\n", .{});
    try write(w, "  {s} i32.add 5 3\n", .{prog});
    try write(w, "  {s} mem.store-load 8 305419896\n", .{prog});
    try write(w, "  {s} control.sum 10000\n", .{prog});
}

pub fn main() !void {
    // WASI entry; std supports args/env and stdout via fd_write
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var it = try std.process.ArgIterator.initWithAllocator(allocator);
    defer it.deinit();
    const prog = it.next() orelse "opcodes-cli";

    const w = {};

    const cmds = [_]Cmd{
        .{ .name = "i32.add", .desc = "Add two i32", .run = cmd_i32_add },
        .{ .name = "i32.and", .desc = "Bitwise and two i32", .run = cmd_i32_and },
        .{ .name = "i32.shl", .desc = "Shift-left i32 by s", .run = cmd_i32_shl },
        .{ .name = "i32.clz", .desc = "Count leading zeros", .run = cmd_i32_clz },
        .{ .name = "i32.ctz", .desc = "Count trailing zeros", .run = cmd_i32_ctz },
        .{ .name = "i32.popcnt", .desc = "Population count", .run = cmd_i32_popcnt },
        .{ .name = "i32.div", .desc = "div_s and div_u", .run = cmd_i32_div },
        .{ .name = "i32.rem", .desc = "rem_s and rem_u", .run = cmd_i32_rem },
        .{ .name = "i32.rot-shr", .desc = "rotl/rotr/shr_s/u", .run = cmd_i32_rot_shr },
        .{ .name = "i32.cmp", .desc = "all comparisons", .run = cmd_i32_cmp },
        .{ .name = "i32.mem", .desc = "load/store 8/16/32", .run = cmd_i32_mem },
        .{ .name = "i64.add", .desc = "Add two i64", .run = cmd_i64_add },
        .{ .name = "i64.alu", .desc = "add/sub/mul/clz/ctz/popcnt", .run = cmd_i64_alu },
        .{ .name = "i64.divrem", .desc = "div/rem s/u", .run = cmd_i64_divrem },
        .{ .name = "i64.rot-shr", .desc = "rotl/rotr/shr_s/u", .run = cmd_i64_rot_shr },
        .{ .name = "i64.mem", .desc = "load/store sizes", .run = cmd_i64_mem },
        .{ .name = "f32.add", .desc = "Add two f32", .run = cmd_f32_add },
        .{ .name = "f32.unary", .desc = "abs/neg/ceil/floor/trunc/nearest/sqrt", .run = cmd_f32_unary },
        .{ .name = "f32.bin-cmp", .desc = "add/sub/mul/div/min/max/cmp/copysign", .run = cmd_f32_bin_cmp },
        .{ .name = "f32.convert", .desc = "convert/demote", .run = cmd_f32_convert },
        .{ .name = "f64.mul", .desc = "Multiply f64", .run = cmd_f64_mul },
        .{ .name = "f64.unary", .desc = "abs/neg/ceil/floor/trunc/nearest/sqrt", .run = cmd_f64_unary },
        .{ .name = "f64.bin-cmp", .desc = "add/sub/mul/div/min/max/cmp/copysign", .run = cmd_f64_bin_cmp },
        .{ .name = "f64.convert", .desc = "convert/promote", .run = cmd_f64_convert },
        .{ .name = "mem.store-load", .desc = "Store/load u32 at offset", .run = cmd_mem_store_load },
        .{ .name = "mem.size-grow", .desc = "exercise memory", .run = cmd_mem_size_grow },
        .{ .name = "control.sum", .desc = "Sum 1..n via loop", .run = cmd_control_loop_sum },
        .{ .name = "select", .desc = "Select a or b by c", .run = cmd_select_like },
        .{ .name = "select.t", .desc = "Typed select", .run = cmd_select_t },
        .{ .name = "locals.demo", .desc = "Use locals set/get/tee", .run = cmd_locals_demo },
        .{ .name = "dispatch", .desc = "Pseudo indirect call", .run = cmd_dispatch },
    };

    const sub = it.next() orelse {
        try usage(w, prog, &cmds);
        return;
    };

    if (std.mem.eql(u8, sub, "--help") or std.mem.eql(u8, sub, "--list")) {
        try usage(w, prog, &cmds);
        return;
    }

    // dispatch
    inline for (cmds) |c| {
        if (std.mem.eql(u8, sub, c.name)) {
            try c.run(&it);
            return;
        }
    }

    try write(w, "Unknown command: {s}\n\n", .{sub});
    try usage(w, prog, &cmds);
}
