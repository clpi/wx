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
// Preopened directories (file descriptors 3+)
preopens: std.ArrayList(Preopen),

const Preopen = struct {
    fd: i32,
    path: []const u8,
};

pub fn init(allocator: std.mem.Allocator, args: [][:0]u8) !WASI {
    var preopens = std.ArrayList(Preopen).init(allocator);
    // Add default preopens: current directory as fd 3
    try preopens.append(.{ .fd = 3, .path = "." });
    
    return WASI{
        .allocator = allocator,
        .args = args,
        .stdout_buffer = try std.ArrayList(u8).initCapacity(allocator, 0),
        .debug = false,
        .preopens = preopens,
    };
}

pub fn deinit(self: *WASI) void {
    self.stdout_buffer.deinit(self.allocator);
    self.preopens.deinit();
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
        const stdout_file = std.fs.File{ .handle = 1 };
        const stderr_file = std.fs.File{ .handle = 2 };

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
            const file = if (fd == 1) stdout_file else stderr_file;
            _ = try file.writeAll(buffer);

            // Collect in buffer only when debugging
            if (self.debug) {
                try self.stdout_buffer.appendSlice(self.allocator, buffer);
            }

            total_written += buf_len;
        }

        // Flush the buffered writers
        if (fd == 1) {} else {}

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

/// Get the resolution of a clock (clock_res_get)
pub fn clock_res_get(_: *WASI, clock_id: i32, resolution_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        // Return nanosecond resolution (1ns = 1)
        const resolution: u64 = 1;
        
        if (resolution_ptr >= 0 and @as(usize, @intCast(resolution_ptr)) + 8 <= memory.len) {
            std.mem.writeInt(u64, memory[@intCast(resolution_ptr)..][0..8], resolution, .little);
        }
        
        _ = clock_id; // Ignore clock_id for now
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Get the time value of a clock (clock_time_get)
pub fn clock_time_get(_: *WASI, clock_id: i32, precision: i64, time_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        // Get current time in nanoseconds
        const timestamp = std.time.nanoTimestamp();
        
        if (time_ptr >= 0 and @as(usize, @intCast(time_ptr)) + 8 <= memory.len) {
            std.mem.writeInt(u64, memory[@intCast(time_ptr)..][0..8], @intCast(timestamp), .little);
        }
        
        _ = clock_id; // Ignore clock_id for now
        _ = precision; // Ignore precision for now
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Close a file descriptor (fd_close)
pub fn fd_close(_: *WASI, fd: i32) !i32 {
    // For now, we only support stdout/stderr which shouldn't be closed
    // Return success for any fd >= 3 (file descriptors)
    if (fd >= 3) {
        return 0; // Success
    }
    return -1; // Cannot close stdin/stdout/stderr
}

/// Read from a file descriptor (fd_read)
pub fn fd_read(self: *WASI, fd: i32, iovs_ptr: i32, iovs_len: i32, nread_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "fd_read");
    
    if (self.debug) {
        o.log("\nWASI fd_read: fd={d}, iovs_ptr={d}, iovs_len={d}, nread_ptr={d}\n", .{ fd, iovs_ptr, iovs_len, nread_ptr });
    }
    
    if (module.memory) |memory| {
        var total_read: u32 = 0;
        
        // Check if the iovs_ptr is valid
        if (iovs_ptr < 0 or @as(usize, @intCast(iovs_ptr)) + (@as(usize, @intCast(iovs_len)) * 8) > memory.len) {
            return -1; // Invalid iovec array
        }
        
        // For stdin (fd=0), we'll return 0 bytes (EOF)
        // For other fds, we also return 0 for now
        if (fd == 0) {
            // stdin - return EOF for now
            total_read = 0;
        } else {
            // Other file descriptors not yet supported
            total_read = 0;
        }
        
        // Write the number of bytes read to nread_ptr
        if (nread_ptr >= 0 and @as(usize, @intCast(nread_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(nread_ptr)..][0..4], total_read, .little);
        }
        
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Get information about a preopened directory (fd_prestat_get)
pub fn fd_prestat_get(self: *WASI, fd: i32, prestat_ptr: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "fd_prestat_get");
    
    if (self.debug) {
        o.log("\nWASI fd_prestat_get: fd={d}, prestat_ptr={d}\n", .{ fd, prestat_ptr });
    }
    
    if (module.memory) |memory| {
        // Check if this is a preopened directory
        for (self.preopens.items) |preopen| {
            if (preopen.fd == fd) {
                // Write prestat structure:
                // u8: tag (0 for dir)
                // u32: path length
                if (prestat_ptr >= 0 and @as(usize, @intCast(prestat_ptr)) + 8 <= memory.len) {
                    memory[@intCast(prestat_ptr)] = 0; // tag = 0 (dir)
                    std.mem.writeInt(u32, memory[@intCast(prestat_ptr) + 4 ..][0..4], @intCast(preopen.path.len), .little);
                    
                    if (self.debug) {
                        o.log("  Found preopen fd={d}, path_len={d}\n", .{ fd, preopen.path.len });
                    }
                }
                return 0; // Success
            }
        }
        
        // Not a preopened directory
        return 8; // EBADF
    } else {
        return -1; // No memory available
    }
}

/// Get the path of a preopened directory (fd_prestat_dir_name)
pub fn fd_prestat_dir_name(self: *WASI, fd: i32, path_ptr: i32, path_len: i32, module: *Module) !i32 {
    var o = Log.op("WASI", "fd_prestat_dir_name");
    
    if (self.debug) {
        o.log("\nWASI fd_prestat_dir_name: fd={d}, path_ptr={d}, path_len={d}\n", .{ fd, path_ptr, path_len });
    }
    
    if (module.memory) |memory| {
        // Find the preopened directory
        for (self.preopens.items) |preopen| {
            if (preopen.fd == fd) {
                const copy_len = @min(@as(usize, @intCast(path_len)), preopen.path.len);
                
                if (path_ptr >= 0 and @as(usize, @intCast(path_ptr)) + copy_len <= memory.len) {
                    @memcpy(memory[@intCast(path_ptr)..][0..copy_len], preopen.path[0..copy_len]);
                    
                    if (self.debug) {
                        o.log("  Copied path: {s}\n", .{preopen.path});
                    }
                }
                return 0; // Success
            }
        }
        
        // Not a preopened directory
        return 8; // EBADF
    } else {
        return -1; // No memory available
    }
}

/// Get file descriptor attributes (fd_fdstat_get)
pub fn fd_fdstat_get(_: *WASI, fd: i32, stat_ptr: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        // Write fdstat structure (24 bytes):
        // u8: fs_filetype
        // u16: fs_flags
        // u64: fs_rights_base
        // u64: fs_rights_inheriting
        
        if (stat_ptr >= 0 and @as(usize, @intCast(stat_ptr)) + 24 <= memory.len) {
            const base: usize = @intCast(stat_ptr);
            
            // Set file type based on fd
            if (fd >= 0 and fd <= 2) {
                // stdin/stdout/stderr - character device
                memory[base] = 2; // CHARACTER_DEVICE
            } else {
                // Other fds - assume directory
                memory[base] = 3; // DIRECTORY
            }
            
            // fs_flags (u16 at offset 2)
            std.mem.writeInt(u16, memory[base + 2 ..][0..2], 0, .little);
            
            // fs_rights_base (u64 at offset 8) - all rights
            std.mem.writeInt(u64, memory[base + 8 ..][0..8], 0xFFFFFFFF, .little);
            
            // fs_rights_inheriting (u64 at offset 16) - all rights
            std.mem.writeInt(u64, memory[base + 16 ..][0..8], 0xFFFFFFFF, .little);
        }
        
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Set file descriptor flags (fd_fdstat_set_flags)
pub fn fd_fdstat_set_flags(_: *WASI, _: i32, _: i32) !i32 {
    // Not implemented yet, return success
    return 0;
}

/// Open a file or directory (path_open)
pub fn path_open(_: *WASI, dirfd: i32, dirflags: i32, path_ptr: i32, path_len: i32, oflags: i32, fs_rights_base: i64, fs_rights_inheriting: i64, fdflags: i32, fd_ptr: i32, module: *Module) !i32 {
    _ = dirfd;
    _ = dirflags;
    _ = oflags;
    _ = fs_rights_base;
    _ = fs_rights_inheriting;
    _ = fdflags;
    
    if (module.memory) |memory| {
        // For now, just fail all path_open operations
        // A real implementation would open the file and assign an fd
        _ = path_ptr;
        _ = path_len;
        _ = fd_ptr;
        
        return 28; // ENOSYS - not implemented
    } else {
        return -1; // No memory available
    }
}

/// Get file or directory metadata (path_filestat_get)
pub fn path_filestat_get(_: *WASI, _: i32, _: i32, _: i32, _: i32, _: i32, _: *Module) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}

/// Remove a directory (path_remove_directory)
pub fn path_remove_directory(_: *WASI, _: i32, _: i32, _: i32, _: *Module) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}

/// Unlink a file (path_unlink_file)
pub fn path_unlink_file(_: *WASI, _: i32, _: i32, _: i32, _: *Module) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}

/// Get random bytes (random_get)
pub fn random_get(_: *WASI, buf_ptr: i32, buf_len: i32, module: *Module) !i32 {
    if (module.memory) |memory| {
        if (buf_ptr >= 0 and @as(usize, @intCast(buf_ptr)) + @as(usize, @intCast(buf_len)) <= memory.len) {
            const buffer = memory[@intCast(buf_ptr)..][0..@intCast(buf_len)];
            
            // Fill with random bytes
            var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
            prng.random().bytes(buffer);
        }
        
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Poll for events (poll_oneoff)
pub fn poll_oneoff(_: *WASI, in_ptr: i32, out_ptr: i32, nsubscriptions: i32, nevents_ptr: i32, module: *Module) !i32 {
    _ = in_ptr;
    _ = out_ptr;
    _ = nsubscriptions;
    
    if (module.memory) |memory| {
        // For now, immediately return with 0 events
        if (nevents_ptr >= 0 and @as(usize, @intCast(nevents_ptr)) + 4 <= memory.len) {
            std.mem.writeInt(u32, memory[@intCast(nevents_ptr)..][0..4], 0, .little);
        }
        
        return 0; // Success
    } else {
        return -1; // No memory available
    }
}

/// Yield the processor (sched_yield)
pub fn sched_yield(_: *WASI) !i32 {
    // Give up CPU time slice
    std.Thread.yield() catch {};
    return 0; // Success
}

/// Receive a message from a socket (sock_recv)
pub fn sock_recv(_: *WASI, _: i32, _: i32, _: i32, _: i32, _: i32, _: i32, _: *Module) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}

/// Send a message on a socket (sock_send)
pub fn sock_send(_: *WASI, _: i32, _: i32, _: i32, _: i32, _: i32, _: *Module) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}

/// Shut down socket send and receive channels (sock_shutdown)
pub fn sock_shutdown(_: *WASI, _: i32, _: i32) !i32 {
    // Not implemented yet
    return 28; // ENOSYS
}
