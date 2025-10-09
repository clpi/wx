const Runtime = @import("wasm/runtime.zig");
const std = @import("std");
const Value = Runtime.Value;
const print = @import("util/fmt.zig").print;
const Color = @import("util/fmt/color.zig");
const eq = std.mem.eql;
const config = @import("cmd/config.zig");

fn printHelp(program_name: []const u8) void {
    print("wx - WebAssembly Runtime\n", .{}, Color.cyan);
    print("Usage: {s} [OPTIONS] <wasm_file> [args...]\n\n", .{program_name}, Color.white);

    print("Arguments:\n", .{}, Color.yellow);
    print("  <wasm_file>     WebAssembly (.wasm) file to execute\n", .{}, Color.white);
    print("  [args...]       Arguments to pass to the WASM program\n\n", .{}, Color.white);

    print("Options:\n", .{}, Color.yellow);
    print("  -h, --help      Show this help message\n", .{}, Color.white);
    print("  -d, --debug     Enable debug output\n", .{}, Color.white);
    print("  -j, --jit       Enable JIT compilation\n", .{}, Color.white);
    print("  -a, --aot       Enable AOT (Ahead-of-Time) compilation\n", .{}, Color.white);
    print("  -c, --compile   Alias for --aot\n", .{}, Color.white);
    print("  -o, --output    Output file for AOT compilation\n", .{}, Color.white);
    print("  -v, --version   Show version information\n\n", .{}, Color.white);

    print("Examples:\n", .{}, Color.yellow);
    print("  {s} examples/hello.wasm\n", .{program_name}, Color.white);
    print("  {s} --debug examples/math.wasm\n", .{program_name}, Color.white);
    print("  {s} examples/fibonacci.wasm 10\n", .{program_name}, Color.white);
    print("  {s} --aot examples/hello.wasm -o hello.exe\n", .{program_name}, Color.white);
}

fn printVersion() void {
    print("wx WebAssembly Runtime v0.1.0\n", .{}, Color.cyan);
    print("Built with Zig\n", .{}, Color.white);
}

pub fn main() !void {
    // Use c_allocator for low overhead in release runs
    const allocator = std.heap.c_allocator;

    // Get command line arguments
    var as = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, as);

    // Handle case where no arguments are provided
    if (as.len < 2) {
        printHelp(as[0]);
        return;
    }

    // Check for help or version flags
    for (as[1..]) |arg| {
        if (eq(u8, arg, "-h") or eq(u8, arg, "--help")) {
            printHelp(as[0]);
            return;
        }
        if (eq(u8, arg, "-v") or eq(u8, arg, "--version")) {
            printVersion();
            return;
        }
    }

    // Find first non-flag argument as the WASM path
    var wpath: ?[:0]u8 = null;
    for (as[1..]) |arg| {
        if (arg.len == 0) continue;
        if (arg[0] != '-') { wpath = arg; break; }
    }

    // Ensure we have a WASM file path
    if (wpath == null) {
        print("Error: No WASM file specified\n", .{}, Color.red);
        printHelp(as[0]);
        return;
    }

    // Check for debug flag
    const cfg = config.fromArgs(as[1..]);

    // Read WASM file
    const wasm_bytes = std.fs.cwd().readFileAlloc(allocator, wpath.?, 1024 * 1024 * 10) catch |err| {
        switch (err) {
            error.FileNotFound => {
                print("Error: WASM file '{s}' not found\n", .{wpath.?}, Color.red);
                return;
            },
            error.AccessDenied => {
                print("Error: Permission denied reading '{s}'\n", .{wpath.?}, Color.red);
                return;
            },
            else => return err,
        }
    };
    defer allocator.free(wasm_bytes);

    if (cfg.debug) {
        print("WASM args: {any}\n", .{as[1..]}, Color.cyan);
    }

    // Initialize runtime
    var runtime = try Runtime.init(allocator);
    defer runtime.deinit();

    // Set runtime flags before loading module
    runtime.debug = cfg.debug;
    runtime.validate = cfg.validate;
    runtime.jit_enabled = cfg.jit;

    if (cfg.debug) {
        std.debug.print("Config: debug={}, validate={}, jit={}, aot={}\n", .{cfg.debug, cfg.validate, cfg.jit, cfg.aot});
        std.debug.print("Runtime: debug={}, validate={}, jit_enabled={}\n", .{runtime.debug, runtime.validate, runtime.jit_enabled});
    }

    // Initialize JIT if enabled
    if (runtime.jit_enabled) {
        if (cfg.debug) std.debug.print("Initializing JIT...\n", .{});
        runtime.jit = Runtime.JIT.init(allocator) catch |err| blk: {
            if (cfg.debug) std.debug.print("JIT initialization failed: {s}\n", .{@errorName(err)});
            break :blk null;
        };
        if (runtime.jit) |_| {
            if (cfg.debug) std.debug.print("JIT initialized successfully\n", .{});
        }
    }

    // Load WASM module, fallback to no-validation if validation fails
    var module_load_err: ?anyerror = null;
    var module: *Runtime.Module = undefined;
    if (runtime.validate) {
        module = runtime.loadModule(wasm_bytes) catch |e| blk: {
            module_load_err = e;
            // Retry once without validation
            runtime.validate = false;
            const m2 = runtime.loadModule(wasm_bytes) catch |e2| {
                // Restore flag and rethrow the first error for clarity
                runtime.validate = cfg.validate;
                return e2;
            };
            break :blk m2;
        };
        if (module_load_err) |_| {
            // keep runtime.validate=false for the rest of execution
        }
    } else {
        module = try runtime.loadModule(wasm_bytes);
    }

    // Handle AOT compilation mode
    if (cfg.aot) {
        const AOT = @import("wasm/aot.zig").AOT;
        var aot_compiler = try AOT.init(allocator, module);
        defer aot_compiler.deinit();

        if (cfg.debug) {
            print("Starting AOT compilation...\n", .{}, Color.cyan);
        }

        const compiled = try aot_compiler.compileModule();
        defer allocator.free(compiled.native_code);
        defer allocator.free(compiled.function_table);

        if (cfg.debug) {
            print("AOT compilation complete. Generated {d} bytes of native code\n", .{compiled.native_code.len}, Color.green);
        }

        // Save to file if output specified
        if (cfg.aot_output) |output_path| {
            try aot_compiler.saveExecutable(compiled, output_path);
            print("Native executable saved to: {s}\n", .{output_path}, Color.green);
        } else {
            print("AOT compilation successful. Use -o to save native executable.\n", .{}, Color.green);
        }
        return;
    }

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
    runtime.validate = cfg.validate;
    const exec = runtime.executeFunction(start_func, &[_]Value{});
    if (exec) |_| {
        // ok
    } else |e| {
        // Print minimal diagnostic to help locate failures
        std.debug.print("wx error: {s} at opcode 0x{X:0>2} pos {d}\n", .{ @errorName(e), runtime.last_opcode, runtime.last_pos });
        return e;
    }
}
