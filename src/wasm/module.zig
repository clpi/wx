const print = @import("../util/fmt.zig").print;
const Color = @import("../util/fmt/color.zig");
const std = @import("std");
const Log = @import("../util/fmt.zig").Log;
const value = @import("value.zig");
const Value = value.Value;
const ValueType = value.Type;
const Module = @This();

pub const Import = @import("module/import.zig");
pub const Export = @import("module/export.zig");
pub const Function = @import("module/function.zig");
pub const Signature = @import("module/signature.zig");
pub const Reader = @import("module/reader.zig");
pub const Global = @import("module/global.zig");
pub const Type = @import("module/type.zig");

// Lightweight block summary for validator/runtime use
pub const BlockSummary = struct { start_pos: usize, end_pos: usize };
pub const FunctionCFG = struct { blocks: []BlockSummary = &[_]BlockSummary{} };

pub const Section = enum(u8) {
    custom = 0,
    type = 1,
    import = 2,
    function = 3,
    table = 4,
    memory = 5,
    global = 6,
    @"export" = 7,
    start = 8,
    element = 9,
    code = 10,
    data = 11,
};

allocator: std.mem.Allocator,
functions: std.ArrayList(*Function),
types: std.ArrayList(Signature),
memory: ?[]u8,
table: ?std.ArrayList(value.Value),
globals: std.ArrayList(Global),
imports: std.ArrayList(Import),
exports: std.ArrayList(Export),
start_function_index: ?u32,
cfg: std.ArrayList(FunctionCFG),
    // Passive bulk-memory storage (for memory.init/data.drop)
    passive_data_segments: std.ArrayList([]u8) = undefined,
    passive_data_dropped: std.ArrayList(bool) = undefined,
    // Passive element segments (for table.init/elem.drop)
    passive_elem_segments: std.ArrayList([]usize) = undefined,
    passive_elem_dropped: std.ArrayList(bool) = undefined,

pub fn init(allocator: std.mem.Allocator) !*Module {
    const module = try allocator.create(Module);
    module.* = .{
        .allocator = allocator,
        .functions = try std.ArrayList(*Function).initCapacity(allocator, 0),
        .types = try std.ArrayList(Signature).initCapacity(allocator, 0),
        .memory = null,
        .table = null,
        .globals = try std.ArrayList(Global).initCapacity(allocator, 0),
        .imports = try std.ArrayList(Import).initCapacity(allocator, 0),
        .exports = try std.ArrayList(Export).initCapacity(allocator, 0),
        .start_function_index = null,
        .cfg = try std.ArrayList(FunctionCFG).initCapacity(allocator, 0),
        .passive_data_segments = try std.ArrayList([]u8).initCapacity(allocator, 0),
        .passive_data_dropped = try std.ArrayList(bool).initCapacity(allocator, 0),
        .passive_elem_segments = try std.ArrayList([]usize).initCapacity(allocator, 0),
        .passive_elem_dropped = try std.ArrayList(bool).initCapacity(allocator, 0),
    };
    return module;
}

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !*Module {
    var reader = Reader.init(bytes);

    // Check magic number and version
    const magic = try reader.readBytes(4);
    if (!std.mem.eql(u8, magic, "\x00asm")) return error.InvalidMagic;

    const version = try reader.readBytes(4);
    if (!std.mem.eql(u8, version, "\x01\x00\x00\x00")) return error.InvalidVersion;

    const module = try Module.init(allocator);
    errdefer module.deinit();

    var function_type_indices = try std.ArrayList(u32).initCapacity(allocator, 0);
    defer function_type_indices.deinit(allocator);

    // Initialize default memory (65536 bytes = 1 page)
    module.memory = try allocator.alloc(u8, 65536);
    @memset(module.memory.?, 0);

    // Parse sections
    while (reader.pos < reader.bytes.len) {
        const section_id = try reader.readByte();
        const section_size = try reader.readLEB128();
        const section_data = try reader.readBytes(section_size);

        // Safely handle section_id by using a switch with explicit cases
        // instead of trying to convert to enum directly
        switch (section_id) {
            0 => {
                var o = Log.op("custom", "section");
                o.log("Skipping custom section (size: {d})", .{section_size});
            },
            1 => {
                // Type section
                const o = Log.op("type", "section");
                _ = o;
                var type_reader = Reader.init(section_data);
                const count = try type_reader.readLEB128();
                // Reserve capacity to avoid reallocations while appending
                try module.types.ensureTotalCapacityPrecise(allocator, module.types.items.len + count);
                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const form = try type_reader.readByte();
                    if (form != 0x60) return error.InvalidType;

                    const param_count = try type_reader.readLEB128();
                    var params = try allocator.alloc(ValueType, param_count);
                    for (0..param_count) |j| {
                        const val_type = try type_reader.readByte();
                        params[j] = try ValueType.fromByte(val_type);
                    }

                    const result_count = try type_reader.readLEB128();
                    var results = try allocator.alloc(ValueType, result_count);
                    for (0..result_count) |j| {
                        const val_type = try type_reader.readByte();
                        results[j] = try ValueType.fromByte(val_type);
                    }

                    try module.types.append(allocator, .{
                        .params = params,
                        .results = results,
                    });
                }
            },
            2 => {
                // Import section - skip for now
                var o = Log.op("import", "section");
                o.log("Parsing import section (size: {d})", .{section_size});
                var import_reader = Reader.init(section_data);
                const count = try import_reader.readLEB128();
                try module.imports.ensureTotalCapacityPrecise(allocator, module.imports.items.len + count);
                o.log("  Found {d} imports", .{count});

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    // Read module name
                    const module_name_len = try import_reader.readLEB128();
                    const module_name = try import_reader.readBytes(module_name_len);

                    // Read field name
                    const field_name_len = try import_reader.readLEB128();
                    const field_name = try import_reader.readBytes(field_name_len);

                    // Read kind
                    const kind = try import_reader.readByte();

                    var import_type: @import("module/export.zig").Type = undefined;
                    var type_index: ?u32 = null;

                    switch (kind) {
                        0x00 => { // Function import
                            import_type = .function;
                            type_index = try import_reader.readLEB128();

                            // Create function placeholder
                            const func = try allocator.create(Function);
                            errdefer allocator.destroy(func);

                            func.* = .{
                                .type_index = type_index.?,
                                .code = &[_]u8{}, // Empty code for imported function
                                .locals = &[_]ValueType{}, // No locals for imported function
                                .imported = true,
                            };

                            try module.functions.append(allocator, func);
                        },
                        0x01 => { // Table import
                            import_type = .table;
                            const elem_type = try import_reader.readByte();
                            if (elem_type != 0x70) return error.InvalidType; // Only funcref allowed in WASM 1.0

                            const has_max = try import_reader.readByte();
                            const initial_size = try import_reader.readLEB128();
                            var max_size: u32 = 0;

                            if (has_max == 1) {
                                max_size = try import_reader.readLEB128();
                            }

                            o.log("  Table import: initial={d}, max={d}", .{ initial_size, max_size });

                            // Initialize table with null references
                            if (module.table == null) {
                                var table = try std.ArrayList(value.Value).initCapacity(allocator, 0);
                                errdefer table.deinit(allocator);

                                try table.resize(allocator, initial_size);
                                for (table.items) |*item| {
                                    item.* = .{ .funcref = null };
                                }

                                module.table = table;
                            }
                        },
                        0x02 => { // Memory import
                            import_type = .memory;
                            const has_max = try import_reader.readByte();
                            const initial_pages = try import_reader.readLEB128();
                            var max_pages: u32 = 65536; // Default maximum (4GB)

                            if (has_max == 1) {
                                max_pages = try import_reader.readLEB128();
                            }

                            // Initialize memory
                            if (module.memory) |mem| {
                                allocator.free(mem);
                            }

                            const page_size: usize = 65536; // WebAssembly memory page size (64KB)
                            const memory_size = page_size * initial_pages;

                            o.log("  Allocating imported memory: {d} pages ({d} bytes)", .{ initial_pages, memory_size });

                            module.memory = try allocator.alloc(u8, memory_size);
                            @memset(module.memory.?, 0);
                        },
                        0x03 => { // Global import
                            import_type = .global;
                            const val_type = try import_reader.readByte();
                            const global_type = try ValueType.fromByte(val_type);
                            const mutability = try import_reader.readByte(); // 0 = const, 1 = var

                            // Initialize with default val
                            const default_val: value.Value = switch (global_type) {
                                .i32 => .{ .i32 = 0 },
                                .i64 => .{ .i64 = 0 },
                                .f32 => .{ .f32 = 0.0 },
                                .f64 => .{ .f64 = 0.0 },
                                else => return error.InvalidType,
                            };

                            try module.globals.append(allocator, .{
                                .value = default_val,
                                .mutable = mutability == 1,
                            });
                        },
                        else => return error.InvalidImportKind,
                    }

                    // Store the import information
                    const module_name_copy = try allocator.dupe(u8, module_name);
                    const field_name_copy = try allocator.dupe(u8, field_name);

                    try module.imports.append(allocator, .{
                        .module = module_name_copy,
                        .name = field_name_copy,
                        .kind = @as(Export.Type, import_type),
                        .type_index = type_index.?,
                    });

                    o.log("  Import {d}: module=\"{s}\", field=\"{s}\", kind={d}", .{
                        i, module_name, field_name, kind,
                    });
                }
            },
            3 => {
                // Function section
                var func_reader = Reader.init(section_data);
                const count = try func_reader.readLEB128();
                // Reserve for defined functions (in addition to already appended imported ones)
                try module.functions.ensureTotalCapacityPrecise(allocator, module.functions.items.len + count);
                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const type_idx = try func_reader.readLEB128();
                    try function_type_indices.append(allocator, type_idx);
                }
            },
            4 => {
                var o = Log.op("table", "section");
                // Table section
                o.log("Parsing table section (size: {d})", .{section_size});

                var table_reader = Reader.init(section_data);
                const count = try table_reader.readLEB128();
                if (count > 1) return error.MultipleTables; // WASM 1.0 only allows one table

                if (count == 1) {
                    const elem_type = try table_reader.readByte();
                    if (elem_type != 0x70) return error.InvalidType; // Only funcref allowed in WASM 1.0

                    const has_max = try table_reader.readByte();
                    const initial_size = try table_reader.readLEB128();
                    var max_size: u32 = 0;

                    if (has_max == 1) {
                        max_size = try table_reader.readLEB128();
                    }

                    o.log("  Table: initial={d}, max={d}", .{ initial_size, max_size });

                    // Initialize table with null references if not already initialized
                    if (module.table == null) {
                        var table = try std.ArrayList(value.Value).initCapacity(allocator, 0);
                        errdefer table.deinit(allocator);

                        try table.resize(allocator, initial_size);
                        for (table.items) |*item| {
                            item.* = .{ .funcref = null };
                        }

                        module.table = table;
                    } else {
                        // If table exists, ensure it's at least as large as initial_size
                        if (module.table.?.items.len < initial_size) {
                            try module.table.?.resize(allocator, initial_size);
                            for (module.table.?.items[module.table.?.items.len - (initial_size - module.table.?.items.len) ..]) |*item| {
                                item.* = .{ .funcref = null };
                            }
                        }
                    }
                }
            },
            5 => {
                // Memory section
                var mem_reader = Reader.init(section_data);
                const count = try mem_reader.readLEB128();
                if (count > 1) return error.MultipleMemories; // WASM 1.0 only allows one memory

                if (count == 1) {
                    const has_max = try mem_reader.readByte();
                    const initial_pages = try mem_reader.readLEB128();
                    var max_pages: u32 = 65536; // Default maximum (4GB)

                    if (has_max == 1) {
                        max_pages = try mem_reader.readLEB128();
                    }

                    // Free default memory and allocate the specified size
                    if (module.memory) |mem| {
                        allocator.free(mem);
                    }

                    const page_size: usize = 65536; // WebAssembly memory page size (64KB)
                    const memory_size = page_size * initial_pages;

                    var o = Log.op("memory", "section");
                    o.log("Allocating {d} memory pages ({d} bytes)", .{ initial_pages, memory_size });

                    module.memory = try allocator.alloc(u8, memory_size);
                    @memset(module.memory.?, 0);
                }
            },
            6 => {
                // Global section
                var global_reader = Reader.init(section_data);
                const count = try global_reader.readLEB128();
                try module.globals.ensureTotalCapacityPrecise(allocator, module.globals.items.len + count);
                var o = Log.op("global", "section");
                o.log("Parsing {d} globals", .{count});

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const val_type = try global_reader.readByte();
                    const global_type = try ValueType.fromByte(val_type);
                    const mutability = try global_reader.readByte(); // 0 = const, 1 = var
                    o.log("Global {d}: type={s}, mutability={d}", .{ i, @tagName(global_type), mutability });

                    // Read initialization expression
                    const init_opcode = try global_reader.readByte();
                    const init_value: Value = switch (init_opcode) {
                        0x41 => blk: { // i32.const
                            const val = try global_reader.readLEB128();
                            break :blk .{ .i32 = @intCast(val) };
                        },
                        0x42 => blk: { // i64.const
                            const val = try global_reader.readLEB128();
                            break :blk .{ .i64 = @intCast(val) };
                        },
                        0x43 => blk: { // f32.const
                            // Read 4 bytes as little-endian f32
                            const float_bytes = try global_reader.readBytes(4);
                            const val = @as(f32, @bitCast(std.mem.readInt(u32, float_bytes[0..4], .little)));
                            break :blk .{ .f32 = val };
                        },
                        0x44 => blk: { // f64.const
                            // Read 8 bytes as little-endian f64
                            const double_bytes = try global_reader.readBytes(8);
                            const val = @as(f64, @bitCast(std.mem.readInt(u64, double_bytes[0..8], .little)));
                            break :blk .{ .f64 = val };
                        },
                        else => return error.InvalidOpcode,
                    };

                    // Skip end opcode
                    const end_opcode = try global_reader.readByte();
                    if (end_opcode != 0x0b) return error.InvalidModule;

                    try module.globals.append(allocator, .{
                        .value = init_value,
                        .mutable = mutability == 1,
                    });
                }
            },
            7 => {
                // Export section

                var o = Log.op("export", "section");
                o.log("Parsing export section (size: {d})", .{section_size});
                var export_reader = Reader.init(section_data);
                const count = try export_reader.readLEB128();
                try module.exports.ensureTotalCapacityPrecise(allocator, module.exports.items.len + count);
                o.log("  Found {d} exports", .{count});

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    // Read export name
                    const name_len = try export_reader.readLEB128();
                    const name = try export_reader.readBytes(name_len);

                    // Read kind and index
                    const kind = try export_reader.readByte();
                    const index = try export_reader.readLEB128();

                    // Copy name to ensure it lives beyond the section data
                    const name_copy = try allocator.dupe(u8, name);

                    // Add to exports
                    try module.exports.append(allocator, .{
                        .name = name_copy,
                        .kind = @import("module/Export.zig").Type.fromByte(kind),
                        .index = index,
                    });

                    o.log("  Export {d}: name=\"{s}\", kind={d}, index={d}", .{
                        i, name, kind, index,
                    });

                    switch (kind) {
                        0x00 => o.log("    (Function export)", .{}),
                        0x01 => o.log("    (Table export)", .{}),
                        0x02 => o.log("    (Memory export)", .{}),
                        0x03 => o.log("    (Global export)", .{}),
                        else => o.log("    (Unknown export kind)", .{}),
                    }
                }
            },
            8 => {
                // Start section
                var o = Log.op("start", "section");
                o.log("Parsing start section (size: {d})", .{section_size});
                var start_reader = Reader.init(section_data);
                const func_index = try start_reader.readLEB128();
                module.start_function_index = func_index;
                o.log("  Start function index: {d}", .{func_index});
            },
            9 => {
                var o = Log.op("element", "section");
                // Element section
                o.log("Parsing element section (size: {d})", .{section_size});

                var elem_reader = Reader.init(section_data);
                const count = try elem_reader.readLEB128();
                o.log("  Found {d} element segments", .{count});

                // Debug: Check if table exists before proceeding
                if (module.table) |table| {
                    o.log("  Table exists with size: {d}", .{table.items.len});
                    o.log("  Table contents before initialization:", .{});
                    for (table.items, 0..) |item, idx| {
                        o.log("    table[{d}] = {any}", .{ idx, item });
                    }
                } else {
                    o.log("  ERROR: Table does not exist before element section parsing!", .{});
                }

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const flags = try elem_reader.readLEB128();
                    switch (flags) {
                        0 => {
                            // Active element segment targeting table 0 with offset expr
                            const offset_opcode = try elem_reader.readByte();
                            if (offset_opcode != 0x41) return error.InvalidOffsetExpression; // i32.const
                            const offset = try elem_reader.readLEB128();
                            const end_opcode = try elem_reader.readByte();
                            if (end_opcode != 0x0b) return error.InvalidModule;
                            const num_elems = try elem_reader.readLEB128();

                            if (module.table == null) {
                                o.log("  Error: No table initialized for element segment", .{});
                                return error.InvalidModule;
                            }
                            if (offset + num_elems > module.table.?.items.len) {
                                try module.table.?.resize(allocator, offset + num_elems);
                                for (module.table.?.items[module.table.?.items.len - num_elems ..]) |*item| item.* = .{ .funcref = null };
                            }
                            var j: usize = 0;
                            while (j < num_elems) : (j += 1) {
                                const func_idx = try elem_reader.readLEB128();
                                module.table.?.items[offset + j] = .{ .funcref = func_idx };
                            }
                            o.log("  Initialized active element seg at offset {d} count {d}", .{ offset, num_elems });
                        },
                        1, 3 => {
                            // Passive or declarative: store indices for table.init
                            const elemkind_or_type = try elem_reader.readByte();
                            _ = elemkind_or_type; // expect funcref
                            const n = try elem_reader.readLEB128();
                            const list = try allocator.alloc(usize, n);
                            for (list, 0..) |*slot, k| {
                                _ = k;
                                slot.* = try elem_reader.readLEB128();
                            }
                            try module.passive_elem_segments.append(allocator, list);
                            try module.passive_elem_dropped.append(allocator, false);
                            o.log("  Stored passive element seg {d} with {d} funcs", .{ i, n });
                        },
                        2 => {
                            // Active with explicit table index
                            const table_idx = try elem_reader.readLEB128();
                            if (table_idx != 0) return error.InvalidTableIndex;
                            const offset_opcode = try elem_reader.readByte();
                            if (offset_opcode != 0x41) return error.InvalidOffsetExpression;
                            const offset = try elem_reader.readLEB128();
                            const end_opcode = try elem_reader.readByte();
                            if (end_opcode != 0x0b) return error.InvalidModule;
                            const elemkind_or_type = try elem_reader.readByte();
                            _ = elemkind_or_type;
                            const num_elems = try elem_reader.readLEB128();
                            if (module.table == null) {
                                return error.InvalidModule;
                            }
                            if (offset + num_elems > module.table.?.items.len) {
                                try module.table.?.resize(allocator, offset + num_elems);
                                for (module.table.?.items[module.table.?.items.len - num_elems ..]) |*item| item.* = .{ .funcref = null };
                            }
                            var j: usize = 0;
                            while (j < num_elems) : (j += 1) {
                                const func_idx = try elem_reader.readLEB128();
                                module.table.?.items[offset + j] = .{ .funcref = func_idx };
                            }
                            o.log("  Initialized active(element) segment at offset {d} count {d}", .{ offset, num_elems });
                        },
                        else => return error.InvalidModule,
                    }
                }

                // Debug: Check table after initialization
                if (module.table) |table| {
                    o.log("  Table contents after initialization:", .{});
                    for (table.items, 0..) |item, idx| {
                        o.log("    table[{d}] = {any}", .{ idx, item });
                    }
                }
            },
            10 => {
                // Code section
                var code_reader = Reader.init(section_data);
                const count = try code_reader.readLEB128();
                try module.cfg.ensureTotalCapacityPrecise(allocator, module.cfg.items.len + count);
                if (count != function_type_indices.items.len) return error.InvalidModule;

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const size = try code_reader.readLEB128();
                    const body_start = code_reader.pos;
                    const body_end = body_start + size;
                    if (body_end > section_data.len) return error.InvalidModule;

                    var o = Log.op("code", "section");
                    o.log("Parsing function {d} body at offset {d}, size {d}", .{ i, body_start, size });

                    // Read local declarations
                    const local_decl_count = try code_reader.readLEB128();
                    if (local_decl_count > 1000) return error.InvalidModule; // Sanity check
                    o.log("Local declarations count: {d}", .{local_decl_count});

                    var locals_tmp = try std.ArrayList(ValueType).initCapacity(allocator, 0);
                    defer locals_tmp.deinit(allocator);

                    var j: usize = 0;
                    while (j < local_decl_count) : (j += 1) {
                        const repeat_count = try code_reader.readLEB128();
                        if (repeat_count > 10000) return error.InvalidModule; // Sanity check
                        const val_type = try code_reader.readByte();
                        o.log("Local declaration {d}: count={d}, type=0x{X:0>2}", .{ j, repeat_count, val_type });

                        const local_type = ValueType.fromByte(val_type) catch |err| {
                            o.log("Error: Invalid local type 0x{X:0>2} at index {d}", .{ val_type, j });
                            return err;
                        };

                        var k: usize = 0;
                        while (k < repeat_count) : (k += 1) {
                            try locals_tmp.append(allocator, local_type);
                        }
                    }

                    // Create function
                    const func = try allocator.create(Function);
                    errdefer allocator.destroy(func);

                    const locals = try allocator.alloc(ValueType, locals_tmp.items.len);
                    errdefer allocator.free(locals);
                    @memcpy(locals, locals_tmp.items);

                    // The remaining bytes after locals declarations are the function body
                    const code_start = code_reader.pos;
                    if (code_start > body_end) return error.InvalidModule;

                    func.* = .{
                        .type_index = function_type_indices.items[i],
                        .code = section_data[code_start..body_end],
                        .locals = locals,
                    };
                    try module.functions.append(allocator, func);
                    // Placeholder CFG slot; filled during validation
                    try module.cfg.append(allocator, .{ .blocks = &[_]BlockSummary{} });

                    // Skip to end of function body
                    code_reader.pos = body_end;

                    o.log("Function {d} parsed with {d} locals, code size {d}", .{ i, locals.len, func.code.len });
                }
            },
            11 => {
                // Data section
                var o = Log.op("data", "section");
                o.log("Parsing data section (size: {d})", .{section_size});

                var data_reader = Reader.init(section_data);
                const count = try data_reader.readLEB128();
                o.log("  Found {d} data segments", .{count});

                var i: usize = 0;
                while (i < count) : (i += 1) {
                    const flags = try data_reader.readLEB128();
                    switch (flags) {
                        0 => { // active, memidx=0
                            // offset expr
                            const op = try data_reader.readByte();
                            if (op != 0x41) return error.InvalidOffsetExpression; // i32.const
                            const offset = try data_reader.readLEB128();
                            const end = try data_reader.readByte();
                            if (end != 0x0B) return error.InvalidModule;
                            const data_size = try data_reader.readLEB128();
                            const data = try data_reader.readBytes(data_size);
                            o.log("  Active data seg {d}: offset=0x{X}, size={d}", .{ i, offset, data_size });
                            if (module.memory == null) {
                                const new_size = offset + data_size;
                                module.memory = try allocator.alloc(u8, new_size);
                                @memset(module.memory.?, 0);
                            }
                            if (offset + data_size > module.memory.?.len) {
                                const new_size = offset + data_size;
                                const new_memory = try allocator.alloc(u8, new_size);
                                @memcpy(new_memory[0..module.memory.?.len], module.memory.?);
                                @memset(new_memory[module.memory.?.len..], 0);
                                allocator.free(module.memory.?);
                                module.memory = new_memory;
                            }
                            @memcpy(module.memory.?[offset .. offset + data_size], data);
                        },
                        1 => { // passive
                            const data_size = try data_reader.readLEB128();
                            const data = try allocator.alloc(u8, data_size);
                            const seg_bytes = try data_reader.readBytes(data_size);
                            @memcpy(data, seg_bytes);
                            try module.passive_data_segments.append(allocator, data);
                            try module.passive_data_dropped.append(allocator, false);
                            o.log("  Stored passive data seg {d} size={d}", .{ i, data_size });
                        },
                        2 => { // active with memidx
                            const memidx = try data_reader.readLEB128();
                            _ = memidx; // only 0 supported
                            const op = try data_reader.readByte();
                            if (op != 0x41) return error.InvalidOffsetExpression;
                            const offset = try data_reader.readLEB128();
                            const end = try data_reader.readByte();
                            if (end != 0x0B) return error.InvalidModule;
                            const data_size = try data_reader.readLEB128();
                            const data = try data_reader.readBytes(data_size);
                            o.log("  Active (memidx) data seg {d}: offset=0x{X}, size={d}", .{ i, offset, data_size });
                            if (module.memory == null) {
                                const new_size = offset + data_size;
                                module.memory = try allocator.alloc(u8, new_size);
                                @memset(module.memory.?, 0);
                            }
                            if (offset + data_size > module.memory.?.len) {
                                const new_size = offset + data_size;
                                const new_memory = try allocator.alloc(u8, new_size);
                                @memcpy(new_memory[0..module.memory.?.len], module.memory.?);
                                @memset(new_memory[module.memory.?.len..], 0);
                                allocator.free(module.memory.?);
                                module.memory = new_memory;
                            }
                            @memcpy(module.memory.?[offset .. offset + data_size], data);
                        },
                        else => return error.InvalidModule,
                    }
                }
            },
            else => {
                // Unknown section - skip gracefully
                var o = Log.op("unknown", "section");
                o.log("Skipping unknown section ID: {d} (size: {d})", .{ section_id, section_size });
            },
        }
    }

    return module;
}

pub fn deinit(self: *Module) void {
    for (self.functions.items) |func| {
        self.allocator.free(func.locals);
        self.allocator.destroy(func);
    }
    for (self.types.items) |*typ| {
        self.allocator.free(typ.params);
        self.allocator.free(typ.results);
    }

    // Free import strings
    for (self.imports.items) |import| {
        self.allocator.free(import.module);
        self.allocator.free(import.name);
    }

    // Free export strings
    for (self.exports.items) |exp| {
        self.allocator.free(exp.name);
    }

    self.functions.deinit(self.allocator);
    self.types.deinit(self.allocator);
    if (self.memory) |mem| {
        self.allocator.free(mem);
    }
    if (self.table) |*table| {
        table.deinit(self.allocator);
    }
    // Free passive data segments
    for (self.passive_data_segments.items) |seg| {
        self.allocator.free(seg);
    }
    self.passive_data_segments.deinit(self.allocator);
    self.passive_data_dropped.deinit(self.allocator);
    // Free passive element segments
    for (self.passive_elem_segments.items) |seg| {
        self.allocator.free(seg);
    }
    self.passive_elem_segments.deinit(self.allocator);
    self.passive_elem_dropped.deinit(self.allocator);
    self.globals.deinit(self.allocator);
    self.imports.deinit(self.allocator);
    self.exports.deinit(self.allocator);
    self.allocator.destroy(self);
}

// pub fn parseDataSection(self: *Module, reader: anytype) !void {
//     var reader = Reader.init(bytes);
//     const count = try reader.readULEB128(u32, reader);
//     o.log("Parsing data section with {d} segments\n", .{count});

//     var i: u32 = 0;
//     while (i < count) : (i += 1) {
//         const flags = try leb.readULEB128(u32, reader);
//         o.log("  Data segment {d} flags: {d}\n", .{ i, flags });

//         var memory_index: u32 = 0;
//         var offset_expr = Expression{};
//         var offset: u32 = 0;

//         if (flags == 0) {
//             try offset_expr.parse(reader);
//             const result = try self.evaluateConstantExpression(&offset_expr);
//             offset = @intCast(result.i32);
//             o.log("  Data segment {d} active, offset: {d}\n", .{ i, offset });
//         } else if (flags == 1) {
//             o.log("  Data segment {d} passive\n", .{i});
//         } else if (flags == 2) {
//             memory_index = try leb.readULEB128(u32, reader);
//             try offset_expr.parse(reader);
//             const result = try self.evaluateConstantExpression(&offset_expr);
//             offset = @intCast(result.i32);
//             o.log("  Data segment {d} active, memory: {d}, offset: {d}\n", .{ i, memory_index, offset });
//         } else {
//             return error.InvalidDataSegmentFlags;
//         }

//         const size = try leb.readULEB128(u32, reader);
//         o.log("  Data segment {d} size: {d} bytes\n", .{ i, size });

//         if (size > 0) {
//             const data = try self.allocator.alloc(u8, size);
//             errdefer self.allocator.free(data);

//             const bytes_read = try reader.readAll(data);
//             if (bytes_read != size) {
//                 return error.UnexpectedEndOfFile;
//             }

//             // o.log( the first few bytes of the data for debugging
//             if (size <= 64) {
//                 o.log("  Data content: ", .{});
//                 for (data) |byte| {
//                     if (byte >= 32 and byte <= 126) {
//                         o.log("{c}", .{byte});
//                     } else {
//                         o.log("\\x{X:0>2}", .{byte});
//                     }
//                 }
//                 o.log("\n", .{});
//             } else {
//                 o.log("  Data content (first 64 bytes): ", .{});
//                 for (data[0..@min(64, data.len)]) |byte| {
//                     if (byte >= 32 and byte <= 126) {
//                         o.log("{c}", .{byte});
//                     } else {
//                         o.log("\\x{X:0>2}", .{byte});
//                     }
//                 }
//                 o.log("...\n", .{});
//             }

//             if (flags != 1) { // Not passive
//                 try self.data_segments.append(self.allocator, .{
//                     .memory_index = memory_index,
//                     .offset = offset,
//                     .data = data,
//                 });
//             } else {
//                 // For passive segments, we just store them for now
//                 try self.passive_data_segments.append(self.allocator, data);
//             }
//         } else {
//             o.log("  Data segment {d} is empty\n", .{i});
//             if (flags != 1) { // Not passive
//                 try self.data_segments.append(self.allocator, .{
//                     .memory_index = memory_index,
//                     .offset = offset,
//                     .data = &[_]u8{},
//                 });
//             } else {
//                 // For passive segments, we just store them for now
//                 try self.passive_data_segments.append(self.allocator, &[_]u8{});
//             }
//         }
//     }
// }

pub fn initMemory(self: *Module) !void {
    // Initialize memory with data segments
    var o = Log.op("memory", "init");
    o.log("Initializing memory with {d} data segments\n", .{self.data_segments.items.len});

    for (self.data_segments.items, 0..) |segment, i| {
        if (segment.memory_index >= self.memories.items.len) {
            return error.InvalidMemoryIndex;
        }

        const memory = &self.memories.items[segment.memory_index];
        const offset = segment.offset;
        const data = segment.data;

        o.log("Initializing memory[{d}] at offset {d} with {d} bytes\n", .{
            segment.memory_index, offset, data.len,
        });

        if (offset + data.len > memory.data.len) {
            o.log("Error: Data segment {d} would exceed memory bounds (offset={d}, size={d}, memory_size={d})\n", .{ i, offset, data.len, memory.data.len });
            return error.DataSegmentOutOfBounds;
        }

        // Copy data to memory
        @memcpy(memory.data[offset..][0..data.len], data);

        // Debug o.log( the data
        if (data.len <= 64) {
            o.log("  Data content: ", .{});
            for (data) |byte| {
                if (byte >= 32 and byte <= 126) {
                    o.log("{c}", .{byte});
                } else {
                    o.log("\\x{X:0>2}", .{byte});
                }
            }
            o.log("\n", .{});
        } else {
            o.log("  Data content (first 64 bytes): ", .{});
            for (data[0..@min(64, data.len)]) |byte| {
                if (byte >= 32 and byte <= 126) {
                    o.log("{c}", .{byte});
                } else {
                    o.log("\\x{X:0>2}", .{byte});
                }
            }
            o.log("...\n", .{});
        }
    }
}

/// Validates a WebAssembly module before execution
/// This checks for common errors and inconsistencies in the module
pub fn validateModule(self: *Module) !void {
    var o = Log.op("validateModule", "");
    o.log("Validating WebAssembly module", .{});

    // 1. Validate function signatures against type section
    o.log("Validating {d} functions against type section", .{self.functions.items.len});
    for (self.functions.items, 0..) |func, idx| {
        if (func.type_index >= self.types.items.len) {
            o.log("Error: Function {d} has invalid type index {d} (max: {d})", .{ idx, func.type_index, self.types.items.len - 1 });
            return error.InvalidTypeIndex;
        }
    }

    // 2. Validate imports
    o.log("Validating {d} imports", .{self.imports.items.len});
    for (self.imports.items, 0..) |import, idx| {
        if (import.kind == .function) {
            if (import.type_index >= self.types.items.len) {
                o.log("Error: Import {d} ({s}::{s}) has invalid type index {d} (max: {d})", .{ idx, import.module, import.name, import.type_index, self.types.items.len - 1 });
                return error.InvalidTypeIndex;
            }
        }
    }

    // 3. Validate exports
    o.log("Validating {d} exports", .{self.exports.items.len});
    for (self.exports.items, 0..) |export_item, idx| {
        switch (export_item.kind) {
            .function => {
                if (export_item.index >= self.functions.items.len) {
                    o.log("Error: Export {d} ({s}) references invalid function index {d} (max: {d})", .{ idx, export_item.name, export_item.index, self.functions.items.len - 1 });
                    return error.InvalidExportIndex;
                }
            },
            .memory => {
                if (self.memory == null) {
                    o.log("Error: Export {d} ({s}) references memory but no memory section exists", .{ idx, export_item.name });
                    return error.InvalidExport;
                }
            },
            .table => {
                if (self.table == null) {
                    o.log("Error: Export {d} ({s}) references table but no table section exists", .{ idx, export_item.name });
                    return error.InvalidExport;
                }
            },
            .global => {
                if (export_item.index >= self.globals.items.len) {
                    o.log("Error: Export {d} ({s}) references invalid global index {d} (max: {d})", .{ idx, export_item.name, export_item.index, self.globals.items.len - 1 });
                    return error.InvalidExportIndex;
                }
            },
        }
    }

    // 4. Validate function code
    o.log("Validating function code", .{});
    for (self.functions.items, 0..) |func, idx| {
        if (!func.imported) {
            // Skip imports - they don't have code
            try validateFunctionCode(self, func, idx);
        }
    }

    o.log("Module validation complete", .{});
}

/// Validates the bytecode of a single function
fn validateFunctionCode(module: *Module, func: *Function, func_idx: usize) !void {
    var o = Log.op("validateFunctionCode", "");
    o.log("Validating function {d} code ({d} bytes)", .{ func_idx, func.code.len });

    // Create a reader for the function code
    var code_reader = Reader.init(func.code);

    // Quick pre-scan to size validation stacks (approximate # of blocks)
    var approx_blocks: usize = 0;
    for (func.code) |b| {
        switch (b) {
            0x02, 0x03, 0x04 => approx_blocks += 1, // block/loop/if
            else => {},
        }
    }

    // Track blocks for balance checking (function body is implicit block)
    var block_depth: usize = 1;
    var blocks = try std.ArrayList(BlockSummary).initCapacity(module.allocator, @max(8, approx_blocks + 2));
    defer blocks.deinit(module.allocator);
    var start_stack = try std.ArrayList(usize).initCapacity(module.allocator, @max(8, approx_blocks + 2));
    defer start_stack.deinit(module.allocator);
    const ElseOpen = struct { end_depth: usize, idx: usize };
    var else_stack = try std.ArrayList(ElseOpen).initCapacity(module.allocator, @max(4, approx_blocks));
    defer else_stack.deinit(module.allocator);

    // Track value types on conceptual stack for type checking
    var type_stack = try std.ArrayList(ValueType).initCapacity(module.allocator, 0);
    defer type_stack.deinit(module.allocator);

    // Get the function type
    const func_type = module.types.items[func.type_index];

    // Add locals (parameters + locals)
    var locals = try std.ArrayList(ValueType).initCapacity(module.allocator, 0);
    defer locals.deinit(module.allocator);

    // Add parameters as locals first
    try locals.appendSlice(module.allocator, func_type.params);

    // Add function-defined locals
    for (func.locals) |local_type| {
        try locals.append(module.allocator, local_type);
    }

    while (code_reader.pos < func.code.len) {
        const opcode = code_reader.readByte() catch |err| {
            o.log("Error reading opcode at position {d}: {any}", .{ code_reader.pos, err });
            return err;
        };

        // Handle control flow instructions
        switch (opcode) {
            0x02, 0x03, 0x04 => { // block, loop, if
                // Record start position of this block (current opcode was at pos-1)
                const start_pos = code_reader.pos - 1;
                try start_stack.append(module.allocator, start_pos);
                block_depth += 1;

                // Skip block type
                _ = code_reader.readByte() catch |err| {
                    o.log("Error reading block type at position {d}: {any}", .{ code_reader.pos, err });
                    return err;
                };

                // For if instructions, ensure there's a condition value
                if (opcode == 0x04 and type_stack.items.len == 0) {
                    o.log("Error: if instruction at position {d} without condition value", .{code_reader.pos - 2});
                    return error.TypeMismatch;
                }

                // Pop the condition for if
                if (opcode == 0x04) {
                    const condition_type = type_stack.pop();
                    if (condition_type == null or condition_type.? != .i32) {
                        o.log("Error: if instruction at position {d} with invalid condition type", .{code_reader.pos - 2});
                        return error.TypeMismatch;
                    }
                }
            },
            0x05 => { // else
                if (block_depth == 0) {
                    o.log("Error: else instruction at position {d} without matching if", .{code_reader.pos - 1});
                    return error.InvalidCode;
                }
                const else_pos = code_reader.pos - 1;
                const idx = blocks.items.len;
                try blocks.append(module.allocator, .{ .start_pos = else_pos, .end_pos = 0 });
                // Matching end will reduce depth by 1
                try else_stack.append(module.allocator, .{ .end_depth = block_depth - 1, .idx = idx });
                // Note: we don't decrement block_depth for else
            },
            0x0B => { // end
                if (block_depth == 0) {
                    o.log("Error: end instruction at position {d} without matching block", .{code_reader.pos - 1});
                    return error.InvalidCode;
                }
                block_depth -= 1;
                const end_pos = code_reader.pos - 1;
                const start_opt = if (start_stack.items.len > 0) start_stack.pop() else null;
                const start_pos = if (start_opt) |sp| sp else 0;
                try blocks.append(module.allocator, .{ .start_pos = start_pos, .end_pos = end_pos });
                // If an else region is open for this depth, close it now
                if (else_stack.items.len > 0) {
                    const top = else_stack.items[else_stack.items.len - 1];
                    if (top.end_depth == block_depth) {
                        else_stack.items.len -= 1;
                        blocks.items[top.idx].end_pos = end_pos;
                    }
                }
            },
            // Handle local access
            0x20 => { // local.get
                const local_idx = code_reader.readLEB128() catch |err| {
                    o.log("Error reading local index at position {d}: {any}", .{ code_reader.pos, err });
                    return err;
                };

                if (local_idx >= locals.items.len) {
                    o.log("Error: local.get at position {d} references invalid local index {d} (max: {d})", .{ code_reader.pos - 2, local_idx, locals.items.len - 1 });
                    return error.InvalidLocalIndex;
                }

                // Push the local's type onto the stack
                try type_stack.append(module.allocator, locals.items[local_idx]);
            },
            0x21 => { // local.set
                const local_idx = code_reader.readLEB128() catch |err| {
                    o.log("Error reading local index at position {d}: {any}", .{ code_reader.pos, err });
                    return err;
                };

                if (local_idx >= locals.items.len) {
                    o.log("Error: local.set at position {d} references invalid local index {d} (max: {d})", .{ code_reader.pos - 2, local_idx, locals.items.len - 1 });
                    return error.InvalidLocalIndex;
                }

                // Check for stack underflow
                if (type_stack.items.len == 0) {
                    o.log("Error: local.set at position {d} with empty stack", .{code_reader.pos - 2});
                    return error.StackUnderflow;
                }

                // Pop the value type and check compatibility
                const value_type = type_stack.pop() orelse {
                    o.log("Error: local.set at position {d} with empty stack", .{code_reader.pos - 2});
                    return error.StackUnderflow;
                };
                if (value_type != locals.items[local_idx]) {
                    o.log("Error: local.set at position {d} with incompatible types: expected {s}, got {s}", .{ code_reader.pos - 2, @tagName(locals.items[local_idx]), @tagName(value_type) });
                    return error.TypeMismatch;
                }
            },
            // Memory operations
            0x28, 0x29, 0x2A, 0x2B => { // i32.load, i64.load, f32.load, f64.load
                // Skip alignment and offset
                _ = code_reader.readLEB128() catch |err| {
                    o.log("Error reading alignment at position {d}: {any}", .{ code_reader.pos, err });
                    return err;
                };
                _ = code_reader.readLEB128() catch |err| {
                    o.log("Error reading offset at position {d}: {any}", .{ code_reader.pos, err });
                    return err;
                };

                // Check for memory section
                if (module.memory == null) {
                    o.log("Error: memory operation at position {d} but no memory section exists", .{code_reader.pos - 3});
                    return error.InvalidMemoryAccess;
                }

                // Check for address on stack
                if (type_stack.items.len == 0) {
                    o.log("Error: memory load at position {d} with empty stack", .{code_reader.pos - 3});
                    return error.StackUnderflow;
                }

                // Pop address and check type
                const addr_type = type_stack.pop() orelse {
                    o.log("Error: memory load at position {d} with empty stack", .{code_reader.pos - 3});
                    return error.StackUnderflow;
                };
                if (addr_type != .i32) {
                    o.log("Error: memory load at position {d} with non-i32 address type: {s}", .{ code_reader.pos - 3, @tagName(addr_type) });
                    return error.TypeMismatch;
                }

                // Push result type based on opcode
                const result_type: ValueType = switch (opcode) {
                    0x28 => .i32,
                    0x29 => .i64,
                    0x2A => .f32,
                    0x2B => .f64,
                    else => unreachable,
                };
                try type_stack.append(module.allocator, result_type);
            },
            // Skip other opcodes for brevity - a real implementation would validate all opcodes
            else => {
                // For simplicity, we're not validating all opcodes in this example
                // A real implementation would validate every opcode's type constraints
            },
        }
    }

    // After processing all opcodes, ensure blocks are balanced
    if (block_depth != 0) {
        o.log("Error: Function has {d} unclosed blocks", .{block_depth});
        return error.UnbalancedBlocks;
    }

    // For functions with results, ensure the correct number of values are on the stack
    if (func_type.results.len > 0) {
        if (type_stack.items.len < func_type.results.len) {
            o.log("Error: Function has insufficient return values on stack: expected {d}, got {d}", .{ func_type.results.len, type_stack.items.len });
            return error.InvalidReturnValue;
        }

        // Check result types match function signature
        const stack_pos = type_stack.items.len - func_type.results.len;
        for (func_type.results, 0..) |expected_type, i| {
            const actual_type = type_stack.items[stack_pos + i];
            if (expected_type != actual_type) {
                o.log("Error: Function return type mismatch at position {d}: expected {s}, got {s}", .{ i, @tagName(expected_type), @tagName(actual_type) });
                return error.TypeMismatch;
            }
        }
    }

    o.log("Function {d} code validation succeeded", .{func_idx});

    // Store block summaries
    const slice = try module.allocator.dupe(BlockSummary, blocks.items);
    if (func_idx < module.cfg.items.len) {
        module.cfg.items[func_idx].blocks = slice;
    } else {
        // Ensure cfg has slots up to func_idx
        while (module.cfg.items.len < func_idx) {
            try module.cfg.append(module.allocator, .{ .blocks = &[_]BlockSummary{} });
        }
        try module.cfg.append(module.allocator, .{ .blocks = slice });
    }
}
