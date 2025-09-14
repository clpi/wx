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

// i64 ops
fn cmd_i64_add(it: *std.process.ArgIterator) !void {
    const a: i64 = try parseInt(i64, it);
    const b: i64 = try parseInt(i64, it);
    const r = a + b; // i64.add
    try write({}, "{d}\n", .{r});
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

// f64 ops
fn cmd_f64_mul(it: *std.process.ArgIterator) !void {
    const a_str = it.next() orelse return error.MissingArgument;
    const b_str = it.next() orelse return error.MissingArgument;
    const a = try std.fmt.parseFloat(f64, a_str);
    const b = try std.fmt.parseFloat(f64, b_str);
    const r: f64 = a * b; // f64.mul
    try write({}, "{d:.12}\n", .{r});
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
        .{ .name = "i64.add", .desc = "Add two i64", .run = cmd_i64_add },
        .{ .name = "f32.add", .desc = "Add two f32", .run = cmd_f32_add },
        .{ .name = "f64.mul", .desc = "Multiply f64", .run = cmd_f64_mul },
        .{ .name = "mem.store-load", .desc = "Store/load u32 at offset", .run = cmd_mem_store_load },
        .{ .name = "control.sum", .desc = "Sum 1..n via loop", .run = cmd_control_loop_sum },
        .{ .name = "select", .desc = "Select a or b by c", .run = cmd_select_like },
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
