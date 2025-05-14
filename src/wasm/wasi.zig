const std = @import("std");
const Log = @import("../util/fmt.zig").Log;
const print = @import("../util/fmt.zig").print;
const Color = @import("../util/fmt/color.zig");
const Runtime = @import("runtime.zig");
const Module = @import("module.zig");
const Value = Runtime.Value;
const WASI = @This();

allocator: std.mem.Allocator,
args: [][:0]u8,
stdout_buffer: std.ArrayList(u8),
debug: bool = true,

pub fn init(allocator: std.mem.Allocator, args: [][:0]u8) !WASI {
    return WASI{
        .allocator = allocator,
        .args = args,
        .stdout_buffer = std.ArrayList(u8).init(allocator),
        .debug = true,
    };
}

pub fn deinit(self: *WASI) void {
    self.stdout_buffer.deinit();
}

/// Initialize the WASM module with WASI imports
pub fn setupModule(self: *WASI, runtime: *Runtime, module: *Module) !void {
    var o = Log.op("WASI", "setupModule");
    var e = Log.err("WASI", "setupModule");
    // Setup memory for args
    if (module.memory == null) {
        e.log("No memory section in module", .{});
        return error.NoMemory;
    }

    // Check if the data section is initialized
    o.log("Setting up WASI module with memory size: {d} bytes\n", .{module.memory.?.len});

    // Initialize command line arguments in memory
    const args_info = try self.setupArgs(module);
    o.log("Initialized args: argc={d}, argv_ptr={d}\n", .{ args_info.argc, args_info.argv_ptr });

    // Add function types for WASI imports
    const i32_type = Runtime.ValueType.i32;
    const i64_type = Runtime.ValueType.i64;

    // fd_write: (i32, i32, i32, i32) -> i32
    const fd_write_type_idx = module.types.items.len;
    try module.types.append(.{
        .params = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{ i32_type, i32_type, i32_type, i32_type }),
        .results = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{i32_type}),
    });

    // fd_seek: (i32, i64, i32, i32) -> i32
    const fd_seek_type_idx = module.types.items.len;
    try module.types.append(.{
        .params = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{ i32_type, i64_type, i32_type, i32_type }),
        .results = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{i32_type}),
    });

    // environ_sizes_get, environ_get, args_sizes_get, args_get: (i32, i32) -> i32
    const two_i32_to_i32_type_idx = module.types.items.len;
    try module.types.append(.{
        .params = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{ i32_type, i32_type }),
        .results = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{i32_type}),
    });

    // proc_exit: (i32) -> void
    const proc_exit_type_idx = module.types.items.len;
    try module.types.append(.{
        .params = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{i32_type}),
        .results = try runtime.allocator.dupe(Runtime.ValueType, &[_]Runtime.ValueType{}),
    });

    // Add WASI imports with correct type indices
    try module.imports.append(.{ .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"), .name = try runtime.allocator.dupe(u8, "fd_write"), .kind = .function, .type_index = @intCast(fd_write_type_idx) });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "fd_seek"),
        .kind = .function,
        .type_index = @intCast(fd_seek_type_idx),
    });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "environ_sizes_get"),
        .kind = .function,
        .type_index = @intCast(two_i32_to_i32_type_idx),
    });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "environ_get"),
        .kind = .function,
        .type_index = @intCast(two_i32_to_i32_type_idx),
    });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "args_sizes_get"),
        .kind = .function,
        .type_index = @intCast(two_i32_to_i32_type_idx),
    });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "args_get"),
        .kind = .function,
        .type_index = @intCast(two_i32_to_i32_type_idx),
    });

    try module.imports.append(.{
        .module = try runtime.allocator.dupe(u8, "wasi_snapshot_preview1"),
        .name = try runtime.allocator.dupe(u8, "proc_exit"),
        .kind = .function,
        .type_index = @intCast(proc_exit_type_idx),
    });
}

/// Write data to stdout
pub fn fd_write(self: *WASI, fd: i32, iovs_ptr: i32, iovs_len: i32, written_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "fd_write");
    if (fd != 1 and fd != 2) {
        o.log("  Invalid file descriptor: {d}\n", .{fd});
        return -1; // Only support stdout and stderr
    }

    if (self.debug) {
        o.log("\nWASI fd_write called: fd={d}, iovs_ptr={d}, iovs_len={d}, written_ptr={d}\n", .{ fd, iovs_ptr, iovs_len, written_ptr });
    }

    if (module.memory) |memory| {
        var total_written: u32 = 0;
        const stdout = std.io.getStdOut();
        const stderr = std.io.getStdErr();

        // Create buffered writers
        var stdout_buffered = std.io.bufferedWriter(stdout.writer());
        var stderr_buffered = std.io.bufferedWriter(stderr.writer());

        // Check if the iovs_ptr is valid
        if (iovs_ptr < 0 or @as(usize, @intCast(iovs_ptr)) + (@as(usize, @intCast(iovs_len)) * 8) > memory.len) {
            if (self.debug) {
                o.log("  Invalid iovec array: ptr={d}, len={d}, memory_size={d}\n", .{ iovs_ptr, iovs_len, memory.len });
            }
            return -1; // Invalid iovec array
        }

        // Read IOVs (I/O vectors)
        for (0..@as(usize, @intCast(iovs_len))) |i| {
            const iov_base_offset: usize = @as(usize, @intCast(iovs_ptr)) + (i * 8); // Each IOV is 8 bytes

            // Read the buffer pointer and length
            const buf_ptr = std.mem.readInt(u32, memory[iov_base_offset..][0..4], .little);
            const buf_len = std.mem.readInt(u32, memory[iov_base_offset + 4 ..][0..4], .little);

            if (self.debug) {
                o.log("  IOV[{d}]: buf_ptr={d}, buf_len={d}\n", .{ i, buf_ptr, buf_len });
            }

            // Skip empty buffers
            if (buf_len == 0) {
                if (self.debug) {
                    o.log("  Empty buffer, skipping\n", .{});
                }
                continue;
            }

            // Check buffer validity
            if (@as(usize, @intCast(buf_ptr)) + buf_len > memory.len) {
                if (self.debug) {
                    o.log("  Invalid buffer: {d} + {d} > {d}\n", .{ buf_ptr, buf_len, memory.len });
                }
                return -1; // Invalid buffer
            }

            // Get the buffer data
            const buffer = memory[buf_ptr .. buf_ptr + buf_len];

            if (self.debug) {
                // Print buffer contents (as hex for non-printable chars)
                o.log("  Buffer contents: \"", .{});
                for (buffer) |byte| {
                    if (byte >= 32 and byte <= 126) {
                        // Printable ASCII character
                        o.log("{c}", .{byte});
                    } else {
                        // Non-printable character, show as hex
                        o.log("\\x{X:0>2}", .{byte});
                    }
                }
                o.log("\"\n", .{});
            }

            // Write to stdout/stderr
            const writer = if (fd == 1) stdout_buffered.writer() else stderr_buffered.writer();
            try writer.writeAll(buffer);

            // Collect in buffer for testing or other purposes
            try self.stdout_buffer.appendSlice(buffer);

            total_written += buf_len;
        }

        // Flush the buffered writers
        if (fd == 1) {
            try stdout_buffered.flush();
        } else {
            try stderr_buffered.flush();
        }

        // Write the number of bytes written to written_ptr
        if (written_ptr >= 0 and @as(usize, @intCast(written_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(written_ptr)..][0..4], total_written, .little);
            if (self.debug) {
                o.log("  Wrote total_written={d} to written_ptr={d}\n", .{ total_written, written_ptr });
            }
        }

        if (self.debug) {
            o.log("\nWASI fd_write result: {d}\n", .{0});
        }

        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Seek within a file descriptor
pub fn fd_seek(self: *WASI, fd: i32, offset: i64, whence: i32, new_offset_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "fd_seek");
    if (self.debug) {
        o.log("\nWASI fd_seek: fd={d}, offset={d}, whence={d}, new_offset_ptr={d}\n", .{ fd, offset, whence, new_offset_ptr });
    }

    // Currently we only support seeking in stdout/stderr, which is a no-op
    // but we'll return success and the current position (0)
    if (fd != 1 and fd != 2) {
        return -1; // Only support stdout and stderr for now
    }

    if (module.memory) |memory| {
        // Write the new offset (always 0 for stdout/stderr)
        if (new_offset_ptr >= 0 and @as(usize, @intCast(new_offset_ptr)) + 8 <= memory.len) {
            std.mem.writeInt(i64, memory[@intCast(new_offset_ptr)..][0..8], 0, .little);
        }

        if (self.debug) {
            o.log("  Seek result: 0\n", .{});
        }

        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Setup arguments in WASM memory
pub fn setupArgs(self: *WASI, module: *Module) !struct { argc: i32, argv_ptr: i32 } {
    if (module.memory == null) {
        return error.NoMemory;
    }
    var o = Log.op("WASI", "setupArgs");

    o.log("Setting up args: args.len={d}\n", .{self.args.len});
    for (self.args, 0..) |arg, i| {
        o.log("  arg[{d}] = \"{s}\"\n", .{ i, arg });
    }

    o.log("Memory size: {d} bytes\n", .{module.memory.?.len});

    // Calculate total size needed for strings
    var total_size: usize = 0;
    for (self.args) |arg| {
        total_size += arg.len + 1; // +1 for null terminator
    }

    // Calculate size needed for argv array
    const argv_array_size = self.args.len * 4; // 4 bytes per pointer

    // Find a suitable location in memory for argv array and strings
    // Start at offset 1024 to avoid interfering with any low memory usage
    const argv_ptr: usize = 1024;
    const strings_ptr: usize = argv_ptr + argv_array_size;

    o.log("  argv_ptr = {d}, strings_ptr = {d}, total_strings_size = {d}\n", .{ argv_ptr, strings_ptr, total_size });

    // Check if we have enough memory
    if (strings_ptr + total_size > module.memory.?.len) {
        o.log("Error: Not enough memory for args: need {d} bytes\n", .{strings_ptr + total_size});
        return error.OutOfMemory;
    }

    var current_string_ptr: usize = strings_ptr;

    // Write argument strings and their pointers
    for (self.args, 0..) |arg, i| {
        // Write pointer to string in argv array
        const argv_entry_ptr = argv_ptr + (i * 4);
        std.mem.writeInt(u32, module.memory.?[argv_entry_ptr..][0..4], @intCast(current_string_ptr), .little);

        o.log("  Writing arg[{d}]=\"{s}\" at memory[{d}], pointer at memory[{d}]={d}\n", .{ i, arg, current_string_ptr, argv_entry_ptr, current_string_ptr });

        // Write string data
        @memcpy(module.memory.?[current_string_ptr..][0..arg.len], arg);
        module.memory.?[current_string_ptr + arg.len] = 0; // Null terminator

        current_string_ptr += arg.len + 1;
    }

    o.log("Arguments setup completed: argc={d}, argv_ptr={d}\n", .{ self.args.len, argv_ptr });

    return .{
        .argc = @intCast(self.args.len),
        .argv_ptr = @intCast(argv_ptr),
    };
}

/// Get environment variables count
pub fn environ_sizes_get(_: *WASI, environ_count_ptr: i32, environ_buf_size_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        // For now, we don't support environment variables
        if (environ_count_ptr >= 0 and @as(usize, @intCast(environ_count_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(environ_count_ptr)..][0..4], 0, .little);
        }

        if (environ_buf_size_ptr >= 0 and @as(usize, @intCast(environ_buf_size_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(environ_buf_size_ptr)..][0..4], 0, .little);
        }

        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Get environment variables
pub fn environ_get(_: *WASI, _: i32, _: i32, _: *Module) !i32 {
    // No environment variables to populate
    return 0; // Success
}

/// Get command-line arguments count
pub fn args_sizes_get(self: *WASI, argc_ptr: i32, argv_buf_size_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "args_sizes_get");
    if (module.memory) |memory| {
        // Write argc
        if (argc_ptr >= 0 and @as(usize, @intCast(argc_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(argc_ptr)..][0..4], @as(u32, @intCast(self.args.len)), .little);
        }

        // Calculate total size needed for all arguments (including null terminators)
        var total_size: u32 = 0;
        for (self.args) |arg| {
            total_size += @as(u32, @intCast(arg.len + 1)); // +1 for null terminator
        }

        // Write argv_buf_size
        if (argv_buf_size_ptr >= 0 and @as(usize, @intCast(argv_buf_size_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(argv_buf_size_ptr)..][0..4], total_size, .little);
        }

        if (self.debug) {
            o.log("args_sizes_get: argc={d}, argv_buf_size={d}, argc_ptr={d}, argv_buf_size_ptr={d}\n", .{ self.args.len, total_size, argc_ptr, argv_buf_size_ptr });
        }

        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Get command-line arguments
pub fn args_get(self: *WASI, argv_ptr: i32, argv_buf_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "args_get");
    if (module.memory) |memory| {
        var current_buf_ptr: u32 = @intCast(argv_buf_ptr);

        if (self.debug) {
            o.log("args_get: argv_ptr={d}, argv_buf_ptr={d}\n", .{ argv_ptr, argv_buf_ptr });
            o.log("  Memory size: {d} bytes\n", .{memory.len});
            o.log("  Arguments:\n", .{});
            for (self.args, 0..) |arg, i| {
                o.log("    arg[{d}] = \"{s}\"\n", .{ i, arg });
            }
        }

        // Check if we have enough memory for the argv array
        const argv_array_size = self.args.len * 4; // 4 bytes per pointer
        if (@as(usize, @intCast(argv_ptr)) + argv_array_size > memory.len) {
            o.log("  Error: Not enough memory for argv array: {d} + {d} > {d}\n", .{ argv_ptr, argv_array_size, memory.len });
            return -1;
        }

        // Calculate total size needed for strings
        var total_size: usize = 0;
        for (self.args) |arg| {
            total_size += arg.len + 1; // +1 for null terminator
        }

        // Check if we have enough memory for the strings
        if (@as(usize, @intCast(argv_buf_ptr)) + total_size > memory.len) {
            o.log("  Error: Not enough memory for argument strings: {d} + {d} > {d}\n", .{ argv_buf_ptr, total_size, memory.len });
            return -1;
        }

        // For each argument
        for (self.args, 0..) |arg, i| {
            // Write pointer to argument string in argv array
            const arg_ptr_offset = @as(usize, @intCast(argv_ptr)) + (i * 4);
            std.mem.writeInt(u32, memory[arg_ptr_offset..][0..4], current_buf_ptr, .little);

            if (self.debug) {
                o.log("  Writing arg[{d}] pointer {d} at offset {d}\n", .{ i, current_buf_ptr, arg_ptr_offset });
            }

            // Write argument string to buffer
            @memcpy(memory[current_buf_ptr..][0..arg.len], arg);
            memory[current_buf_ptr + arg.len] = 0; // Null terminator

            if (self.debug) {
                o.log("  Writing arg[{d}]=\"{s}\" at offset {d}\n", .{ i, arg, current_buf_ptr });
            }

            // Update buffer pointer
            current_buf_ptr += @as(u32, @intCast(arg.len + 1));
        }

        if (self.debug) {
            o.log("args_get completed successfully\n", .{});
        }

        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Exit the program
pub fn proc_exit(_: *WASI, exit_code: i32) !i32 {
    std.process.exit(@intCast(exit_code));
    return 0; // Never reached
}
