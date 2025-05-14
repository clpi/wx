const Runtime = @import("wasm/runtime.zig");
const cmd = @import("cmd.zig");
const std = @import("std");
const Value = Runtime.Value;
const print = @import("util/fmt.zig").print;
const Color = @import("util/fmt/color.zig");
const eq = std.mem.eql;
const config = @import("cmd/config.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    // var args = std.process.args();
    var a = try std.process.ArgIterator.initWithAllocator(allocator);
    var as = try std.process.argsAlloc(allocator);
    defer a.deinit();
    // defer args.deinit();
    _ = a.skip();
    const wpath = a.next();

    while (a.next()) |arg| {
        print("arg: {s}\n", .{arg}, Color.yellow);
    }

    // defer std.process.argsFree(allocator, args);

    // if (args.len < 2) {
    //     std.debug.print("Usage: {s} <wasm_file> [args...]\n", .{args[0]});
    //     return;
    // }

    // Check for debug flag
    const cfg = config.fromArgs(as[1..]);

    // Read WASM file
    // const wasm_path = args[1];
    const wasm_bytes = try std.fs.cwd().readFileAlloc(allocator, wpath.?, 1024 * 1024 * 10); // 10MB max
    defer allocator.free(wasm_bytes);

    if (cfg.debug) {
        print("WASM args: {any}\n", .{as[1..]}, Color.cyan);
    }

    // Initialize runtime
    var runtime = try Runtime.init(allocator);
    defer runtime.deinit();

    // Load WASM module
    const module = try runtime.loadModule(wasm_bytes);

    // Set runtime debug flag
    runtime.debug = cfg.debug;

    // Setup WASI with program arguments (skip the first two args: program name and wasm file)
    try runtime.setupWASI(as[1..]); // Pass all args including wasm file as argv[0]

    // Set global debug flag in TLS

    // Find _start function
    const start_func = runtime.findExportedFunction("_start") orelse {
        print("No _start function found\n", .{}, Color.red);
        return;
    };

    if (cfg.debug) {
        print("Found entry point: function {d}, type {d}\n", .{ start_func, module.functions.items[start_func].type_index }, Color.cyan);
        print("Function expects {d} parameters, returns {d} values\n", .{ module.types.items[module.functions.items[start_func].type_index].params.len, module.types.items[module.functions.items[start_func].type_index].results.len }, Color.cyan);
    }

    // Execute _start function with no arguments
    _ = try runtime.executeFunction(start_func, &[_]Value{});
}
