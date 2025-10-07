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
debug: bool = false,

pub fn init(allocator: std.mem.Allocator, args: [][:0]u8) !WASI {
    return WASI{
        .allocator = allocator,
        .args = args,
        .stdout_buffer = try std.ArrayList(u8).initCapacity(allocator, 0),
        .debug = false,
    };
}

pub fn deinit(self: *WASI) void {
    self.stdout_buffer.deinit(self.allocator);
}

/// Initialize the WASM module with WASI imports
pub fn setupModule(self: *WASI, _: *Runtime, module: *Module) !void {
    var o = Log.op("WASI", "setupModule");
    var e = Log.err("WASI", "setupModule");
    // Setup memory for args
    if (module.memory == null) {
        e.log("No memory section in module", .{});
        return error.NoMemory;
    }

    // Avoid pre-populating argv in linear memory here to prevent clobbering
    // the guest's data segment. The guest will call args_sizes_get and
    // args_get; we implement those to write into guest-provided pointers.
    o.log("WASI ready (memory size: {d} bytes)\n", .{module.memory.?.len});
    _ = self; // silence unused warnings in some Zig versions
}

/// Write data to stdout
pub fn fd_write(self: *WASI, fd: i32, iovs_ptr: i32, iovs_len: i32, written_ptr: i32, module: *Module) !i32 {
    // Fast path: validate fd early
    if (fd != 1 and fd != 2) {
        if (self.debug) {
            var o = Log.op("WASI", "fd_write");
            o.log("  Invalid file descriptor: {d}\n", .{fd});
        }
        return -1; // Only support stdout and stderr
    }

    if (self.debug) {
        var o = Log.op("WASI", "fd_write");
        o.log("\nWASI fd_write called: fd={d}, iovs_ptr={d}, iovs_len={d}, written_ptr={d}\n", .{ fd, iovs_ptr, iovs_len, written_ptr });
    }

    if (module.memory) |memory| {
        // Fast path: pre-select file handle to avoid repeated branching
        const file = std.fs.File{ .handle = @intCast(fd) };
        
        // Fast validation: single bounds check for entire iovec array
        const iovs_ptr_usize = @as(usize, @intCast(iovs_ptr));
        const iovs_len_usize = @as(usize, @intCast(iovs_len));
        const iovs_array_size = iovs_len_usize * 8;
        
        if (iovs_ptr < 0 or iovs_ptr_usize + iovs_array_size > memory.len) {
            if (self.debug) {
                var o = Log.op("WASI", "fd_write");
                o.log("  Invalid iovec array: ptr={d}, len={d}, memory_size={d}\n", .{ iovs_ptr, iovs_len, memory.len });
            }
            return -1;
        }

        var total_written: u32 = 0;

        // Optimized I/O vector processing loop
        for (0..iovs_len_usize) |i| {
            const iov_base_offset: usize = iovs_ptr_usize + (i * 8);

            // Read buffer pointer and length (zero-copy)
            const buf_ptr = std.mem.readInt(u32, memory[iov_base_offset..][0..4], .little);
            const buf_len = std.mem.readInt(u32, memory[iov_base_offset + 4 ..][0..4], .little);

            if (self.debug) {
                var o = Log.op("WASI", "fd_write");
                o.log("  IOV[{d}]: buf_ptr={d}, buf_len={d}\n", .{ i, buf_ptr, buf_len });
            }

            // Fast path: skip empty buffers early
            if (buf_len == 0) {
                if (self.debug) {
                    var o = Log.op("WASI", "fd_write");
                    o.log("  Empty buffer, skipping\n", .{});
                }
                continue;
            }

            // Fast bounds check
            const buf_ptr_usize = @as(usize, @intCast(buf_ptr));
            if (buf_ptr_usize + buf_len > memory.len) {
                if (self.debug) {
                    var o = Log.op("WASI", "fd_write");
                    o.log("  Invalid buffer: {d} + {d} > {d}\n", .{ buf_ptr, buf_len, memory.len });
                }
                return -1;
            }

            // Zero-copy buffer access
            const buffer = memory[buf_ptr_usize .. buf_ptr_usize + buf_len];

            if (self.debug) {
                var o = Log.op("WASI", "fd_write");
                o.log("  Buffer contents: \"", .{});
                for (buffer) |byte| {
                    if (byte >= 32 and byte <= 126) {
                        o.log("{c}", .{byte});
                    } else {
                        o.log("\\x{X:0>2}", .{byte});
                    }
                }
                o.log("\"\n", .{});
            }

            // Direct write without branching (file already selected)
            _ = try file.writeAll(buffer);

            // Collect in buffer only when debugging
            if (self.debug) {
                try self.stdout_buffer.appendSlice(self.allocator, buffer);
            }

            total_written += buf_len;
        }

        // Write total bytes written to memory
        if (written_ptr >= 0 and @as(usize, @intCast(written_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(written_ptr)..][0..4], total_written, .little);
            if (self.debug) {
                var o = Log.op("WASI", "fd_write");
                o.log("  Wrote total_written={d} to written_ptr={d}\n", .{ total_written, written_ptr });
            }
        }

        if (self.debug) {
            var o = Log.op("WASI", "fd_write");
            o.log("\nWASI fd_write result: {d}\n", .{0});
        }

        return 0;
    } else {
        return -1;
    }
}

/// Seek within a file descriptor
pub fn fd_seek(self: *WASI, fd: i32, offset: i64, whence: i32, new_offset_ptr: i32, module: *Module) !i32 {
    // Fast path: validate fd early
    if (fd != 1 and fd != 2) {
        return -1; // Only support stdout and stderr for now
    }

    if (self.debug) {
        var o = Log.op("WASI", "fd_seek");
        o.log("\nWASI fd_seek: fd={d}, offset={d}, whence={d}, new_offset_ptr={d}\n", .{ fd, offset, whence, new_offset_ptr });
    }

    if (module.memory) |memory| {
        const ptr = @as(usize, @intCast(new_offset_ptr));
        
        // Fast validation and write (always 0 for stdout/stderr)
        if (new_offset_ptr < 0 or ptr + 8 > memory.len) {
            return -1;
        }
        
        std.mem.writeInt(i64, memory[ptr..][0..8], 0, .little);

        if (self.debug) {
            var o = Log.op("WASI", "fd_seek");
            o.log("  Seek result: 0\n", .{});
        }

        return 0;
    } else {
        return -1;
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
        // Fast path: validate both pointers at once
        const count_ptr = @as(usize, @intCast(environ_count_ptr));
        const size_ptr = @as(usize, @intCast(environ_buf_size_ptr));
        
        if (environ_count_ptr < 0 or count_ptr + 4 > memory.len or
            environ_buf_size_ptr < 0 or size_ptr + 4 > memory.len) {
            return -1;
        }

        // Optimized: write zeros for both values (we don't support environment variables yet)
        std.mem.writeInt(u32, memory[count_ptr..][0..4], 0, .little);
        std.mem.writeInt(u32, memory[size_ptr..][0..4], 0, .little);

        return 0;
    } else {
        return -1;
    }
}

/// Get environment variables
pub fn environ_get(_: *WASI, _: i32, _: i32, _: *Module) !i32 {
    // No environment variables to populate
    return 0; // Success
}

/// Get command-line arguments count
pub fn args_sizes_get(self: *WASI, argc_ptr: i32, argv_buf_size_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        // Fast path: validate pointers once
        const argc_ptr_usize = @as(usize, @intCast(argc_ptr));
        const argv_buf_size_ptr_usize = @as(usize, @intCast(argv_buf_size_ptr));
        
        if (argc_ptr < 0 or argc_ptr_usize + 4 > memory.len or
            argv_buf_size_ptr < 0 or argv_buf_size_ptr_usize + 4 > memory.len) {
            return -1;
        }

        // Fast calculation: compute total size in single pass
        var total_size: u32 = 0;
        for (self.args) |arg| {
            total_size += @as(u32, @intCast(arg.len + 1)); // +1 for null terminator
        }

        // Write both values (optimized for cache locality)
        std.mem.writeInt(u32, memory[argc_ptr_usize..][0..4], @as(u32, @intCast(self.args.len)), .little);
        std.mem.writeInt(u32, memory[argv_buf_size_ptr_usize..][0..4], total_size, .little);

        if (self.debug) {
            var o = Log.op("WASI", "args_sizes_get");
            o.log("args_sizes_get: argc={d}, argv_buf_size={d}, argc_ptr={d}, argv_buf_size_ptr={d}\n", .{ self.args.len, total_size, argc_ptr, argv_buf_size_ptr });
        }

        return 0;
    } else {
        return -1;
    }
}

/// Get command-line arguments
pub fn args_get(self: *WASI, argv_ptr: i32, argv_buf_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        const argv_ptr_usize = @as(usize, @intCast(argv_ptr));
        var current_buf_ptr: u32 = @intCast(argv_buf_ptr);

        if (self.debug) {
            var o = Log.op("WASI", "args_get");
            o.log("args_get: argv_ptr={d}, argv_buf_ptr={d}\n", .{ argv_ptr, argv_buf_ptr });
            o.log("  Memory size: {d} bytes\n", .{memory.len});
            o.log("  Arguments:\n", .{});
            for (self.args, 0..) |arg, i| {
                o.log("    arg[{d}] = \"{s}\"\n", .{ i, arg });
            }
        }

        // Fast bounds checking: validate entire argv array and buffer space
        const argv_array_size = self.args.len * 4;
        var total_string_size: usize = 0;
        for (self.args) |arg| {
            total_string_size += arg.len + 1;
        }

        if (argv_ptr_usize + argv_array_size > memory.len or
            @as(usize, @intCast(argv_buf_ptr)) + total_string_size > memory.len) {
            if (self.debug) {
                var o = Log.op("WASI", "args_get");
                o.log("  Error: Not enough memory\n", .{});
            }
            return -1;
        }

        // Optimized loop: write pointers and strings in single pass
        for (self.args, 0..) |arg, i| {
            const arg_ptr_offset = argv_ptr_usize + (i * 4);
            
            // Write pointer to argument string in argv array
            std.mem.writeInt(u32, memory[arg_ptr_offset..][0..4], current_buf_ptr, .little);

            if (self.debug) {
                var o = Log.op("WASI", "args_get");
                o.log("  Writing arg[{d}] pointer {d} at offset {d}\n", .{ i, current_buf_ptr, arg_ptr_offset });
            }

            // Write argument string to buffer (zero-copy from source)
            const buf_start = @as(usize, @intCast(current_buf_ptr));
            @memcpy(memory[buf_start..][0..arg.len], arg);
            memory[buf_start + arg.len] = 0; // Null terminator

            if (self.debug) {
                var o = Log.op("WASI", "args_get");
                o.log("  Writing arg[{d}]=\"{s}\" at offset {d}\n", .{ i, arg, current_buf_ptr });
            }

            current_buf_ptr += @as(u32, @intCast(arg.len + 1));
        }

        if (self.debug) {
            var o = Log.op("WASI", "args_get");
            o.log("args_get completed successfully\n", .{});
        }

        return 0;
    } else {
        return -1;
    }
}

/// Exit the program
pub fn proc_exit(_: *WASI, exit_code: i32) !i32 {
    std.process.exit(@intCast(exit_code));
    return 0; // Never reached
}
