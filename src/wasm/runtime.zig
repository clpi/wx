const std = @import("std");
const print = @import("../util/fmt.zig").print;
const Block = @import("block.zig");
const Color = @import("../util/fmt/color.zig");
const Runtime = @This();
const Log = @import("../util/fmt.zig").Log;
const mem = std.mem;
const Allocator = mem.Allocator;
const SmallVec = @import("stack.zig").SmallVec;

pub const value = @import("value.zig");
pub const Value = @import("value.zig").Value;
pub const ValueType = @import("value.zig").Type;
pub const Module = @import("module.zig");
pub const WASI = @import("wasi.zig");
pub const Op = @import("op.zig").Op;
pub const Error = @import("op.zig").Error;

// Near the top of the file, add Function import
const Function = Module.Function;
const BlockType = Block.Type;
const BytecodeReader = Module.Reader;
inline fn asI32(v: Value) i32 {
    return switch (@as(ValueType, std.meta.activeTag(v))) {
        .i32 => v.i32,
        .i64 => @intCast(v.i64),
        .f32 => @intFromFloat(v.f32),
        .f64 => @intFromFloat(v.f64),
        else => 0,
    };
}

inline fn asU32(v: Value) u32 {
    return @as(u32, @bitCast(asI32(v)));
}
const FunctionSummary = struct {
    code_len: usize,
    block_count: usize,
};

debug: bool = false,
validate: bool = true,
allocator: Allocator,
stack: SmallVec(Value, 256),
block_stack: SmallVec(Block, 64),
module: ?*Module,
wasi: ?WASI = null,

// New field: Block position index mapping
// Maps instruction positions to their containing block index
// This helps avoid expensive linear searches
block_position_map: std.AutoHashMap(usize, usize),
function_summary: std.AutoHashMap(usize, FunctionSummary),
// Debug tracking for last executed opcode
last_opcode: u8 = 0,
last_pos: usize = 0,

pub fn init(allocator: Allocator) !*Runtime {
    const runtime = try allocator.create(Runtime);
    runtime.* = Runtime{
        .allocator = allocator,
        .stack = undefined,
        .block_stack = undefined,
        .block_position_map = undefined,
        .module = null,
        .debug = false,
        .validate = true,
        .function_summary = undefined,
    };
    // Initialize small-vector stacks
    runtime.stack = SmallVec(Value, 256).init();
    runtime.block_stack = SmallVec(Block, 64).init();
    runtime.block_position_map = std.AutoHashMap(usize, usize).init(allocator);
    runtime.function_summary = std.AutoHashMap(usize, FunctionSummary).init(allocator);
    return runtime;
}

pub fn deinit(self: *Runtime) void {
    var o = Log.op("deinit", "Runtime");
    o.log("Cleaning up runtime resources", .{});

    // Free WASI resources
    if (self.wasi) |*wasi| {
        o.log("Freeing WASI resources", .{});
        wasi.deinit();
        self.wasi = null;
    }

    // Free module resources if we own the module
    if (self.module) |module| {
        o.log("Freeing module resources", .{});
        module.deinit();
        self.module = null;
    }

    // Free stack resources
    o.log("Freeing stack with {d} items", .{self.stack.items.len});
    self.stack.deinit(self.allocator);

    // Free block stack resources
    o.log("Freeing block stack", .{});
    self.block_stack.deinit(self.allocator);

    // Free block position map
    o.log("Freeing block position map", .{});
    self.block_position_map.deinit();

    // Free function summaries
    o.log("Freeing function summaries", .{});
    self.function_summary.deinit();

    o.log("Runtime cleanup complete", .{});
}

pub fn loadModule(self: *Runtime, bytes: []const u8) !*Module {
    var o = Log.op("loadModule", "");
    o.log("Loading WebAssembly module", .{});

    // Parse the module
    const module = try Module.parse(self.allocator, bytes);
    self.module = module;

    // Validate the module before execution (can be disabled)
    if (self.validate) {
        o.log("Validating module", .{});
        try module.validateModule();
    }

    // Precompute light function summaries for validator/execution
    try self.function_summary.ensureTotalCapacity(@intCast(module.functions.items.len));
    for (module.functions.items, 0..) |f, idx| {
        if (f.imported) continue;
        const code = f.code;
        var blocks: usize = 0;
        var i: usize = 0;
        while (i < code.len) : (i += 1) {
            const b = code[i];
            switch (b) {
                0x02, 0x03, 0x04 => blocks += 1, // block/loop/if
                else => {},
            }
        }
        try self.function_summary.put(idx, .{ .code_len = code.len, .block_count = blocks });
    }

    o.log("Module loaded and validated successfully", .{});

    return module;
}

pub fn setupWASI(self: *Runtime, args: [][:0]u8) !void {
    if (self.wasi != null) {
        self.wasi.?.deinit();
    }

    self.wasi = try WASI.init(self.allocator, args);
    // Propagate runtime debug into WASI to control logging
    self.wasi.?.debug = self.debug;

    if (self.module) |module| {
        try self.wasi.?.setupModule(self, module);
    }
}

// ===== Fast memory helpers =====
inline fn memOrError(self: *Runtime) ![]u8 {
    const module = self.module orelse return Error.InvalidAccess;
    if (module.memory == null) return Error.InvalidAccess;
    return module.memory.?;
}

inline fn effAddr(base: i32, offset: usize) !usize {
    if (base < 0) return Error.InvalidAccess;
    return @as(usize, @intCast(base)) + offset;
}

inline fn readLittle(self: *Runtime, comptime T: type, addr: usize) !T {
    const m = try self.memOrError();
    const size = @sizeOf(T);
    if (addr + size > m.len) return Error.InvalidAccess;
    return std.mem.readInt(T, m[addr..][0..size], .little);
}

inline fn writeLittle(self: *Runtime, comptime T: type, addr: usize, v: T) !void {
    const m = try self.memOrError();
    const size = @sizeOf(T);
    if (addr + size > m.len) return Error.InvalidAccess;
    std.mem.writeInt(T, m[addr..][0..size], v, .little);
}

pub fn handleImport(self: *Runtime, module_name: []const u8, field_name: []const u8, args: []const Value) !Value {
    // Only handle WASI imports for now
    var o = Log.op("handleImport", "");
    var e = Log.err("handleImport", "");
    if (std.mem.eql(u8, module_name, "wasi_snapshot_preview1")) {
        if (self.wasi == null) {
            e.log("WASI not initialized", .{});
            return Error.UnknownImport;
        }

        if (std.mem.eql(u8, field_name, "fd_write")) {
            if (args.len < 4) return Error.TypeMismatch;
            if (self.module) |module| {
                const fd = args[0].i32;
                const iovs_ptr = args[1].i32;
                const iovs_len = args[2].i32;
                const written_ptr = args[3].i32;

                o.log("\nWASI fd_write called: fd={d}, iovs_ptr={d}, iovs_len={d}, written_ptr={d}\n", .{ fd, iovs_ptr, iovs_len, written_ptr });

                const result = try self.wasi.?.fd_write(fd, iovs_ptr, iovs_len, written_ptr, module);
                o.log("WASI fd_write result: {d}\n", .{result});
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "environ_sizes_get")) {
            if (args.len < 2) return Error.TypeMismatch;
            if (self.module) |module| {
                const environ_count_ptr = args[0].i32;
                const environ_buf_size_ptr = args[1].i32;

                const result = try self.wasi.?.environ_sizes_get(environ_count_ptr, environ_buf_size_ptr, module);
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "environ_get")) {
            if (args.len < 2) return Error.TypeMismatch;
            if (self.module) |module| {
                const environ_ptr = args[0].i32;
                const environ_buf_ptr = args[1].i32;

                const result = try self.wasi.?.environ_get(environ_ptr, environ_buf_ptr, module);
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "args_sizes_get")) {
            if (args.len < 2) return Error.TypeMismatch;
            if (self.module) |module| {
                const argc_ptr = args[0].i32;
                const argv_buf_size_ptr = args[1].i32;

                const result = try self.wasi.?.args_sizes_get(argc_ptr, argv_buf_size_ptr, module);
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "args_get")) {
            if (args.len < 2) return Error.TypeMismatch;
            if (self.module) |module| {
                const argv_ptr = args[0].i32;
                const argv_buf_ptr = args[1].i32;

                const result = try self.wasi.?.args_get(argv_ptr, argv_buf_ptr, module);
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "fd_seek")) {
            if (args.len < 4) return Error.TypeMismatch;
            if (self.module) |module| {
                const fd = args[0].i32;
                const offset = args[1].i64;
                const whence = args[2].i32;
                const new_offset_ptr = args[3].i32;

                const result = try self.wasi.?.fd_seek(fd, offset, whence, new_offset_ptr, module);
                return Value{ .i32 = result };
            }
        } else if (std.mem.eql(u8, field_name, "proc_exit")) {
            if (args.len < 1) return Error.TypeMismatch;
            const exit_code = args[0].i32;

            const result = try self.wasi.?.proc_exit(exit_code);
            return Value{ .i32 = result };
        }

        Log.err("Unknown WASI import", "field_name").log(
            "Unknown WASI import: {s}",
            .{field_name},
        );
        return Error.UnknownImport;
    }

    Log.err("Unknown import module", "module_name").log(
        "Unknown import module: {s}::{s}",
        .{ module_name, field_name },
    );
    return Error.UnknownImport;
}

fn dumpStack(self: *Runtime, prefix: []const u8) void {
    Log.err("dumpStack", "prefix").log(
        "{s}{s}Stack state (size={d}):",
        .{ prefix, self.stack.items.len },
    );
    for (self.stack.items, 0..) |item, idx| {
        switch (item) {
            .i32 => |v| Log.err("dumpStack", "i32").log(
                "  [{d}] i32={d}",
                .{ idx, v },
            ),
            .i64 => |v| Log.err("dumpStack", "i64").log(
                "  [{d}] i64={d}",
                .{ idx, v },
            ),
            .f64 => |v| Log.err("dumpStack", "f64").log(
                "  [{d}] f64={}",
                .{ idx, v },
            ),
            else => Log.err("dumpStack", "unknown").log(
                "  [{d}] unknown",
                .{idx},
            ),
        }
    }
}

pub fn executeFunction(self: *Runtime, func_index: usize, args: []const Value) !Value {
    const module = self.module orelse return Error.InvalidAccess;
    if (func_index >= module.functions.items.len) return Error.InvalidAccess;

    const func = module.functions.items[func_index];
    const func_type = module.types.items[func.type_index];

    var oe = Log.op("executeFunction", "");
    if (self.debug) {
        std.debug.print("[wx] enter func {d}, params={d}, locals={d}, codelen={d}\n", .{ func_index, args.len, func.locals.len, func.code.len });
    }

    // Type check arguments
    if (args.len != func_type.params.len) {
        Log.err("Type mismatch", "args").log(
            "function expects {d} arguments but got {d}",
            .{ func_type.params.len, args.len },
        );
    }

    // If this is an imported function, find and call the import
    if (func.imported) {
        // Imported functions occupy the lowest function indices in the same
        // order as they appear in the import section. Map func_index to the
        // corresponding import by ordinal.
        var ordinal: usize = 0;
        var i: usize = 0;
        while (i < func_index) : (i += 1) {
            if (module.functions.items[i].imported) ordinal += 1;
        }
        // Find the ordinal-th function import
        var fi: usize = 0;
        for (module.imports.items) |import| {
            if (import.kind == .function) {
                if (fi == ordinal) {
                    if (self.wasi) |*wasi| {
                        if (wasi.debug) {
                            oe.log("\nCalling imported function {s}::{s} with args: {any}\n", .{ import.module, import.name, args });
                        }
                    }
                    return try self.handleImport(import.module, import.name, args);
                }
                fi += 1;
            }
        }
        oe.log("Could not map imported function index {d} to import ordinal {d}", .{ func_index, ordinal });
        return Error.UnknownImport;
    }

    // Debug: show function code
    if (self.wasi) |*wasi| {
        if (wasi.debug) {
            oe.log("{s}Function {d} code bytes: ", .{ Color.cyan, func_index });
            for (func.code) |byte| {
                _ = byte;
                // oe.log("0x{X:0>2} ", .{byte});
            }
            // oe.log("{s}\n", .{Color.reset});
        }
    }

    // Save current stack size to restore on error
    const original_stack_size = self.stack.items.len;
    errdefer self.stack.shrinkRetainingCapacity(original_stack_size);

    // Create local variables environment
    const total_locals = func_type.params.len + func.locals.len;
    var locals_env = try std.ArrayList(Value).initCapacity(self.allocator, total_locals);
    defer locals_env.deinit(self.allocator);

    // Initialize locals with arguments, converting types if necessary
    for (args, 0..) |arg, i| {
        const param_type = func_type.params[i];
        const arg_type = @as(ValueType, std.meta.activeTag(arg));

        if (arg_type == param_type) {
            // Types match, use the argument as is
            try locals_env.append(self.allocator, arg);
        } else {
            // Types don't match, try to convert
            oe.log("Type mismatch for argument {d}: expected {s}, got {s}", .{
                i, @tagName(param_type), @tagName(arg_type),
            });
            oe.log("Attempting to convert value to expected type", .{});

            // Convert the value to the expected type
            const converted_value = switch (param_type) {
                .i32 => switch (arg_type) {
                    .i64 => Value{ .i32 = @as(i32, @intCast(arg.i64)) },
                    .f32 => Value{ .i32 = @as(i32, @intFromFloat(arg.f32)) },
                    .f64 => Value{ .i32 = @as(i32, @intFromFloat(arg.f64)) },
                    else => {
                        oe.log("Cannot convert {s} to i32", .{@tagName(arg_type)});
                        return Error.TypeMismatch;
                    },
                },
                .i64 => switch (arg_type) {
                    .i32 => Value{ .i64 = @as(i64, arg.i32) },
                    .f32 => Value{ .i64 = @as(i64, @intFromFloat(arg.f32)) },
                    .f64 => Value{ .i64 = @as(i64, @intFromFloat(arg.f64)) },
                    else => {
                        oe.log("Cannot convert {s} to i64", .{@tagName(arg_type)});
                        return Error.TypeMismatch;
                    },
                },
                .f32 => switch (arg_type) {
                    .i32 => Value{ .f32 = @as(f32, @floatFromInt(arg.i32)) },
                    .i64 => Value{ .f32 = @as(f32, @floatFromInt(arg.i64)) },
                    .f64 => Value{ .f32 = @as(f32, @floatCast(arg.f64)) },
                    else => {
                        oe.log("Cannot convert {s} to f32", .{@tagName(arg_type)});
                        return Error.TypeMismatch;
                    },
                },
                .f64 => switch (arg_type) {
                    .i32 => Value{ .f64 = @as(f64, @floatFromInt(arg.i32)) },
                    .i64 => Value{ .f64 = @as(f64, @floatFromInt(arg.i64)) },
                    .f32 => Value{ .f64 = @as(f64, arg.f32) },
                    else => {
                        oe.log("Cannot convert {s} to f64", .{@tagName(arg_type)});
                        return Error.TypeMismatch;
                    },
                },
                else => {
                    oe.log("Cannot convert to {s}", .{@tagName(param_type)});
                    return Error.TypeMismatch;
                },
            };

            oe.log("Converted value: {any}", .{converted_value});
            try locals_env.append(self.allocator, converted_value);
        }
    }

    // Initialize declared locals to zero values
    if (func.locals.len > 0) {
        for (func.locals) |lt| {
            const zero: Value = switch (lt) {
                .i32 => .{ .i32 = 0 },
                .i64 => .{ .i64 = 0 },
                .f32 => .{ .f32 = 0.0 },
                .f64 => .{ .f64 = 0.0 },
                .v128 => .{ .v128 = [_]u8{0} ** 16 },
                .funcref => .{ .funcref = null },
                .externref => .{ .externref = null },
                .block => .{ .block = {} },
            };
            try locals_env.append(self.allocator, zero);
        }
    }

    // Initialize control flow stack for blocks and loops, pre-sized from summary if available
    var block_stack = try std.ArrayList(Block).initCapacity(self.allocator, 0);
    if (self.function_summary.get(func_index)) |s| {
        try block_stack.ensureTotalCapacity(self.allocator, s.block_count + 4);
    }
    defer block_stack.deinit(self.allocator);

    // Execute function code
    var code_reader = Module.Reader.init(func.code);
    while (code_reader.pos < func.code.len) : ({}) {
        const opcode = try code_reader.readByte();
        self.last_opcode = opcode;
        self.last_pos = code_reader.pos - 1;
        if (self.debug) {
            std.debug.print("[wx] op 0x{X:0>2} at {d}, stack={d}\n", .{ opcode, self.last_pos, self.stack.items.len });
        }
        oe.log("  Executing opcode 0x{X:0>2} at pos {d} (stack size: {d})", .{
            opcode, code_reader.pos - 1, self.stack.items.len,
        });

        // Debugging: Show next few bytes to help diagnose instruction parsing
        if (code_reader.pos < func.code.len) {
            const end_pos = @min(code_reader.pos + 4, func.code.len);
            oe.log("  Next bytes: ", .{});
            for (code_reader.pos..end_pos) |i| {
                oe.log("0x{X:0>2} ", .{func.code[i]});
            }
            oe.log("\n", .{});
        }

        // Special handling for type marker opcodes and other block result types
        // These are WebAssembly type markers that should only appear as parameters
        // to control instructions, but they might be encountered directly
        if (opcode == 0x7F or opcode == 0x7E or opcode == 0x7D or
            opcode == 0x7C or opcode == 0x70 or opcode == 0x6F or opcode == 0x40)
        {
            const type_name = switch (opcode) {
                0x7F => "i32",
                0x7E => "i64",
                0x7D => "f32",
                0x7C => "f64",
                0x70 => "funcref",
                0x6F => "externref",
                0x40 => "void",
                else => unreachable,
            };
            var o = Log.op("type_marker", type_name);
            o.log("Treating type marker (0x{X:0>2}) as a no-op", .{opcode});
            continue;
        }

        const op_match = Op.match(opcode) orelse {
            std.debug.print("Unknown opcode 0x{X:0>2} at pos {d}\n", .{ opcode, code_reader.pos - 1 });
            return Error.InvalidOpcode;
        };

        switch (op_match) {
            .throw => |t| switch (t) {
                .@"try" => {
                    var o = Log.op("try", "");
                    o.log("Starting try block", .{});

                    // Read block type - similar to if/block/loop
                    const bt = try code_reader.readByte();

                    // Track the try block on the block stack
                    const try_pos = code_reader.pos - 2; // Position of the try opcode
                    try self.block_stack.append(self.allocator, .{
                        .type = .@"try",
                        .pos = try_pos,
                        .start_stack_size = self.stack.items.len,
                    });

                    // Handle block type like we do for other blocks
                    if (bt == 0x40) {
                        // Empty (void) result type
                        o.log("  Try block with void result type", .{});
                    } else if (bt >= 0x7C and bt <= 0x7F) {
                        // Value type result
                        const vt = switch (bt) {
                            0x7F => ValueType.i32,
                            0x7E => ValueType.i64,
                            0x7D => ValueType.f32,
                            0x7C => ValueType.f64,
                            else => {
                                o.log("  Unknown value type: 0x{X:0>2}", .{bt});
                                return Error.InvalidOpcode;
                            },
                        };
                        o.log("  Try block with result type: {s}", .{@tagName(vt)});
                        self.block_stack.items[self.block_stack.items.len - 1].result_type = vt;
                    } else {
                        // Function type index
                        o.log("  Try block with function type index: {d}", .{bt});
                        return Error.InvalidOpcode; // Not implemented
                    }
                },
                .@"catch" => {
                    var o = Log.op("catch", "");
                    o.log("Handling catch block", .{});

                    // Get the tag/exception index
                    const tag_idx = try code_reader.readLEB128();
                    o.log("  Catch tag index: {d}", .{tag_idx});

                    // Find the matching try block
                    if (self.block_stack.items.len == 0) {
                        o.log("  Error: No try block on stack for catch", .{});
                        return Error.InvalidOpcode;
                    }

                    var block_idx = self.block_stack.items.len;
                    var found_try = false;
                    while (block_idx > 0) {
                        block_idx -= 1;
                        if (self.block_stack.items[block_idx].type == .@"try") {
                            found_try = true;
                            break;
                        }
                    }

                    if (!found_try) {
                        o.log("  Error: No matching try block found for catch", .{});
                        return Error.InvalidOpcode;
                    }

                    // Record the catch position in the try block
                    self.block_stack.items[block_idx].else_pos = code_reader.pos - 2;

                    // Execute catch logic - in actual implementation, would check if
                    // current exception matches the tag_idx
                    o.log("  Processing catch for try block at position {d}", .{self.block_stack.items[block_idx].pos});
                },
                .throw => {
                    var o = Log.op("throw", "");

                    // Get the tag/exception index
                    const tag_idx = try code_reader.readLEB128();
                    o.log("Throwing exception with tag index: {d}", .{tag_idx});

                    // Pop exception value from stack
                    if (self.stack.items.len < 1) {
                        o.log("  Stack underflow: throw needs an exception value", .{});
                        return Error.StackUnderflow;
                    }

                    const exception_value = self.stack.pop().?;
                    o.log("  Exception value: {any}", .{exception_value});

                    // In full implementation: look for catch blocks that can handle this exception
                    // For now, we'll just return an error
                    o.log("  Unhandled exception with tag {d}", .{tag_idx});
                    return Error.InvalidAccess;
                },
                .rethrow => {
                    var o = Log.op("rethrow", "");
                    o.log("Rethrowing current exception", .{});

                    // Get the relative depth of the catch block
                    const relative_depth = try code_reader.readLEB128();
                    o.log("  Rethrow from catch block at depth: {d}", .{relative_depth});

                    // Find the catch block at the specified depth
                    if (relative_depth >= self.block_stack.items.len) {
                        o.log("  Invalid catch depth for rethrow", .{});
                        return Error.InvalidOpcode;
                    }

                    // In full implementation: would get the current exception and rethrow it
                    o.log("  Rethrowing exception (not fully implemented)", .{});
                    return Error.InvalidAccess;
                },
                .catch_all => {
                    var o = Log.op("catch_all", "");
                    o.log("Handling catch_all block", .{});

                    // Find the matching try block
                    if (self.block_stack.items.len == 0) {
                        o.log("  Error: No try block on stack for catch_all", .{});
                        return Error.InvalidOpcode;
                    }

                    var block_idx = self.block_stack.items.len;
                    var found_try = false;
                    while (block_idx > 0) {
                        block_idx -= 1;
                        if (self.block_stack.items[block_idx].type == .@"try") {
                            found_try = true;
                            break;
                        }
                    }

                    if (!found_try) {
                        o.log("  Error: No matching try block found for catch_all", .{});
                        return Error.InvalidOpcode;
                    }

                    // Record the catch_all position in the try block
                    self.block_stack.items[block_idx].else_pos = code_reader.pos - 2;

                    // Execute catch_all logic
                    o.log("  Processing catch_all for try block at position {d}", .{self.block_stack.items[block_idx].pos});
                },
                .throw_ref => {
                    var o = Log.op("throw_ref", "");
                    o.log("Throwing exception reference", .{});

                    // Pop exception reference from stack
                    if (self.stack.items.len < 1) {
                        o.log("  Stack underflow: throw_ref needs an exception reference", .{});
                        return Error.StackUnderflow;
                    }

                    const exception_ref = self.stack.pop().?;
                    o.log("  Exception reference: {any}", .{exception_ref});

                    // In full implementation: look for catch blocks that can handle this exception
                    // For now, we'll just return an error
                    o.log("  Unhandled exception reference", .{});
                    return Error.InvalidAccess;
                },
            },
            .memory => |m| switch (m) {
                .size => {
                    var o = Log.op("memory", "size");
                    o.log("", .{});

                    if (module.memory == null) {
                        print("Memory not initialized", .{}, Color.red);
                        return Error.InvalidAccess;
                    }

                    // Calculate current number of pages (64KB per page)
                    const page_size: usize = 65536;
                    const current_pages = module.memory.?.len / page_size;

                    o.log("Memory size: {d} pages ({d} bytes)", .{
                        current_pages, module.memory.?.len,
                    });

                    // Push page count to stack
                    try self.stack.append(self.allocator, .{ .i32 = @intCast(current_pages) });
                },
                .grow => {
                    var o = Log.op("memory", "grow");
                    o.log("", .{});

                    if (self.stack.items.len < 1) {
                        print("Stack underflow: memory.grow needs a page count", .{}, Color.red);
                        return Error.StackUnderflow;
                    }

                    const pages = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(pages.?)) != .i32) {
                        print("Type mismatch: memory.grow expects i32 page count, got {s}", .{@tagName(std.meta.activeTag(pages.?))}, Color.red);
                        return Error.TypeMismatch;
                    }

                    if (module.memory == null) {
                        print("Memory not initialized", .{}, Color.red);
                        return Error.InvalidAccess;
                    }

                    // Calculate current number of pages (64KB per page)
                    const page_size: usize = 65536;
                    const current_pages = module.memory.?.len / page_size;

                    // Check if page count is negative
                    if (pages.?.i32 < 0) {
                        print("Cannot grow memory by negative pages: {d}", .{pages.?.i32}, Color.red);
                        // Return -1 to indicate failure
                        try self.stack.append(self.allocator, .{ .i32 = -1 });
                        return Error.MemoryGrowLimitReached;
                    }

                    // Calculate new memory size
                    const new_pages = current_pages + @as(usize, @intCast(pages.?.i32));
                    const max_pages: usize = 65536; // 4GB limit (maximum addressable in 32-bit)

                    if (new_pages > max_pages) {
                        print("Memory growth limit reached: {d} + {d} > {d}", .{
                            current_pages, pages.?.i32, max_pages,
                        }, Color.red);
                        // Return -1 to indicate failure
                        try self.stack.append(self.allocator, .{ .i32 = -1 });
                        return Error.MemoryGrowLimitReached;
                    }

                    const new_size = new_pages * page_size;
                    o.log("Growing memory from {d} to {d} pages ({d} to {d} bytes)", .{
                        current_pages, new_pages, module.memory.?.len, new_size,
                    });

                    // Allocate new memory
                    const new_memory = try module.allocator.alloc(u8, new_size);

                    // Copy old memory contents
                    @memcpy(new_memory[0..module.memory.?.len], module.memory.?);

                    // Zero-initialize new memory
                    @memset(new_memory[module.memory.?.len..], 0);

                    // Free old memory
                    module.allocator.free(module.memory.?);

                    // Update module memory
                    module.memory = new_memory;

                    // Return old page count
                    try self.stack.append(self.allocator, .{ .i32 = @intCast(current_pages) });
                },
            },
            .f32 => |float32| switch (float32) {
                .@"const" => {
                    const bytes = try code_reader.readBytes(4);
                    const bits = std.mem.readInt(u32, bytes[0..4], .little);
                    const v: f32 = @bitCast(bits);
                    try self.stack.append(self.allocator, .{ .f32 = v });
                },
                .store => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32 or @as(ValueType, std.meta.activeTag(v.?)) != .f32)
                        return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const bits: u32 = @bitCast(v.?.f32);
                    try self.writeLittle(u32, ea, bits);
                },
                .load => {
                    _ = try code_reader.readLEB128();
                    const offset = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr_val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr_val.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr_val.?.i32, offset);
                    const bits = try self.readLittle(u32, ea);
                    const loaded_value: f32 = @bitCast(bits);
                    try self.stack.append(self.allocator, .{ .f32 = loaded_value });
                },
                .convert_i32_u => {
                    var o = Log.op("f32", "convert_i32_u");
                    o.log("", .{});
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i32) return Error.TypeMismatch;
                    try self.stack.append(self.allocator, .{ .f32 = @as(f32, @floatFromInt(@as(u32, @bitCast(val.?.i32)))) });
                },
                .convert_i32_s => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i32) return Error.TypeMismatch;
                    try self.stack.append(self.allocator, .{ .f32 = @as(f32, @floatFromInt(val.?.i32)) });
                    
                    var o = Log.op("f32", "convert_i32_s");
                    o.log("convert_i32_s({d}) = {d}", .{ val.?.i32, @as(f32, @floatFromInt(val.?.i32)) });
                },
                .convert_i64_s => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i64) return Error.TypeMismatch;
                    try self.stack.append(self.allocator, .{ .f32 = @as(f32, @floatFromInt(val.?.i64)) });
                    
                    var o = Log.op("f32", "convert_i64_s");
                    o.log("convert_i64_s({d}) = {d}", .{ val.?.i64, @as(f32, @floatFromInt(val.?.i64)) });
                },
                .convert_i64_u => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i64) return Error.TypeMismatch;
                    const uval = @as(u64, @bitCast(val.?.i64));
                    try self.stack.append(self.allocator, .{ .f32 = @as(f32, @floatFromInt(uval)) });
                    
                    var o = Log.op("f32", "convert_i64_u");
                    o.log("convert_i64_u({d}) = {d}", .{ uval, @as(f32, @floatFromInt(uval)) });
                },
                .demote_f64 => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .f64) return Error.TypeMismatch;
                    try self.stack.append(self.allocator, .{ .f32 = @as(f32, @floatCast(val.?.f64)) });
                    
                    var o = Log.op("f32", "demote_f64");
                    o.log("demote_f64({d}) = {d}", .{ val.?.f64, @as(f32, @floatCast(val.?.f64)) });
                },
                // Comparison operations
                .eq => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 == b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "eq");
                    o.log("{d} == {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                .ne => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 != b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "ne");
                    o.log("{d} != {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                .lt => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 < b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "lt");
                    o.log("{d} < {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                .gt => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 > b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "gt");
                    o.log("{d} > {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                .le => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 <= b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "le");
                    o.log("{d} <= {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                .ge => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.f32 >= b.?.f32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("f32", "ge");
                    o.log("{d} >= {d} -> {d}", .{ a.?.f32, b.?.f32, result });
                },
                // Math operations
                .abs => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @abs(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "abs");
                    o.log("abs({d}) = {d}", .{ a.?.f32, result });
                },
                .neg => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = -a.?.f32;
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "neg");
                    o.log("neg({d}) = {d}", .{ a.?.f32, result });
                },
                .ceil => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @ceil(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "ceil");
                    o.log("ceil({d}) = {d}", .{ a.?.f32, result });
                },
                .floor => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @floor(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "floor");
                    o.log("floor({d}) = {d}", .{ a.?.f32, result });
                },
                .trunc => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @trunc(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "trunc");
                    o.log("trunc({d}) = {d}", .{ a.?.f32, result });
                },
                .nearest => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @round(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "nearest");
                    o.log("nearest({d}) = {d}", .{ a.?.f32, result });
                },
                .sqrt => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @sqrt(a.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "sqrt");
                    o.log("sqrt({d}) = {d}", .{ a.?.f32, result });
                },
                .add => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = a.?.f32 + b.?.f32;
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "add");
                    o.log("{d} + {d} = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .sub => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = a.?.f32 - b.?.f32;
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "sub");
                    o.log("{d} - {d} = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .mul => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = a.?.f32 * b.?.f32;
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "mul");
                    o.log("{d} * {d} = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .div => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = a.?.f32 / b.?.f32;
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "div");
                    o.log("{d} / {d} = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .min => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @min(a.?.f32, b.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "min");
                    o.log("min({d}, {d}) = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .max => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = @max(a.?.f32, b.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "max");
                    o.log("max({d}, {d}) = {d}", .{ a.?.f32, b.?.f32, result });
                },
                .copysign => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    const result = std.math.copysign(a.?.f32, b.?.f32);
                    try self.stack.append(self.allocator, .{ .f32 = result });
                    
                    var o = Log.op("f32", "copysign");
                    o.log("copysign({d}, {d}) = {d}", .{ a.?.f32, b.?.f32, result });
                },
                // f32.const handled earlier in this switch
            },
            .control => |ctrl_op| switch (ctrl_op) {
                .@"unreachable" => {}, // unreachable - TODO: implement
                .nop => {}, // nop
                .block => {
                    const block = try code_reader.readByte();
                    var o = Log.op("block", "");
                    o.log("block type=0x{X:0>2}", .{block});

                    // Parse block type to determine result type
                    var result_type: ?ValueType = null;
                    if (block != 0x40) { // 0x40 is void type
                        result_type = try ValueType.fromByte(block);
                        o.log("  Block result type: {s}", .{@tagName(result_type.?)});
                    }

                    try block_stack.append(self.allocator, .{
                        .type = .block,
                        .pos = code_reader.pos,
                        .start_stack_size = self.stack.items.len,
                        .result_type = result_type,
                    });

                    o.log("  Block start at {d}, stack size {d}", .{ code_reader.pos, self.stack.items.len });
                },
                .loop => {
                    const block = try code_reader.readByte();
                    var o = Log.op("loop", "");
                    o.log("loop type=0x{X:0>2}", .{block});

                    // Parse block type to determine result type
                    var result_type: ?ValueType = null;
                    if (block != 0x40) { // 0x40 is void type
                        result_type = try ValueType.fromByte(block);
                        o.log("  Loop result type: {s}", .{@tagName(result_type.?)});
                    }

                    try block_stack.append(self.allocator, .{
                        .type = .loop,
                        .pos = code_reader.pos,
                        .start_stack_size = self.stack.items.len,
                        .result_type = result_type,
                    });

                    o.log("  Loop start at {d}, stack size {d}", .{ code_reader.pos, self.stack.items.len });
                },
                .@"if" => {
                    if (self.stack.items.len < 1) {
                        oe.log("Stack underflow: if instruction needs a condition value, stack is empty", .{});
                        return Error.StackUnderflow;
                    }

                    const condition_opt = self.stack.pop();
                    const condition = condition_opt.?; // Safe to unwrap since we checked stack size

                    if (@as(ValueType, std.meta.activeTag(condition)) != .i32) {
                        oe.log("Type mismatch: if instruction expects i32 condition, got {s}", .{@tagName(std.meta.activeTag(condition))});
                        return Error.TypeMismatch;
                    }

                    var o = Log.op("if", "");
                    o.log("Condition: {d}", .{condition.i32});

                    // Read block type
                    const bt = try code_reader.readByte();

                    // Get result type if any
                    var result_type: ?ValueType = null;
                    if (bt == 0x40) {
                        // Empty (void) result type
                        o.log("  if block with void result type", .{});
                    } else if (bt >= 0x7C and bt <= 0x7F) {
                        // Value type result
                        result_type = switch (bt) {
                            0x7F => ValueType.i32,
                            0x7E => ValueType.i64,
                            0x7D => ValueType.f32,
                            0x7C => ValueType.f64,
                            else => {
                                o.log("  Unknown value type: 0x{X:0>2}", .{bt});
                                return Error.InvalidOpcode;
                            },
                        };
                        o.log("  if block with result type: {s}", .{@tagName(result_type.?)});
                    } else {
                        // Function type index
                        o.log("  if block with function type index: {d}", .{bt});
                        return Error.InvalidOpcode; // Not implemented
                    }

                    // Save the if position
                    const if_pos = code_reader.pos - 2; // Position of the if opcode

                    // Add block to stack
                    const block_idx = block_stack.items.len;
                    try block_stack.append(self.allocator, .{
                        .type = .@"if",
                        .pos = if_pos,
                        .start_stack_size = self.stack.items.len,
                        .result_type = result_type,
                    });

                    // Register block in position map
                    try self.registerBlock(if_pos, block_idx);

                    if (condition.i32 == 0) {
                        // Condition is false, skip to else or end
                        o.log("  Condition is false, skipping to else or end", .{});
                        if (try self.findElseOrEnd(func, &code_reader, code_reader.pos)) |res| {
                            if (res.else_pos) |ep| {
                                // Jump to code just after else opcode
                                block_stack.items[block_idx].else_pos = ep;
                                code_reader.pos = ep + 1;
                            } else {
                                block_stack.items[block_idx].end_pos = res.end_pos;
                                code_reader.pos = res.end_pos + 1;
                            }
                        } else {
                            // No else/end found; bail to end of function
                            code_reader.pos = func.code.len;
                        }
                    } else {
                        o.log("  Condition is true, executing if block", .{});
                        // Optionally pre-compute the end position for later use
                        _ = try self.findMatchingEnd(func, &code_reader, if_pos, .@"if");
                    }
                },
                .@"else" => {
                    // Else reached after executing true-branch: skip to matching end
                    var tmp = Module.Reader.init(func.code);
                    tmp.pos = code_reader.pos;
                    var depth: usize = 1;
                    while (depth > 0 and tmp.pos < func.code.len) {
                        const op = try tmp.readByte();
                        if (op == 0x02 or op == 0x03 or op == 0x04) {
                            depth += 1;
                            const bt = try tmp.readByte();
                            if (bt != 0x40 and bt != 0x7F and bt != 0x7E and bt != 0x7D and bt != 0x7C) {
                                _ = try tmp.readLEB128();
                            }
                        } else if (op == 0x0B) {
                            depth -= 1;
                        } else {
                            skipInstruction(&tmp) catch {};
                        }
                    }
                    code_reader.pos = tmp.pos;
                },
                .end => {
                    if (block_stack.items.len == 0) {
                        // End of function
                        var o = Log.op("end", "end");
                        o.log("  End of function", .{});
                        break;
                    }

                    var o = Log.op("end", "");
                    const block = block_stack.pop(); // Change: Pop first to get block info
                    o.log("  Ending block of type {s}", .{@tagName(block.?.type)});

                    // Detailed debugging information
                    o.log("  Block started at position {d}, stack size was {d}", .{ block.?.pos, block.?.start_stack_size });

                    if (block.?.result_type != null) {
                        o.log("  Block has result type {s}", .{@tagName(block.?.result_type.?)});
                    }

                    o.log("  Current stack size: {d}", .{self.stack.items.len});

                    // If block has a result type, ensure we have a value
                    var result_value: ?Value = null;
                    if (block.?.result_type != null) {
                        if (self.stack.items.len > 0) {
                            result_value = self.stack.pop();
                            o.log("  Preserving result value from stack: {any}", .{result_value.?});
                        } else {
                            // No value on stack, use default value as a recovery mechanism
                            const default_val: Value = switch (block.?.result_type.?) {
                                .i32 => .{ .i32 = 0 },
                                .i64 => .{ .i64 = 0 },
                                .f32 => .{ .f32 = 0.0 },
                                .f64 => .{ .f64 = 0.0 },
                                .funcref => .{ .funcref = null },
                                .externref => .{ .externref = null },
                                else => return Error.TypeMismatch,
                            };
                            result_value = default_val;
                            o.log("  Using default value for result type {s}: {any}", .{ @tagName(block.?.result_type.?), default_val });
                        }
                    }

                    // Restore stack to the size before the block, plus the result value if any
                    const target_stack_size = block.?.start_stack_size;

                    // Safety check - don't attempt to pop beyond zero
                    if (self.stack.items.len > target_stack_size) {
                        // Remove any extra values that were pushed during block execution
                        const to_pop = self.stack.items.len - target_stack_size;
                        o.log("  Removing {d} extra items from stack", .{to_pop});

                        for (0..to_pop) |_| {
                            _ = self.stack.pop();
                        }
                    } else if (self.stack.items.len < target_stack_size) {
                        // Stack underflow - missing values, recover by adding zeroes
                        const to_push = target_stack_size - self.stack.items.len;
                        o.log("  Stack underflow, adding {d} default values", .{to_push});

                        for (0..to_push) |_| {
                            try self.stack.append(self.allocator, .{ .i32 = 0 });
                        }
                    }

                    // Add back the result value if there is one
                    if (result_value != null) {
                        try self.stack.append(self.allocator, result_value.?);
                        o.log("  Restored result value to stack: {any}", .{result_value.?});
                    }

                    o.log("  Final stack size after block end: {d}", .{self.stack.items.len});
                },
            },
            .branch => |f| switch (f) {
                .br => {
                    const label_idx = try code_reader.readLEB128();
                    var o = Log.op("br", "");
                    var e = Log.err("invalid branch", "target");
                    o.log("{d} at pos {d}", .{ label_idx, code_reader.pos - 1 });

                    if (label_idx >= block_stack.items.len) {
                        e.log("Invalid branch target: {d}", .{label_idx});
                        return Error.InvalidAccess;
                    }

                    // Calculate which block to branch to (from the end of the list)
                    const target_idx = block_stack.items.len - 1 - label_idx;
                    const target = block_stack.items[target_idx];

                    o.log("  br target type: {s}", .{@tagName(target.type)});
                    o.log("  br target position: {d}", .{target.pos});
                    o.log("  br target stack size: {d}", .{target.start_stack_size});

                    if (target.type == .loop) {
                        // For loops, branch to the beginning of the loop
                        code_reader.pos = target.pos;
                        o.log("  br branching to loop start at {d}", .{target.pos});
                        // Pop blocks up to but not including the target loop
                        while (block_stack.items.len - 1 > target_idx) {
                            o.log("  Popping block of type {s}\n", .{@tagName(block_stack.items[block_stack.items.len - 1].type)});
                            _ = block_stack.pop();
                        }
                        continue;
                    }

                    // For blocks and ifs, preserve result value if needed
                    var result_value: ?Value = null;
                    if (target.result_type != null and self.stack.items.len > 0) {
                        result_value = self.stack.pop();
                        o.log("  Preserving result value for block: {any}", .{result_value.?});
                    }

                    // Restore stack to block's starting size
                    while (self.stack.items.len > target.start_stack_size) {
                        _ = self.stack.pop();
                    }

                    // Push back result value if we had one
                    if (result_value != null) {
                        try self.stack.append(self.allocator, result_value.?);
                        o.log("  Restored result value to stack", .{});
                    }

                    // Search for the end instruction if we haven't found it yet
                    if (target.end_pos == null) {
                        var depth: usize = 0;
                        var search_pos = target.pos;
                        var found_target = false;

                        o.log("  Searching for end instruction starting at {d}\n", .{search_pos});
                        var found_end: bool = false;

                        // Initialize depth to 1 since we're already inside the target block
                        depth = 1;
                        found_target = true;

                        while (search_pos < func.code.len) {
                            const op = func.code[search_pos];
                            search_pos += 1;

                            switch (op) {
                                0x02, 0x03, 0x04 => { // block, loop, if
                                    depth += 1;
                                    o.log("      Found nested block/loop/if, depth now {d}\n", .{depth});

                                    // Skip block type byte
                                    if (search_pos < func.code.len) {
                                        const block_type = func.code[search_pos];
                                        search_pos += 1;
                                        // Handle extended block types if needed
                                        if (block_type != 0x40 and block_type != 0x7F and
                                            block_type != 0x7E and block_type != 0x7D and
                                            block_type != 0x7C)
                                        {
                                            // Extended block type - need to read LEB128
                                            var leb_pos = search_pos;
                                            var leb_byte: u8 = 0;
                                            // Skip the LEB128 bytes
                                            while (leb_pos < func.code.len) {
                                                leb_byte = func.code[leb_pos];
                                                leb_pos += 1;
                                                // If highest bit is not set, this is the last byte
                                                if ((leb_byte & 0x80) == 0) break;
                                            }
                                            search_pos = leb_pos;
                                        }
                                    }
                                },
                                0x05 => { // else
                                    // 'else' doesn't change the nesting depth for target purposes
                                    o.log("      Found else, depth remains {d}\n", .{depth});
                                },
                                0x0b => { // end
                                    depth -= 1;
                                    o.log("      Found end, depth now {d}\n", .{depth});
                                    if (depth == 0) {
                                        block_stack.items[target_idx].end_pos = search_pos;
                                        o.log("      Found matching end at {d} for block at {d}\n", .{ search_pos, target.pos });
                                        found_end = true;
                                        break;
                                    }
                                },
                                else => {
                                    // Skip unknown opcodes during scanning
                                },
                            }

                            // Break the loop if we've found the end
                            if (found_end) break;
                        }

                        // If we reached the end of function code without finding matching end
                        if (!found_end) {
                            // For br_if inside nested blocks, this can sometimes happen if we're branching
                            // across function boundaries. Instead of failing, use the end of function as the end pos.
                            block_stack.items[target_idx].end_pos = func.code.len;
                            o.log("      Using end of function ({d}) as end position for block at {d}\n", .{ func.code.len, target.pos });
                            found_end = true;
                        }
                    }

                    if (target.end_pos) |end_pos| {
                        // Move past the end instruction
                        const func_idx = try code_reader.readLEB128();
                        // var oe = Log.op("call", "");
                        var ee = Log.err("call", "function");
                        oe.log("{d}", .{func_idx});

                        if (func_idx >= module.functions.items.len) {
                            ee.log("Invalid function index: {d}", .{func_idx});
                            return Error.InvalidAccess;
                        }

                        const called_func = module.functions.items[func_idx];
                        const called_type = module.types.items[called_func.type_index];

                        // Check if we have enough arguments on the stack
                        if (self.stack.items.len < called_type.params.len) {
                            ee.log("Stack underflow: not enough arguments for function call", .{});
                            return Error.StackUnderflow;
                        }

                        // Prepare arguments
                        var call_args = try self.allocator.alloc(Value, called_type.params.len);
                        defer self.allocator.free(call_args);

                        // Pop arguments in reverse order
                        var i: usize = called_type.params.len;
                        while (i > 0) {
                            i -= 1;
                            call_args[i] = self.stack.pop().?;
                        }

                        // Call the function
                        const result = try self.executeFunction(func_idx, call_args);

                        // If the function returns a value, push it onto the stack
                        if (called_type.results.len > 0) {
                            try self.stack.append(self.allocator, result);
                        }
                        code_reader.pos = end_pos + 1;
                        o.log("  br branching past end at {d}\n", .{end_pos + 1});
                        // Pop all blocks up to and including the target
                        while (block_stack.items.len > target_idx) {
                            o.log("  Popping block of type {s}\n", .{@tagName(block_stack.items[block_stack.items.len - 1].type)});
                            _ = block_stack.pop();
                        }
                    }
                },
                .br_if => {
                    const label_idx = try code_reader.readLEB128();
                    var o_br_if = Log.op("br_if", "");

                    if (self.stack.items.len < 1) {
                        o_br_if.log("Stack underflow: Need 1 value for condition, stack is empty", .{});
                        return Error.StackUnderflow;
                    }

                    const condition_opt = self.stack.pop();
                    const condition = condition_opt.?; // Safe to unwrap since we checked stack size

                    if (@as(ValueType, std.meta.activeTag(condition)) != .i32) {
                        o_br_if.log("Type mismatch: Expected i32 for condition, got {s}", .{@tagName(std.meta.activeTag(condition))});
                        return Error.TypeMismatch;
                    }

                    o_br_if.log("  br_if condition value: {d}", .{condition.i32});
                    o_br_if.log("  br_if stack size before: {d}", .{self.stack.items.len});

                    if (condition.i32 != 0) {
                        if (label_idx >= block_stack.items.len) {
                            o_br_if.log("Invalid branch target: {d}", .{label_idx});
                            return Error.InvalidAccess;
                        }

                        // Calculate which block to branch to (from the end of the list)
                        const target_idx = block_stack.items.len - 1 - label_idx;
                        const target = block_stack.items[target_idx];

                        o_br_if.log("  br_if target type: {s}", .{@tagName(target.type)});
                        o_br_if.log("  br_if target position: {d}", .{target.pos});
                        o_br_if.log("  br_if target stack size: {d}", .{target.start_stack_size});

                        if (target.type == .loop) {
                            // For loops, branch to the beginning of the loop
                            code_reader.pos = target.pos;
                            o_br_if.log("  br_if branching to loop start at {d}", .{target.pos});
                            // Pop blocks up to but not including the target loop
                            while (block_stack.items.len - 1 > target_idx) {
                                o_br_if.log("  Popping block of type {s}\n", .{@tagName(block_stack.items[block_stack.items.len - 1].type)});
                                _ = block_stack.pop();
                            }
                            continue;
                        }

                        // For blocks and ifs, preserve result value if needed
                        var result_value: ?Value = null;
                        if (target.result_type != null and self.stack.items.len > 0) {
                            result_value = self.stack.pop();
                            o_br_if.log("  Preserving result value for block: {any}", .{result_value.?});
                        }

                        // Restore stack to block's starting size
                        while (self.stack.items.len > target.start_stack_size) {
                            _ = self.stack.pop();
                        }

                        // Push back result value if we had one
                        if (result_value != null) {
                            try self.stack.append(self.allocator, result_value.?);
                            o_br_if.log("  Restored result value to stack", .{});
                        }

                        // Search for the end instruction if we haven't found it yet
                        if (target.end_pos == null) {
                            var depth: usize = 0;
                            var search_pos = target.pos;
                            var found_target = false;

                            o_br_if.log("  Searching for end instruction starting at {d}\n", .{search_pos});
                            var found_end: bool = false;

                            // Initialize depth to 1 since we're already inside the target block
                            depth = 1;
                            found_target = true;

                            while (search_pos < func.code.len) {
                                const op = func.code[search_pos];
                                search_pos += 1;

                                switch (op) {
                                    0x02, 0x03, 0x04 => { // block, loop, if
                                        var o_block = Log.op("block", "");
                                        depth += 1;
                                        o_block.log("      Found nested block/loop/if, depth now {d}\n", .{depth});

                                        // Skip block type byte
                                        if (search_pos < func.code.len) {
                                            const block_type = func.code[search_pos];
                                            search_pos += 1;
                                            // Handle extended block types if needed
                                            if (block_type != 0x40 and block_type != 0x7F and
                                                block_type != 0x7E and block_type != 0x7D and
                                                block_type != 0x7C)
                                            {
                                                // Extended block type - need to read LEB128
                                                var leb_pos = search_pos;
                                                var leb_byte: u8 = 0;
                                                // Skip the LEB128 bytes
                                                while (leb_pos < func.code.len) {
                                                    leb_byte = func.code[leb_pos];
                                                    leb_pos += 1;
                                                    // If highest bit is not set, this is the last byte
                                                    if ((leb_byte & 0x80) == 0) break;
                                                }
                                                search_pos = leb_pos;
                                            }
                                        }
                                    },
                                    0x05 => { // else
                                        var o_else = Log.op("else", "");
                                        // 'else' doesn't change the nesting depth for target purposes
                                        o_else.log("      Found else, depth remains {d}\n", .{depth});
                                    },
                                    0x0b => { // end
                                        depth -= 1;
                                        var o_end = Log.op("end", "");
                                        o_end.log("      Found end, depth now {d}\n", .{depth});
                                        if (depth == 0) {
                                            block_stack.items[target_idx].end_pos = search_pos;
                                            o_end.log("      Found matching end at {d} for block at {d}\n", .{ search_pos, target.pos });
                                            found_end = true;
                                            break;
                                        }
                                    },
                                    else => {
                                        // Skip unknown opcodes during scanning
                                    },
                                }

                                // Break the loop if we've found the end
                                if (found_end) break;
                            }

                            // If we reached the end of function code without finding matching end
                            if (!found_end) {
                                // For br_if inside nested blocks, this can sometimes happen if we're branching
                                // across function boundaries. Instead of failing, use the end of function as the end pos.
                                block_stack.items[target_idx].end_pos = func.code.len;
                                o_br_if.log("      Using end of function ({d}) as end position for block at {d}\n", .{ func.code.len, target.pos });
                                found_end = true;
                            }
                        }

                        if (target.end_pos) |end_pos| {
                            // Move past the end instruction
                            code_reader.pos = end_pos + 1;
                            o_br_if.log("  br_if branching past end at {d}\n", .{end_pos + 1});

                            // Pop all blocks up to and including the target
                            while (block_stack.items.len > target_idx) {
                                o_br_if.log("  Popping block of type {s}\n", .{@tagName(block_stack.items[block_stack.items.len - 1].type)});
                                _ = block_stack.pop();
                            }
                        }
                    }
                },
                .br_table => {
                    var o = Log.op("br_table", "");
                    o.log("", .{});
                },
                .br_on_non_null => {
                    var o = Log.op("br_on_non_null", "");
                    o.log("", .{});
                },
                .br_on_null => {
                    var o = Log.op("br_on_null", "");
                    o.log("", .{});
                },
            },
            .@"return" => |f| switch (f) {
                .@"return" => {
                    var o = Log.op("return", "return");
                    o.log("return", .{});

                    // For return, we need to preserve any return value on the stack
                    var return_value: ?Value = null;
                    if (func_type.results.len > 0 and self.stack.items.len > 0) {
                        return_value = self.stack.pop();

                        // Verify return value type matches function result type
                        const val_type = @as(ValueType, std.meta.activeTag(return_value.?));
                        if (val_type != func_type.results[0]) {
                            print("Type mismatch: function expects {s} result, got {s}", .{
                                @tagName(func_type.results[0]),
                                @tagName(val_type),
                            }, Color.red);
                            return Error.TypeMismatch;
                        }
                    }

                    // Clear the stack
                    self.stack.shrinkRetainingCapacity(0);

                    // If we have a return value, push it back
                    if (return_value != null) {
                        try self.stack.append(self.allocator, return_value.?);
                    }

                    // Set position to end of function
                    code_reader.pos = func.code.len;
                },
                .return_call => {},
                .return_call_indirect => {},
                .return_call_ref => {},
            },
            .call => |c| switch (c) {
                .call_indirect => {
                    var o = Log.op("call_indirect", "");
                    o.log("", .{});
                },
                .call_ref => {
                    var o = Log.op("call_ref", "");
                    o.log("", .{});
                },
                .drop => {
                    var o = Log.op("drop", "");
                    var e = Log.err("drop", "");
                    o.log("drop", .{});

                    if (self.stack.items.len < 1) {
                        e.log("Stack underflow: Cannot drop, stack is empty", .{});
                        return Error.StackUnderflow;
                    }

                    const val_opt = self.stack.pop();
                    const val = val_opt.?; // Safe to unwrap since we checked stack size
                    o.log("  Dropped value: {any}", .{val});
                },
                .call => {
                    const func_idx = code_reader.readLEB128() catch |err| {
                        std.debug.print("[wx] failed to read call index at pos {d}: {s}\n", .{ code_reader.pos, @errorName(err) });
                        return err;
                    };
                    var o = Log.op("call", "");
                    var e = Log.err("call", "function");
                    o.log("{d}", .{func_idx});
                    if (self.debug) {
                        std.debug.print("[wx] call {d}\n", .{func_idx});
                    }

                    if (func_idx >= module.functions.items.len) {
                        e.log("Invalid function index: {d}", .{func_idx});
                        return Error.InvalidAccess;
                    }

                    const called_func = module.functions.items[func_idx];
                    const called_type = module.types.items[called_func.type_index];

                    // Check if we have enough arguments on the stack
                    if (self.stack.items.len < called_type.params.len) {
                        e.log("Stack underflow: not enough arguments for function call", .{});
                        return Error.StackUnderflow;
                    }

                    // Prepare arguments
                    var call_args = try self.allocator.alloc(Value, called_type.params.len);
                    defer self.allocator.free(call_args);

                    // Pop arguments in reverse order
                    var i: usize = called_type.params.len;
                    while (i > 0) {
                        i -= 1;
                        call_args[i] = self.stack.pop().?;
                    }

                    // Call the function
                    const result = try self.executeFunction(func_idx, call_args);
                    if (self.debug) {
                        std.debug.print("[wx] return from {d}\n", .{func_idx});
                    }

                    // If the function returns a value, push it onto the stack
                    if (called_type.results.len > 0) {
                        try self.stack.append(self.allocator, result);
                    }
                },
                .delegate => {
                    var o = Log.op("delegate", "");
                    o.log("", .{});
                },
                .select => {
                    if (self.stack.items.len < 3) return Error.StackUnderflow;
                    const cond = self.stack.pop().?;
                    const b = self.stack.pop().?;
                    const a = self.stack.pop().?;
                    if (@as(ValueType, std.meta.activeTag(cond)) != .i32) return Error.TypeMismatch;
                    // Types of a and b must match
                    if (@intFromEnum(@as(ValueType, std.meta.activeTag(a))) != @intFromEnum(@as(ValueType, std.meta.activeTag(b))))
                        return Error.TypeMismatch;
                    const chosen = if (cond.i32 != 0) a else b;
                    try self.stack.append(self.allocator, chosen);
                },
                .select_t => {
                    // For MVP, treat same as select and ignore the immediate type vector.
                    if (self.stack.items.len < 3) return Error.StackUnderflow;
                    const cond = self.stack.pop().?;
                    const b = self.stack.pop().?;
                    const a = self.stack.pop().?;
                    if (@as(ValueType, std.meta.activeTag(cond)) != .i32) return Error.TypeMismatch;
                    if (@intFromEnum(@as(ValueType, std.meta.activeTag(a))) != @intFromEnum(@as(ValueType, std.meta.activeTag(b))))
                        return Error.TypeMismatch;
                    const chosen = if (cond.i32 != 0) a else b;
                    try self.stack.append(self.allocator, chosen);
                },
            },
            .local => |f| switch (f) {
                // else => {
                //     var o = Log.op("unknown", "");
                //     o.log("", .{});
                //     return Error.InvalidOpcode;
                // },
                .get => {
                    const local_idx = try code_reader.readLEB128();
                    var o = Log.op("local", "get");
                    var e = Log.err("local", "get");
                    o.log("{d}", .{local_idx});

                    if (local_idx >= locals_env.items.len) {
                        e.log("Invalid local index: {d}", .{local_idx});
                        return Error.InvalidAccess;
                    }

                    try self.stack.append(self.allocator, locals_env.items[local_idx]);
                    o.log("  Got local {d}: {any}", .{ local_idx, locals_env.items[local_idx] });
                },
                .set => {
                    const local_idx = try code_reader.readLEB128();
                    var op = Log.op("local", "set");
                    var e = Log.err("local", "set");
                    op.log("{d}", .{local_idx});

                    if (local_idx >= locals_env.items.len) {
                        e.log("Invalid local index: {d}", .{local_idx});
                        return Error.InvalidAccess;
                    }

                    if (self.stack.items.len < 1) {
                        e.log("Stack underflow: Cannot set local {d}, stack is empty", .{local_idx});
                        return Error.StackUnderflow;
                    }

                    const val_opt = self.stack.pop();
                    const val = val_opt.?; // Safe to unwrap since we checked stack size
                    locals_env.items[local_idx] = val;
                    op.log("  Set local {d} to {any}", .{ local_idx, val });
                },
                .tee => {
                    const local_idx = try code_reader.readLEB128();
                    var op = Log.op("local", "tee");
                    var e = Log.err("local", "tee");
                    op.log("{d}", .{local_idx});

                    if (local_idx >= locals_env.items.len) {
                        e.log("Invalid local index: {d}", .{local_idx});
                        return Error.InvalidAccess;
                    }

                    if (self.stack.items.len < 1) {
                        e.log("Stack underflow: Cannot tee local {d}, stack is empty", .{local_idx});
                        return Error.StackUnderflow;
                    }

                    const val = self.stack.items[self.stack.items.len - 1];
                    locals_env.items[local_idx] = val;
                    op.log("  Set local {d} to {any} (keeping on stack)", .{ local_idx, val });
                },
            },
            .global => |f| switch (f) {
                // else => {
                //     var o = Log.op("unknown", "");
                //     o.log("", .{});
                //     return Error.InvalidOpcode;
                // },
                .get => {
                    const global_idx = try code_reader.readLEB128();
                    var o = Log.op("global", "get");
                    var e = Log.err("global", "get");
                    o.log("{d}", .{global_idx});

                    if (global_idx >= module.globals.items.len) {
                        e.log("Invalid global index: {d}", .{global_idx});
                        return Error.InvalidAccess;
                    }

                    try self.stack.append(self.allocator, module.globals.items[global_idx].value);
                    o.log("  Got global {d}: {any}", .{ global_idx, module.globals.items[global_idx].value });
                },
                .set => {
                    const global_idx = try code_reader.readLEB128();
                    var o = Log.op("global", "set");
                    var e = Log.err("global", "set");
                    o.log("{d}", .{global_idx});

                    if (global_idx >= module.globals.items.len) {
                        e.log("Invalid global index: {d}", .{global_idx});
                        return Error.InvalidAccess;
                    }

                    if (!module.globals.items[global_idx].mutable) {
                        e.log("Cannot set immutable global {d}", .{global_idx});
                        return Error.InvalidAccess;
                    }

                    if (self.stack.items.len < 1) {
                        e.log("Stack underflow: Cannot set global {d}, stack is empty", .{global_idx});
                        return Error.StackUnderflow;
                    }

                    const val_opt = self.stack.pop();
                    const val = val_opt.?; // Safe to unwrap since we checked stack size
                    module.globals.items[global_idx].value = val;
                    o.log("  Set global {d} to {any}", .{ global_idx, val });
                },
            },
            .ref => |f| switch (f) {
                else => {
                    var o = Log.op("unknown", "");
                    o.log("", .{});
                    return Error.InvalidOpcode;
                },
            },
            .table => |f| switch (f) {
                .set => {
                    var o = Log.op("table", "set");
                    o.log("", .{});

                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const value_tableset = self.stack.pop();
                    const index = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                        return Error.TypeMismatch;

                    if (module.table == null) {
                        print("  Table not initialized", .{}, Color.red);
                        return Error.InvalidAccess;
                    }

                    if (index.?.i32 < 0 or @as(usize, @intCast(index.?.i32)) >= module.table.?.items.len) {
                        print("  Table index out of bounds: {d}", .{index.?.i32}, Color.red);
                        return Error.InvalidAccess;
                    }

                    module.table.?.items[@intCast(index.?.i32)] = value_tableset.?;
                    o.log("  Set table[{d}] = {s}", .{ index.?.i32, @tagName(@as(ValueType, std.meta.activeTag(value_tableset.?))) });
                },
                .get => {
                    var o = Log.op("table", "get");
                    o.log("", .{});

                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const index = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                        return Error.TypeMismatch;

                    if (module.table == null) {
                        print("  Table not initialized", .{}, Color.red);
                        return Error.InvalidAccess;
                    }

                    if (index.?.i32 < 0 or @as(usize, @intCast(index.?.i32)) >= module.table.?.items.len) {
                        print("  Table index out of bounds: {d}", .{index.?.i32}, Color.red);
                        return Error.InvalidAccess;
                    }

                    const v = module.table.?.items[@intCast(index.?.i32)];
                    try self.stack.append(self.allocator, v);

                    o.log("  Got table[{d}]: {s}", .{ index.?.i32, @tagName(@as(ValueType, std.meta.activeTag(v))) });
                },
                else => {
                    const opcode_ext = try code_reader.readLEB128();

                    switch (opcode_ext) {
                        else => {
                            var o = Log.op("unknown", "");
                            o.log("", .{});
                            return Error.InvalidOpcode;
                        },
                        0x00 => { // table.init
                            var o = Log.op("table", "init");
                            o.log("", .{});

                            // Read table index and elem index
                            const elem_idx = try code_reader.readLEB128();
                            const table_idx = try code_reader.readLEB128();
                            _ = elem_idx;
                            _ = table_idx;

                            // Check if we have enough values on the stack
                            if (self.stack.items.len < 3) return Error.StackUnderflow;

                            const n = self.stack.pop(); // number of elements
                            const s = self.stack.pop(); // source offset
                            const d = self.stack.pop(); // destination offset

                            // Type checking
                            if (@as(ValueType, std.meta.activeTag(n.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(s.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(d.?)) != .i32)
                            {
                                print("  Type mismatch: table.init expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            // Check if table exists
                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            // TODO: Implement element segments properly
                            o.log("  {s}Element segments not implemented yet", .{Color.yellow});
                            return Error.InvalidAccess;
                        },
                        0x01 => { // elem.drop
                            var o = Log.op("elem", "drop");
                            o.log("", .{});

                            // Read elem index
                            const elem_idx = try code_reader.readLEB128();
                            _ = elem_idx;

                            // TODO: Implement element segments properly
                            o.log(" {s} Element segments not implemented yet", .{Color.yellow});
                            return Error.InvalidAccess;
                        },
                        0x02 => { // table.copy
                            var o = Log.op("table", "copy");
                            o.log("", .{});

                            // Read destination and source table indices
                            const dst_table_idx = try code_reader.readLEB128();
                            const src_table_idx = try code_reader.readLEB128();
                            _ = dst_table_idx;
                            _ = src_table_idx;

                            // Check if we have enough values on the stack
                            if (self.stack.items.len < 3) return Error.StackUnderflow;

                            const n = self.stack.pop(); // number of elements
                            const s = self.stack.pop(); // source offset
                            const d = self.stack.pop(); // destination offset

                            // Type checking
                            if (@as(ValueType, std.meta.activeTag(n.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(s.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(d.?)) != .i32)
                            {
                                print("  Type mismatch: table.copy expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            // Check if table exists
                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            // Bounds checking
                            const n_val: usize = @intCast(n.?.i32);
                            const s_val: usize = @intCast(s.?.i32);
                            const d_val: usize = @intCast(d.?.i32);

                            if (n_val < 0) {
                                print("  Invalid copy count: {d}", .{n_val}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if ((s_val < 0) or ((s_val + n_val) > module.table.?.items.len)) {
                                print("  Source range out of bounds: {d}..{d}, table size={d}", .{ s_val, s_val + n_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            if ((d_val < 0) or ((d_val + n_val) > module.table.?.items.len)) {
                                print("  Destination range out of bounds: {d}..{d}, table size={d}", .{ d_val, d_val + n_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            // Copy table entries (handle overlapping ranges correctly)
                            if (d_val <= s_val) {
                                // Copy forward
                                var i: usize = 0;
                                while (i < n_val) : (i += 1) {
                                    module.table.?.items[d_val + i] = module.table.?.items[s_val + i];
                                }
                            } else {
                                // Copy backward
                                var i: usize = n_val;
                                while (i > 0) {
                                    i -= 1;
                                    module.table.?.items[d_val + i] = module.table.?.items[s_val + i];
                                }
                            }

                            o.log("  Copied {d} elements from table[{d}..{d}] to table[{d}..{d}]", .{ n_val, s_val, s_val + n_val - 1, d_val, d_val + n_val - 1 });
                        },
                        0x03 => { // table.grow
                            var o = Log.op("table", "grow");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const init_value = self.stack.pop();
                            const delta = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(delta.?)) != .i32)
                                return Error.TypeMismatch;

                            if (@as(ValueType, std.meta.activeTag(init_value.?)) != .funcref and
                                @as(ValueType, std.meta.activeTag(init_value.?)) != .externref)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if (delta.?.i32 < 0) {
                                print("  Cannot grow table by negative count: {d}", .{delta.?.i32}, Color.red);
                                try self.stack.append(self.allocator, .{ .i32 = -1 }); // Return -1 on failure
                                return Error.StackUnderflow;
                            }

                            const old_size = module.table.?.items.len;
                            const new_size = old_size + @as(usize, @intCast(delta.?.i32));

                            // Resize table
                            try module.table.?.resize(self.allocator, new_size);

                            // Initialize new elements
                            for (old_size..new_size) |i| {
                                module.table.?.items[i] = init_value.?;
                            }

                            // Return previous size
                            try self.stack.append(self.allocator, .{ .i32 = @intCast(old_size) });

                            o.log("  Table grown from {d} to {d} elements", .{ old_size, new_size });
                        },
                        0x04 => { // table.size
                            var o = Log.op("table", "size");
                            o.log("", .{});

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            try self.stack.append(self.allocator, .{ .i32 = @intCast(module.table.?.items.len) });

                            o.log("  Table size: {d}", .{module.table.?.items.len});
                        },
                        0x05 => { // table.fill
                            var o = Log.op("table", "fill");
                            o.log("", .{});

                            if (self.stack.items.len < 3) return Error.StackUnderflow;
                            const value_tableset = self.stack.pop();
                            const start = self.stack.pop();
                            const end = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(start.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(end.?)) != .i32)
                            {
                                print("  Type mismatch: table.fill expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const start_val: usize = @intCast(start.?.i32);
                            const end_val: usize = @intCast(end.?.i32);

                            if (start_val < 0 or end_val < 0 or start_val > module.table.?.items.len or end_val > module.table.?.items.len) {
                                print("  Invalid range: {d}..{d}, table size={d}", .{ start_val, end_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            for (start_val..end_val) |i| {
                                module.table.?.items[i] = value_tableset.?;
                            }

                            o.log("  Filled table[{d}..{d}] with {s}", .{ start_val, end_val - 1, @tagName(@as(ValueType, std.meta.activeTag(value_tableset.?))) });
                        },
                        0x06 => { // table.get
                            var o = Log.op("table", "get");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const index = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const idx: usize = @intCast(index.?.i32);
                            if (idx < 0 or idx >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{idx}, Color.red);
                                return Error.InvalidAccess;
                            }

                            try self.stack.append(self.allocator, module.table.?.items[idx]);
                            o.log("  Table[{d}] = {s}", .{ idx, @tagName(@as(ValueType, std.meta.activeTag(module.table.?.items[idx]))) });
                        },
                        0x07 => { // table.set
                            var o = Log.op("table", "set");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const v = self.stack.pop();
                            const index = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const idx: usize = @intCast(index.?.i32);
                            if (idx < 0 or idx >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{idx}, Color.red);
                                return Error.InvalidAccess;
                            }

                            module.table.?.items[idx] = v.?;
                            o.log("  Table[{d}] = {s}", .{ idx, @tagName(@as(ValueType, std.meta.activeTag(v.?))) });
                        },
                        0x08 => { // table.grow
                            var o = Log.op("table", "grow");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const delta = self.stack.pop();
                            const init_value = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(delta.?)) != .i32)
                                return Error.TypeMismatch;

                            if (@as(ValueType, std.meta.activeTag(init_value.?)) != .funcref and
                                @as(ValueType, std.meta.activeTag(init_value.?)) != .externref)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if (delta.?.i32 < 0) {
                                print("  Cannot grow table by negative count: {d}", .{delta.?.i32}, Color.red);
                                try self.stack.append(self.allocator, .{ .i32 = -1 }); // Return -1 on failure
                                return Error.StackUnderflow;
                            }

                            const old_size = module.table.?.items.len;
                            const new_size = old_size + @as(usize, @intCast(delta.?.i32));

                            // Resize table
                            try module.table.?.resize(self.allocator, new_size);

                            // Initialize new elements
                            for (old_size..new_size) |i| {
                                module.table.?.items[i] = init_value.?;
                            }

                            // Return previous size
                            try self.stack.append(self.allocator, .{ .i32 = @intCast(old_size) });

                            o.log("  Table grown from {d} to {d} elements", .{ old_size, new_size });
                        },
                        0x09 => { // table.size
                            var o = Log.op("table", "size");
                            o.log("", .{});

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const size = module.table.?.items.len;
                            try self.stack.append(self.allocator, .{ .i32 = @intCast(size) });

                            o.log("  Table size: {d}", .{size});
                        },
                        0x0a => { // table.fill
                            var o = Log.op("table", "fill");
                            o.log("", .{});

                            if (self.stack.items.len < 3) return Error.StackUnderflow;
                            const value_tableset = self.stack.pop();
                            const start = self.stack.pop();
                            const end = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(start.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(end.?)) != .i32)
                            {
                                print("  Type mismatch: table.fill expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const start_val: usize = @intCast(start.?.i32);
                            const end_val: usize = @intCast(end.?.i32);

                            if (start_val < 0 or end_val < 0 or start_val > module.table.?.items.len or end_val > module.table.?.items.len) {
                                print("  Invalid range: {d}..{d}, table size={d}", .{ start_val, end_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            for (start_val..end_val) |i| {
                                module.table.?.items[i] = value_tableset.?;
                            }

                            o.log("  Filled table[{d}..{d}] with {s}", .{ start_val, end_val - 1, @tagName(@as(ValueType, std.meta.activeTag(value_tableset.?))) });
                        },
                        0x0b => { // table.get
                            var o = Log.op("table", "get");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const index = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const idx: usize = @intCast(index.?.i32);
                            if (idx < 0 or idx >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{idx}, Color.red);
                                return Error.InvalidAccess;
                            }

                            try self.stack.append(self.allocator, module.table.?.items[idx]);
                            o.log("  Table[{d}] = {s}", .{ idx, @tagName(@as(ValueType, std.meta.activeTag(module.table.?.items[idx]))) });
                        },
                        0x0c => { // table.set
                            var o = Log.op("table", "set");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const v = self.stack.pop();
                            const index = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            const idx: usize = @intCast(index.?.i32);
                            if (idx < 0 or idx >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{idx}, Color.red);
                                return Error.InvalidAccess;
                            }

                            module.table.?.items[idx] = v.?;
                            o.log("  Table[{d}] = {s}", .{ idx, @tagName(@as(ValueType, std.meta.activeTag(v.?))) });
                        },
                        0x0d => { // table.init
                            var o = Log.op("table", "init");
                            o.log("", .{});

                            // Read table index and elem index
                            const elem_idx = try code_reader.readLEB128();
                            const table_idx = try code_reader.readLEB128();
                            _ = elem_idx;
                            _ = table_idx;

                            // Check if we have enough values on the stack
                            if (self.stack.items.len < 3) return Error.StackUnderflow;

                            const n = self.stack.pop(); // number of elements
                            const s = self.stack.pop(); // source offset
                            const d = self.stack.pop(); // destination offset

                            // Type checking
                            if (@as(ValueType, std.meta.activeTag(n.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(s.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(d.?)) != .i32)
                            {
                                print("  Type mismatch: table.init expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            // Check if table exists
                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            // TODO: Implement element segments properly
                            // For now, just report that we don't have element segments
                            o.log("  {s}Element segments not implemented yet", .{Color.yellow});
                            return Error.InvalidAccess;
                        },
                        0x0e => { // elem.drop
                            var o = Log.op("elem", "drop");
                            o.log("", .{});

                            // Read elem index
                            const elem_idx = try code_reader.readLEB128();
                            _ = elem_idx;

                            // TODO: Implement element segments properly
                            o.log(" {s} Element segments not implemented yet", .{Color.yellow});
                            return Error.InvalidAccess;
                        },
                        0x0f => { // table.copy
                            var o = Log.op("table", "copy");
                            o.log("", .{});

                            // Read destination and source table indices
                            const dst_table_idx = try code_reader.readLEB128();
                            const src_table_idx = try code_reader.readLEB128();
                            _ = dst_table_idx;
                            _ = src_table_idx;

                            // Check if we have enough values on the stack
                            if (self.stack.items.len < 3) return Error.StackUnderflow;

                            const n = self.stack.pop(); // number of elements
                            const s = self.stack.pop(); // source offset
                            const d = self.stack.pop(); // destination offset

                            // Type checking
                            if (@as(ValueType, std.meta.activeTag(n.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(s.?)) != .i32 or
                                @as(ValueType, std.meta.activeTag(d.?)) != .i32)
                            {
                                print("  Type mismatch: table.copy expects i32 operands", .{}, Color.red);
                                return Error.TypeMismatch;
                            }

                            // Check if table exists
                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            // Bounds checking
                            const n_val: usize = @intCast(n.?.i32);
                            const s_val: usize = @intCast(s.?.i32);
                            const d_val: usize = @intCast(d.?.i32);

                            if (n_val < 0) {
                                print("  Invalid copy count: {d}", .{n_val}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if ((s_val < 0) or ((s_val + n_val) > module.table.?.items.len)) {
                                print("  Source range out of bounds: {d}..{d}, table size={d}", .{ s_val, s_val + n_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            if ((d_val < 0) or ((d_val + n_val) > module.table.?.items.len)) {
                                print("  Destination range out of bounds: {d}..{d}, table size={d}", .{ d_val, d_val + n_val, module.table.?.items.len }, Color.red);
                                return Error.InvalidAccess;
                            }

                            // Copy table entries (handle overlapping ranges correctly)
                            if (d_val <= s_val) {
                                // Copy forward
                                var i: usize = 0;
                                while (i < n_val) : (i += 1) {
                                    module.table.?.items[d_val + i] = module.table.?.items[s_val + i];
                                }
                            } else {
                                // Copy backward
                                var i: usize = n_val;
                                while (i > 0) {
                                    i -= 1;
                                    module.table.?.items[d_val + i] = module.table.?.items[s_val + i];
                                }
                            }

                            o.log("  Copied {d} elements from table[{d}..{d}] to table[{d}..{d}]", .{ n_val, s_val, s_val + n_val - 1, d_val, d_val + n_val - 1 });
                            return Error.InvalidAccess;
                        },
                        0x10 => { // table.grow
                            var o = Log.op("table", "grow");
                            o.log("", .{});

                            if (self.stack.items.len < 2) return Error.StackUnderflow;
                            const delta = self.stack.pop();
                            const init_value = self.stack.pop();
                            _ = delta;
                            _ = init_value;

                            if (self.stack.items.len < 2) return Error.StackUnderflow;

                            const v = self.stack.pop();
                            const index = self.stack.pop();

                            if (@as(ValueType, std.meta.activeTag(index.?)) != .i32)
                                return Error.TypeMismatch;

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if (index.?.i32 < 0 or @as(usize, @intCast(index.?.i32)) >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{index.?.i32}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if (module.table == null) {
                                print("  Table not initialized", .{}, Color.red);
                                return Error.InvalidAccess;
                            }

                            if (index.?.i32 < 0 or @as(usize, @intCast(index.?.i32)) >= module.table.?.items.len) {
                                print("  Table index out of bounds: {d}", .{index.?.i32}, Color.red);
                                return Error.InvalidAccess;
                            }

                            // In WASM 1.0, tables can only contain references, so check type
                            if (@as(ValueType, std.meta.activeTag(v.?)) != .funcref and
                                @as(ValueType, std.meta.activeTag(v.?)) != .externref)
                            {
                                print("  Invalid table element type: {s}", .{@tagName(@as(ValueType, std.meta.activeTag(v.?)))}, Color.red);
                                return Error.TypeMismatch;
                            }

                            module.table.?.items[@intCast(index.?.i32)] = v.?;

                            o.log("  Set table[{d}] = {s}", .{ index.?.i32, @tagName(@as(ValueType, std.meta.activeTag(v.?))) });
                        },
                    }
                },
            },
            .i32 => |int32| switch (int32) {
                .load8_u => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const b = try self.readLittle(u8, ea);
                    try self.stack.append(self.allocator, .{ .i32 = @intCast(b) });
                },
                .store => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const flags = try code_reader.readLEB128();
                    const offset = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(v.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(addr.?)) != .i32)
                        return Error.TypeMismatch;
                    _ = flags; // alignment ignored
                    const ea = try effAddr(addr.?.i32, offset);
                    try self.writeLittle(i32, ea, v.?.i32);
                },
                .store8 => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32 or @as(ValueType, std.meta.activeTag(v.?)) != .i32)
                        return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    try self.writeLittle(u8, ea, @as(u8, @intCast(v.?.i32)));
                },
                // Numeric operations - i32 arithmetic
                .add => {
                    var op = Log.op("i32", "add");

                    if (self.stack.items.len < 2) {
                        var e = Log.err("i32", "add");
                        e.log("Stack underflow: Need 2 values for i32.add, stack has {d}", .{self.stack.items.len});
                        return Error.StackUnderflow;
                    }

                    const v2_opt = self.stack.pop();
                    const v1_opt = self.stack.pop();
                    const v2 = v2_opt.?; // Safe to unwrap since we checked stack size
                    const v1 = v1_opt.?; // Safe to unwrap since we checked stack size

                    if (@as(ValueType, std.meta.activeTag(v1)) != .i32 or @as(ValueType, std.meta.activeTag(v2)) != .i32) {
                        var e = Log.err("i32.add", "Type mismatch");
                        e.log("Expected i32, got {s} and {s}", .{ @tagName(std.meta.activeTag(v1)), @tagName(std.meta.activeTag(v2)) });
                        return Error.TypeMismatch;
                    }

                    const result = v1.i32 +% v2.i32; // Wrapping addition
                    op.log("{d} + {d} = {d}", .{ v1.i32, v2.i32, result });
                    try self.stack.append(self.allocator, Value{ .i32 = result });
                },
                .sub => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const vb = self.stack.pop().?;
                    const va = self.stack.pop().?;
                    const result = asI32(va) -% asI32(vb);
                    try self.stack.append(self.allocator, .{ .i32 = result });
                },
                .mul => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const vb = self.stack.pop().?;
                    const va = self.stack.pop().?;
                    const result = asI32(va) *% asI32(vb);
                    try self.stack.append(self.allocator, .{ .i32 = result });
                },
                .div_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    if (b.?.i32 == 0) return Error.DivideByZero;

                    // Special case in WebAssembly: INT_MIN / -1 would overflow
                    if (a.?.i32 == std.math.minInt(i32) and b.?.i32 == -1) {
                        print("i32.div_s: INT_MIN / -1 trap (would overflow)", .{}, Color.red);
                        return Error.InvalidAccess;
                    }

                    const result = @divTrunc(a.?.i32, b.?.i32);
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    Log.op("i32", "div_s").log("{d} / {d} = {d}", .{ a.?.i32, b.?.i32, result });
                },
                .div_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    if (b.?.i32 == 0) return Error.DivideByZero;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result = @as(i32, @bitCast(@divFloor(ua, ub)));
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "div_u");
                    o.log("{d} (unsigned) / {d} (unsigned) = {d}", .{ ua, ub, result });
                },
                .rem_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    if (b.?.i32 == 0) return Error.DivideByZero;

                    const result = @rem(a.?.i32, b.?.i32);
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    Log.op("i32", "rem_s").log("{d} % {d} = {d}", .{ a.?.i32, b.?.i32, result });
                },
                .rem_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    if (b.?.i32 == 0) return Error.DivideByZero;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result = @as(i32, @bitCast(@mod(ua, ub)));
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "rem_u");
                    o.log("{d} (unsigned) % {d} (unsigned) = {d}", .{ ua, ub, result });
                },
                // Bitwise operations
                .@"and" => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result = a.?.i32 & b.?.i32;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "and");
                    o.log("{d} & {d} = {d}", .{ a.?.i32, b.?.i32, result });
                },
                .@"or" => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result = a.?.i32 | b.?.i32;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "or");
                    o.log("{d} | {d} = {d}", .{ a.?.i32, b.?.i32, result });
                },
                .xor => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result = a.?.i32 ^ b.?.i32;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "xor");
                    o.log("{d} ^ {d} = {d}", .{ a.?.i32, b.?.i32, result });
                },
                .shl => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    // In WebAssembly, shift amount is masked to ensure it's in valid range
                    const shift = @as(u5, @intCast(b.?.i32 & 0x1F)); // mask to 5 bits (0-31)
                    const result = a.?.i32 << shift;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "shl");
                    o.log("i32.shl: {d} << {d} = {d}", .{ a.?.i32, shift, result });
                },
                .shr_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    // In WebAssembly, shift amount is masked to ensure it's in valid range
                    const shift = @as(u5, @intCast(b.?.i32 & 0x1F)); // mask to 5 bits (0-31)
                    const result = a.?.i32 >> shift;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "shr_s");
                    o.log("i32.shr_s: {d} >> {d} = {d}", .{ a.?.i32, shift, result });
                },
                .shr_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    // In WebAssembly, shift amount is masked to ensure it's in valid range
                    const shift = @as(u5, @intCast(b.?.i32 & 0x1F)); // mask to 5 bits (0-31)
                    const ua = @as(u32, @bitCast(a.?.i32));
                    const result = @as(i32, @bitCast(ua >> shift));
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "shr_u");
                    o.log("{d} (unsigned) >> {d} = {d}", .{ ua, shift, result });
                },
                .rotl => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    // In WebAssembly, rotation amount is masked to ensure it's in valid range
                    const rotate = @as(u5, @intCast(b.?.i32 & 0x1F)); // mask to 5 bits (0-31)
                    const ua = @as(u32, @bitCast(a.?.i32));
                    const result = @as(i32, @bitCast(std.math.rotl(u32, ua, rotate)));
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "rotl");
                    o.log("rotl({d}, {d}) = {d}", .{ ua, rotate, result });
                },
                .rotr => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    // In WebAssembly, rotation amount is masked to ensure it's in valid range
                    const rotate = @as(u5, @intCast(b.?.i32 & 0x1F)); // mask to 5 bits (0-31)
                    const ua = @as(u32, @bitCast(a.?.i32));
                    const result = @as(i32, @bitCast(std.math.rotr(u32, ua, rotate)));
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "rotr");
                    o.log("rotl({d}, {d}) = {d}", .{ ua, rotate, result });
                },
                // Comparison operations
                .eqz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 == 0) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "eqz");
                    o.log("{d} == 0 -> {d}", .{ a.?.i32, result });
                },
                .eq => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 == b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "eq");
                    o.log("{d} == {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .ne => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 != b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "ne");
                    o.log("{d} != {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .lt_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 < b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "lt_s");
                    o.log("{d} < {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .lt_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result: i32 = if (ua < ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "lt_u");
                    o.log("{d} (unsigned) < {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .gt_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 > b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "gt_s");
                    o.log("{d} > {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .gt_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result: i32 = if (ua > ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "gt_u");
                    o.log("{d} (unsigned) > {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .le_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 <= b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "le_s");
                    o.log("{d} <= {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .le_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result: i32 = if (ua <= ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    var o = Log.op("i32", "le_u");
                    o.log("{d} (unsigned) <= {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .ge_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const result: i32 = if (a.?.i32 >= b.?.i32) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "ge_s");
                    o.log("{d} >= {d} -> {d}", .{ a.?.i32, b.?.i32, result });
                },
                .ge_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();

                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i32)
                        return Error.TypeMismatch;

                    const ua = @as(u32, @bitCast(a.?.i32));
                    const ub = @as(u32, @bitCast(b.?.i32));
                    const result: i32 = if (ua >= ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });

                    var o = Log.op("i32", "ge_u");
                    o.log("{d} (unsigned) >= {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                // Bitwise count operations
                .clz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32)
                        return Error.TypeMismatch;
                    
                    const val = @as(u32, @bitCast(a.?.i32));
                    const result: i32 = @intCast(@clz(val));
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "clz");
                    o.log("clz({d}) = {d}", .{ val, result });
                },
                .ctz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32)
                        return Error.TypeMismatch;
                    
                    const val = @as(u32, @bitCast(a.?.i32));
                    const result: i32 = @intCast(@ctz(val));
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "ctz");
                    o.log("ctz({d}) = {d}", .{ val, result });
                },
                .popcnt => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i32)
                        return Error.TypeMismatch;
                    
                    const val = @as(u32, @bitCast(a.?.i32));
                    const result: i32 = @intCast(@popCount(val));
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "popcnt");
                    o.log("popcnt({d}) = {d}", .{ val, result });
                },
                // Memory load operations
                .load8_s => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const loaded_value = try self.readLittle(i8, ea);
                    try self.stack.append(self.allocator, .{ .i32 = loaded_value });
                },
                .load16_s => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const loaded_value = try self.readLittle(i16, ea);
                    try self.stack.append(self.allocator, .{ .i32 = loaded_value });
                },
                .load16_u => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const loaded_value = try self.readLittle(u16, ea);
                    try self.stack.append(self.allocator, .{ .i32 = @intCast(loaded_value) });
                },
                .store16 => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32 or @as(ValueType, std.meta.activeTag(v.?)) != .i32)
                        return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    try self.writeLittle(u16, ea, @as(u16, @truncate(@as(u32, @bitCast(v.?.i32)))));
                },
                // Type conversion operations  
                .wrap_i64 => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = @truncate(a.?.i64);
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "wrap_i64");
                    o.log("wrap_i64({d}) = {d}", .{ a.?.i64, result });
                },
                .trunc_f32_s => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    // Check for NaN and infinity
                    if (std.math.isNan(a.?.f32) or std.math.isInf(a.?.f32)) {
                        return Error.InvalidAccess;
                    }
                    
                    // Check for values outside i32 range
                    if (a.?.f32 >= @as(f32, @floatFromInt(std.math.maxInt(i32))) + 1 or 
                        a.?.f32 < @as(f32, @floatFromInt(std.math.minInt(i32)))) {
                        return Error.InvalidAccess;
                    }
                    
                    const result: i32 = @intFromFloat(a.?.f32);
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "trunc_f32_s");
                    o.log("trunc_f32_s({d}) = {d}", .{ a.?.f32, result });
                },
                .trunc_f32_u => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f32)
                        return Error.TypeMismatch;
                    
                    // Check for NaN and infinity
                    if (std.math.isNan(a.?.f32) or std.math.isInf(a.?.f32)) {
                        return Error.InvalidAccess;
                    }
                    
                    // Check for negative values or values outside u32 range
                    if (a.?.f32 < 0 or a.?.f32 >= @as(f32, @floatFromInt(std.math.maxInt(u32))) + 1) {
                        return Error.InvalidAccess;
                    }
                    
                    const result: u32 = @intFromFloat(a.?.f32);
                    try self.stack.append(self.allocator, .{ .i32 = @bitCast(result) });
                    
                    var o = Log.op("i32", "trunc_f32_u");
                    o.log("trunc_f32_u({d}) = {d}", .{ a.?.f32, result });
                },
                .trunc_f64_s => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f64)
                        return Error.TypeMismatch;
                    
                    // Check for NaN and infinity
                    if (std.math.isNan(a.?.f64) or std.math.isInf(a.?.f64)) {
                        return Error.InvalidAccess;
                    }
                    
                    // Check for values outside i32 range
                    if (a.?.f64 >= @as(f64, @floatFromInt(std.math.maxInt(i32))) + 1 or 
                        a.?.f64 < @as(f64, @floatFromInt(std.math.minInt(i32)))) {
                        return Error.InvalidAccess;
                    }
                    
                    const result: i32 = @intFromFloat(a.?.f64);
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i32", "trunc_f64_s");
                    o.log("trunc_f64_s({d}) = {d}", .{ a.?.f64, result });
                },
                .trunc_f64_u => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .f64)
                        return Error.TypeMismatch;
                    
                    // Check for NaN and infinity
                    if (std.math.isNan(a.?.f64) or std.math.isInf(a.?.f64)) {
                        return Error.InvalidAccess;
                    }
                    
                    // Check for negative values or values outside u32 range
                    if (a.?.f64 < 0 or a.?.f64 >= @as(f64, @floatFromInt(std.math.maxInt(u32))) + 1) {
                        return Error.InvalidAccess;
                    }
                    
                    const result: u32 = @intFromFloat(a.?.f64);
                    try self.stack.append(self.allocator, .{ .i32 = @bitCast(result) });
                    
                    var o = Log.op("i32", "trunc_f64_u");
                    o.log("trunc_f64_u({d}) = {d}", .{ a.?.f64, result });
                },
                .load => {
    _ = try code_reader.readLEB128(); // flags (alignment), currently unused
                    const offset = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr_val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr_val.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr_val.?.i32, offset);
                    const val = try self.readLittle(i32, ea);
                    try self.stack.append(self.allocator, .{ .i32 = val });
                },
                .@"const" => {
                    const v = try code_reader.readSLEB32();
                    try self.stack.append(self.allocator, .{ .i32 = v });
                },
            },
            .i64 => |int64| switch (int64) {
                .load8_s => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const b = try self.readLittle(i8, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, b) });
                },
                .load8_u => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const b = try self.readLittle(u8, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, b) });
                },
                .load16_s => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const v = try self.readLittle(i16, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, v) });
                },
                .load16_u => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const v = try self.readLittle(u16, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, v) });
                },
                .load32_s => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const v = try self.readLittle(i32, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, v) });
                },
                .load32_u => {
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const v = try self.readLittle(u32, ea);
                    try self.stack.append(self.allocator, .{ .i64 = @as(i64, v) });
                },
                .store => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32 or @as(ValueType, std.meta.activeTag(v.?)) != .i64)
                        return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    try self.writeLittle(i64, ea, v.?.i64);
                },
                .load => {
                    _ = try code_reader.readLEB128(); // flags
                    const offset = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr_val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr_val.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr_val.?.i32, offset);
                    const loaded_value = try self.readLittle(i64, ea);
                    try self.stack.append(self.allocator, .{ .i64 = loaded_value });
                },
                .@"const" => {
                    const v = try code_reader.readSLEB64();
                    try self.stack.append(self.allocator, .{ .i64 = v });
                },
                // Arithmetic operations
                .add => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 +% b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "add");
                    o.log("{d} + {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .sub => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 -% b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "sub");
                    o.log("{d} - {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .mul => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 *% b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "mul");
                    o.log("{d} * {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .div_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    if (b.?.i64 == 0) return Error.DivideByZero;
                    
                    if (a.?.i64 == std.math.minInt(i64) and b.?.i64 == -1) {
                        return Error.InvalidAccess;
                    }
                    
                    const result = @divTrunc(a.?.i64, b.?.i64);
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "div_s");
                    o.log("{d} / {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .div_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    if (b.?.i64 == 0) return Error.DivideByZero;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result = @as(i64, @bitCast(@divTrunc(ua, ub)));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "div_u");
                    o.log("{d} (unsigned) / {d} (unsigned) = {d}", .{ ua, ub, result });
                },
                .rem_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    if (b.?.i64 == 0) return Error.DivideByZero;
                    
                    const result = @rem(a.?.i64, b.?.i64);
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "rem_s");
                    o.log("{d} % {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .rem_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    if (b.?.i64 == 0) return Error.DivideByZero;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result = @as(i64, @bitCast(@rem(ua, ub)));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "rem_u");
                    o.log("{d} (unsigned) % {d} (unsigned) = {d}", .{ ua, ub, result });
                },
                // Bitwise operations
                .@"and" => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 & b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "and");
                    o.log("{d} & {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .@"or" => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 | b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "or");
                    o.log("{d} | {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .xor => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result = a.?.i64 ^ b.?.i64;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "xor");
                    o.log("{d} ^ {d} = {d}", .{ a.?.i64, b.?.i64, result });
                },
                .shl => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const shift = @as(u6, @truncate(@as(u64, @bitCast(b.?.i64)) % 64));
                    const result = a.?.i64 << shift;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "shl");
                    o.log("{d} << {d} = {d}", .{ a.?.i64, shift, result });
                },
                .shr_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const shift = @as(u6, @truncate(@as(u64, @bitCast(b.?.i64)) % 64));
                    const result = a.?.i64 >> shift;
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "shr_s");
                    o.log("{d} >> {d} = {d}", .{ a.?.i64, shift, result });
                },
                .shr_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const shift = @as(u6, @truncate(@as(u64, @bitCast(b.?.i64)) % 64));
                    const result = @as(i64, @bitCast(ua >> shift));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "shr_u");
                    o.log("{d} (unsigned) >> {d} = {d}", .{ ua, shift, result });
                },
                .rotl => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const rotate = @as(u6, @truncate(@as(u64, @bitCast(b.?.i64)) % 64));
                    const result = std.math.rotl(u64, ua, rotate);
                    try self.stack.append(self.allocator, .{ .i64 = @bitCast(result) });
                    
                    var o = Log.op("i64", "rotl");
                    o.log("rotl({d}, {d}) = {d}", .{ ua, rotate, result });
                },
                .rotr => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const rotate = @as(u6, @truncate(@as(u64, @bitCast(b.?.i64)) % 64));
                    const result = std.math.rotr(u64, ua, rotate);
                    try self.stack.append(self.allocator, .{ .i64 = @bitCast(result) });
                    
                    var o = Log.op("i64", "rotr");
                    o.log("rotr({d}, {d}) = {d}", .{ ua, rotate, result });
                },
                // Count operations
                .clz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const val = @as(u64, @bitCast(a.?.i64));
                    const result: i64 = @intCast(@clz(val));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "clz");
                    o.log("clz({d}) = {d}", .{ val, result });
                },
                .ctz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const val = @as(u64, @bitCast(a.?.i64));
                    const result: i64 = @intCast(@ctz(val));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "ctz");
                    o.log("ctz({d}) = {d}", .{ val, result });
                },
                .popcnt => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const val = @as(u64, @bitCast(a.?.i64));
                    const result: i64 = @intCast(@popCount(val));
                    try self.stack.append(self.allocator, .{ .i64 = result });
                    
                    var o = Log.op("i64", "popcnt");
                    o.log("popcnt({d}) = {d}", .{ val, result });
                },
                // Comparison operations  
                .eqz => {
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 == 0) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "eqz");
                    o.log("{d} == 0 -> {d}", .{ a.?.i64, result });
                },
                .eq => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 == b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "eq");
                    o.log("{d} == {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .ne => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 != b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "ne");
                    o.log("{d} != {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .lt_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 < b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "lt_s");
                    o.log("{d} < {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .lt_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result: i32 = if (ua < ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "lt_u");
                    o.log("{d} (unsigned) < {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .gt_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 > b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "gt_s");
                    o.log("{d} > {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .gt_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result: i32 = if (ua > ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "gt_u");
                    o.log("{d} (unsigned) > {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .le_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 <= b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "le_s");
                    o.log("{d} <= {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .le_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result: i32 = if (ua <= ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "le_u");
                    o.log("{d} (unsigned) <= {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                .ge_s => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const result: i32 = if (a.?.i64 >= b.?.i64) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "ge_s");
                    o.log("{d} >= {d} -> {d}", .{ a.?.i64, b.?.i64, result });
                },
                .ge_u => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const b = self.stack.pop();
                    const a = self.stack.pop();
                    
                    if (@as(ValueType, std.meta.activeTag(a.?)) != .i64 or
                        @as(ValueType, std.meta.activeTag(b.?)) != .i64)
                        return Error.TypeMismatch;
                    
                    const ua = @as(u64, @bitCast(a.?.i64));
                    const ub = @as(u64, @bitCast(b.?.i64));
                    const result: i32 = if (ua >= ub) 1 else 0;
                    try self.stack.append(self.allocator, .{ .i32 = result });
                    
                    var o = Log.op("i64", "ge_u");
                    o.log("{d} (unsigned) >= {d} (unsigned) -> {d}", .{ ua, ub, result });
                },
                else => {
                    var e = Log.err("unknown", "unknown");
                    e.log("Unknown opcode: 0x{X:0>2}", .{opcode});
                    return Error.InvalidOpcode;
                },
            },
            .f64 => |float64| switch (float64) {
                .@"const" => {
                    const bytes = try code_reader.readBytes(8);
                    const bits = std.mem.readInt(u64, bytes[0..8], .little);
                    const v: f64 = @bitCast(bits);
                    try self.stack.append(self.allocator, .{ .f64 = v });
                },
                .store => {
                    if (self.stack.items.len < 2) return Error.StackUnderflow;
                    const offset = try code_reader.readLEB128();
                    _ = try code_reader.readLEB128();
                    const v = self.stack.pop();
                    const addr = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr.?)) != .i32 or @as(ValueType, std.meta.activeTag(v.?)) != .f64)
                        return Error.TypeMismatch;
                    const ea = try effAddr(addr.?.i32, offset);
                    const bits: u64 = @bitCast(v.?.f64);
                    try self.writeLittle(u64, ea, bits);
                },
                .load => {
                    _ = try code_reader.readLEB128();
                    const offset = try code_reader.readLEB128();
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const addr_val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(addr_val.?)) != .i32) return Error.TypeMismatch;
                    const ea = try effAddr(addr_val.?.i32, offset);
                    const bits = try self.readLittle(u64, ea);
                    const loaded_value: f64 = @bitCast(bits);
                    try self.stack.append(self.allocator, .{ .f64 = loaded_value });
                },
                .convert_i32_u => {
                    var o = Log.op("f64", "convert_i32_u");
                    o.log("", .{});
                    if (self.stack.items.len < 1) return Error.StackUnderflow;
                    const val = self.stack.pop();
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i32) return Error.TypeMismatch;
                    try self.stack.append(self.allocator, .{ .f64 = @as(f64, @floatFromInt(@as(u32, @bitCast(val.?.i32)))) });
                },
                // f64.const handled earlier in this switch
                .convert_i32_s => {
                    var o = Log.op("f64", "convert_i32_s");
                    var e = Log.err("Error", "convert_i32_s");
                    o.log("", .{});
                    if (self.stack.items.len < 1) {
                        e.log("Stack underflow: f64.convert_i32_s needs 1 argument", .{});
                        return Error.StackUnderflow;
                    }
                    const val = self.stack.pop();
                    o.log("  Converting i32 value {d} to f64", .{val.?.i32});
                    if (@as(ValueType, std.meta.activeTag(val.?)) != .i32) {
                        e.log("  Type mismatch: expected i32, got {s}", .{@tagName(std.meta.activeTag(val.?))});
                        return Error.TypeMismatch;
                    }
                    try self.stack.append(self.allocator, .{ .f64 = @as(f64, @floatFromInt(val.?.i32)) });
                    o.log("  Result: {d}", .{@as(f64, @floatFromInt(val.?.i32))});
                },
                else => {
                    var e = Log.err("unknown", "unknown");
                    e.log("Unknown opcode: 0x{X:0>2}", .{opcode});
                    return Error.InvalidOpcode;
                },
            },
        }
    }

    // Handle function return value
    if (func_type.results.len > 0) {
        if (self.stack.items.len == 0) {
            var w = Log.warn("Warning", "No return val");
            w.log("should return a value but stack is empty, returning default value", .{});
            // Return a default value based on the expected return type
            return switch (func_type.results[0]) {
                .i32 => .{ .i32 = 0 },
                .i64 => .{ .i64 = 0 },
                .f32 => .{ .f32 = 0.0 },
                .f64 => .{ .f64 = 0.0 },
                else => return Error.TypeMismatch,
            };
        }
        return self.stack.pop().?;
    }
    return .{ .i32 = 0 };
}

pub fn findExportedFunction(self: *Runtime, name: []const u8) ?usize {
    const module = self.module orelse return null;

    for (module.exports.items) |exp| {
        if (exp.kind == .function and std.mem.eql(u8, exp.name, name)) {
            return exp.index;
        }
    }

    return null;
}

pub fn findImportedFunction(self: *Runtime, name: []const u8) ?usize {
    const module = self.module orelse return null;

    for (module.imports.items) |imp| {
        if (imp.kind == 0 and std.mem.eql(u8, imp.name, name)) {
            return imp.index;
        }
    }

    return null;
}

// Add this new function to register blocks in the map
fn registerBlock(self: *Runtime, block_pos: usize, block_idx: usize) !void {
    try self.block_position_map.put(block_pos, block_idx);
}

// Add this function to find matching end instruction more efficiently
fn findMatchingEnd(_: *Runtime, func: *const Function, _: *BytecodeReader, start_pos: usize, _: BlockType) !?usize {
    var r = Module.Reader.init(func.code);
    r.pos = start_pos;
    var depth: usize = 1;
    while (r.pos < func.code.len) {
        const op = try r.readByte();
        switch (op) {
            0x02, 0x03, 0x04 => {
                depth += 1;
                const bt = try r.readByte();
                if (bt != 0x40 and bt != 0x7F and bt != 0x7E and bt != 0x7D and bt != 0x7C) {
                    _ = try r.readLEB128();
                }
            },
            0x0B => {
                depth -= 1;
                if (depth == 0) return r.pos - 1;
            },
            else => try skipInstruction(&r),
        }
    }
    return null;
}

const ElseEnd = struct { else_pos: ?usize, end_pos: usize };

fn findElseOrEnd(_: *Runtime, func: *const Function, _: *BytecodeReader, start_pos: usize) !?ElseEnd {
    var r = Module.Reader.init(func.code);
    r.pos = start_pos;
    var depth: usize = 1;
    while (r.pos < func.code.len) {
        const op = try r.readByte();
        switch (op) {
            0x02, 0x03, 0x04 => {
                depth += 1;
                const bt = try r.readByte();
                if (bt != 0x40 and bt != 0x7F and bt != 0x7E and bt != 0x7D and bt != 0x7C) {
                    _ = try r.readLEB128();
                }
            },
            0x05 => { if (depth == 1) return ElseEnd{ .else_pos = r.pos - 1, .end_pos = undefined }; },
            0x0B => { depth -= 1; if (depth == 0) return ElseEnd{ .else_pos = null, .end_pos = r.pos - 1 }; },
            else => try skipInstruction(&r),
        }
    }
    return null;
}
// Skip immediates for a single non-control instruction
fn skipInstruction(reader: *BytecodeReader) !void {
    const op = try reader.readByte();
    switch (op) {
        // local/global get/set/tee
        0x20, 0x21, 0x22, 0x23, 0x24 => { _ = try reader.readLEB128(); },
        // memory loads/stores (align, offset)
        0x28, 0x29, 0x2A, 0x2B, 0x36, 0x37, 0x38, 0x39 => {
            _ = try reader.readLEB128();
            _ = try reader.readLEB128();
        },
        // i32.const / i64.const
        0x41 => { _ = try reader.readSLEB32(); },
        0x42 => { _ = try reader.readSLEB64(); },
        // f32.const / f64.const
        0x43 => { _ = try reader.readBytes(4); },
        0x44 => { _ = try reader.readBytes(8); },
        // call
        0x10 => { _ = try reader.readLEB128(); },
        // br / br_if
        0x0C, 0x0D => { _ = try reader.readLEB128(); },
        else => {},
    }
}
