const std = @import("std");
const Runtime = @import("runtime.zig");
const Module = @import("module.zig");
const Value = Runtime.Value;
const Log = @import("../util/fmt.zig").Log;

/// WASM4 fantasy console implementation
/// Spec: https://wasm4.org/docs/reference/memory
pub const WASM4 = @This();

allocator: std.mem.Allocator,
debug: bool = false,

// WASM4 Memory Map (all little-endian)
pub const PALETTE: usize = 0x04;       // 4 colors, each u32 (16 bytes)
pub const DRAW_COLORS: usize = 0x14;   // u16
pub const GAMEPAD1: usize = 0x16;      // u8
pub const GAMEPAD2: usize = 0x17;      // u8
pub const GAMEPAD3: usize = 0x18;      // u8
pub const GAMEPAD4: usize = 0x19;      // u8
pub const MOUSE_X: usize = 0x1a;       // i16
pub const MOUSE_Y: usize = 0x1c;       // i16
pub const MOUSE_BUTTONS: usize = 0x1e; // u8
pub const SYSTEM_FLAGS: usize = 0x1f;  // u8
pub const NETPLAY: usize = 0x20;       // u8
pub const FRAMEBUFFER: usize = 0xa0;   // 160x160 pixels, 2 bits per pixel (6400 bytes)

// Display dimensions
pub const SCREEN_WIDTH: u32 = 160;
pub const SCREEN_HEIGHT: u32 = 160;

// Gamepad button flags
pub const BUTTON_1: u8 = 1;
pub const BUTTON_2: u8 = 2;
pub const BUTTON_LEFT: u8 = 16;
pub const BUTTON_RIGHT: u8 = 32;
pub const BUTTON_UP: u8 = 64;
pub const BUTTON_DOWN: u8 = 128;

// Mouse button flags
pub const MOUSE_LEFT: u8 = 1;
pub const MOUSE_RIGHT: u8 = 2;
pub const MOUSE_MIDDLE: u8 = 4;

// System flags
pub const SYSTEM_PRESERVE_FRAMEBUFFER: u8 = 1;
pub const SYSTEM_HIDE_GAMEPAD_OVERLAY: u8 = 2;

// Blit flags
pub const BLIT_1BPP: u32 = 0;
pub const BLIT_2BPP: u32 = 1;
pub const BLIT_FLIP_X: u32 = 2;
pub const BLIT_FLIP_Y: u32 = 4;
pub const BLIT_ROTATE: u32 = 8;

pub fn init(allocator: std.mem.Allocator) !WASM4 {
    return WASM4{
        .allocator = allocator,
        .debug = false,
    };
}

pub fn deinit(_: *WASM4) void {
    // Nothing to clean up currently
}

/// Initialize memory with WASM4 defaults
pub fn setupModule(_: *WASM4, module: *Module) !void {
    if (module.memory) |memory| {
        // Initialize palette with default colors
        // Color 0: Light green (e6f8da)
        std.mem.writeInt(u32, memory[PALETTE..][0..4], 0xe0f8cf, .little);
        // Color 1: Medium green (86c06c)
        std.mem.writeInt(u32, memory[PALETTE + 4 ..][0..4], 0x86c06c, .little);
        // Color 2: Dark green (306850)
        std.mem.writeInt(u32, memory[PALETTE + 8 ..][0..4], 0x306850, .little);
        // Color 3: Darkest (071821)
        std.mem.writeInt(u32, memory[PALETTE + 12 ..][0..4], 0x071821, .little);

        // Initialize draw colors to default
        std.mem.writeInt(u16, memory[DRAW_COLORS..][0..2], 0x1203, .little);

        // Clear gamepad states
        memory[GAMEPAD1] = 0;
        memory[GAMEPAD2] = 0;
        memory[GAMEPAD3] = 0;
        memory[GAMEPAD4] = 0;

        // Initialize mouse state
        std.mem.writeInt(i16, memory[MOUSE_X..][0..2], 0, .little);
        std.mem.writeInt(i16, memory[MOUSE_Y..][0..2], 0, .little);
        memory[MOUSE_BUTTONS] = 0;

        // Initialize system flags
        memory[SYSTEM_FLAGS] = 0;
        memory[NETPLAY] = 0;
    }
}

/// Handle WASM4 imports
pub fn handleImport(self: *WASM4, field_name: []const u8, args: []const Value, runtime: *Runtime, module: *Module) !Value {
    var o = Log.op("WASM4", field_name);
    
    if (self.debug) {
        o.log("Import called with {d} args\n", .{args.len});
    }

    if (std.mem.eql(u8, field_name, "blit")) {
        return try self.blit(args, module);
    } else if (std.mem.eql(u8, field_name, "blitSub")) {
        return try self.blitSub(args, module);
    } else if (std.mem.eql(u8, field_name, "line")) {
        return try self.line(args, module);
    } else if (std.mem.eql(u8, field_name, "hline")) {
        return try self.hline(args, module);
    } else if (std.mem.eql(u8, field_name, "vline")) {
        return try self.vline(args, module);
    } else if (std.mem.eql(u8, field_name, "oval")) {
        return try self.oval(args, module);
    } else if (std.mem.eql(u8, field_name, "rect")) {
        return try self.rect(args, module);
    } else if (std.mem.eql(u8, field_name, "text")) {
        return try self.text(args, module);
    } else if (std.mem.eql(u8, field_name, "tone")) {
        return try self.tone(args, runtime);
    } else if (std.mem.eql(u8, field_name, "diskr")) {
        return try self.diskr(args, module);
    } else if (std.mem.eql(u8, field_name, "diskw")) {
        return try self.diskw(args, module);
    } else if (std.mem.eql(u8, field_name, "trace")) {
        return try self.trace(args, module);
    } else if (std.mem.eql(u8, field_name, "tracef")) {
        return try self.tracef(args, module);
    }

    if (self.debug) {
        o.log("Unknown WASM4 import: {s}\n", .{field_name});
    }
    return .{ .i32 = 0 };
}

/// blit(sprite: ptr, x: i32, y: i32, width: u32, height: u32, flags: u32)
fn blit(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 6) return error.InvalidArgCount;
    
    const sprite_ptr = Runtime.asI32(args[0]);
    const x = Runtime.asI32(args[1]);
    const y = Runtime.asI32(args[2]);
    const width = Runtime.asU32(args[3]);
    const height = Runtime.asU32(args[4]);
    const flags = Runtime.asU32(args[5]);

    if (self.debug) {
        var o = Log.op("WASM4", "blit");
        o.log("sprite_ptr={d}, x={d}, y={d}, width={d}, height={d}, flags={d}\n", 
            .{ sprite_ptr, x, y, width, height, flags });
    }

    if (module.memory) |memory| {
        // Validate sprite pointer
        const bpp: u32 = if (flags & BLIT_2BPP != 0) 2 else 1;
        const sprite_size = (width * height * bpp) / 8;
        
        if (sprite_ptr < 0 or sprite_ptr + @as(i32, @intCast(sprite_size)) > memory.len) {
            return .{ .i32 = 0 };
        }

        // TODO: Implement actual blitting to framebuffer
        // For now, just validate and return
        _ = x;
        _ = y;
    }

    return .{ .i32 = 0 };
}

/// blitSub(sprite: ptr, x: i32, y: i32, width: u32, height: u32, src_x: u32, src_y: u32, stride: u32, flags: u32)
fn blitSub(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 9) return error.InvalidArgCount;
    
    const sprite_ptr = Runtime.asI32(args[0]);
    const x = Runtime.asI32(args[1]);
    const y = Runtime.asI32(args[2]);
    const width = Runtime.asU32(args[3]);
    const height = Runtime.asU32(args[4]);
    const src_x = Runtime.asU32(args[5]);
    const src_y = Runtime.asU32(args[6]);
    const stride = Runtime.asU32(args[7]);
    const flags = Runtime.asU32(args[8]);

    if (self.debug) {
        var o = Log.op("WASM4", "blitSub");
        o.log("sprite_ptr={d}, x={d}, y={d}, w={d}, h={d}, src_x={d}, src_y={d}, stride={d}, flags={d}\n",
            .{ sprite_ptr, x, y, width, height, src_x, src_y, stride, flags });
    }

    _ = module;
    _ = sprite_ptr;
    // TODO: Implement blitSub
    return .{ .i32 = 0 };
}

/// line(x1: i32, y1: i32, x2: i32, y2: i32)
fn line(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 4) return error.InvalidArgCount;
    
    const x1 = Runtime.asI32(args[0]);
    const y1 = Runtime.asI32(args[1]);
    const x2 = Runtime.asI32(args[2]);
    const y2 = Runtime.asI32(args[3]);

    if (self.debug) {
        var o = Log.op("WASM4", "line");
        o.log("x1={d}, y1={d}, x2={d}, y2={d}\n", .{ x1, y1, x2, y2 });
    }

    _ = module;
    // TODO: Implement line drawing
    return .{ .i32 = 0 };
}

/// hline(x: i32, y: i32, len: u32)
fn hline(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 3) return error.InvalidArgCount;
    
    const x = Runtime.asI32(args[0]);
    const y = Runtime.asI32(args[1]);
    const len = Runtime.asU32(args[2]);

    if (self.debug) {
        var o = Log.op("WASM4", "hline");
        o.log("x={d}, y={d}, len={d}\n", .{ x, y, len });
    }

    _ = module;
    // TODO: Implement horizontal line drawing
    return .{ .i32 = 0 };
}

/// vline(x: i32, y: i32, len: u32)
fn vline(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 3) return error.InvalidArgCount;
    
    const x = Runtime.asI32(args[0]);
    const y = Runtime.asI32(args[1]);
    const len = Runtime.asU32(args[2]);

    if (self.debug) {
        var o = Log.op("WASM4", "vline");
        o.log("x={d}, y={d}, len={d}\n", .{ x, y, len });
    }

    _ = module;
    // TODO: Implement vertical line drawing
    return .{ .i32 = 0 };
}

/// oval(x: i32, y: i32, width: u32, height: u32)
fn oval(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 4) return error.InvalidArgCount;
    
    const x = Runtime.asI32(args[0]);
    const y = Runtime.asI32(args[1]);
    const width = Runtime.asU32(args[2]);
    const height = Runtime.asU32(args[3]);

    if (self.debug) {
        var o = Log.op("WASM4", "oval");
        o.log("x={d}, y={d}, width={d}, height={d}\n", .{ x, y, width, height });
    }

    _ = module;
    // TODO: Implement oval drawing
    return .{ .i32 = 0 };
}

/// rect(x: i32, y: i32, width: u32, height: u32)
fn rect(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 4) return error.InvalidArgCount;
    
    const x = Runtime.asI32(args[0]);
    const y = Runtime.asI32(args[1]);
    const width = Runtime.asU32(args[2]);
    const height = Runtime.asU32(args[3]);

    if (self.debug) {
        var o = Log.op("WASM4", "rect");
        o.log("x={d}, y={d}, width={d}, height={d}\n", .{ x, y, width, height });
    }

    _ = module;
    // TODO: Implement rectangle drawing
    return .{ .i32 = 0 };
}

/// text(text: ptr, x: i32, y: i32)
fn text(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 3) return error.InvalidArgCount;
    
    const text_ptr = Runtime.asI32(args[0]);
    const x = Runtime.asI32(args[1]);
    const y = Runtime.asI32(args[2]);

    if (self.debug) {
        var o = Log.op("WASM4", "text");
        o.log("text_ptr={d}, x={d}, y={d}\n", .{ text_ptr, x, y });
    }

    if (module.memory) |memory| {
        // Read null-terminated string from memory
        if (text_ptr >= 0 and text_ptr < memory.len) {
            var len: usize = 0;
            while (text_ptr + @as(i32, @intCast(len)) < memory.len and memory[@intCast(text_ptr + @as(i32, @intCast(len)))] != 0) {
                len += 1;
            }
            
            if (self.debug and len > 0) {
                const text_slice = memory[@intCast(text_ptr)..@intCast(text_ptr + @as(i32, @intCast(len)))];
                var o = Log.op("WASM4", "text");
                o.log("Text: \"{s}\"\n", .{text_slice});
            }
        }
    }

    _ = x;
    _ = y;
    // TODO: Implement text drawing
    return .{ .i32 = 0 };
}

/// tone(frequency: u32, duration: u32, volume: u32, flags: u32)
fn tone(self: *WASM4, args: []const Value, _: *Runtime) !Value {
    if (args.len != 4) return error.InvalidArgCount;
    
    const frequency = Runtime.asU32(args[0]);
    const duration = Runtime.asU32(args[1]);
    const volume = Runtime.asU32(args[2]);
    const flags = Runtime.asU32(args[3]);

    if (self.debug) {
        var o = Log.op("WASM4", "tone");
        o.log("frequency={d}, duration={d}, volume={d}, flags={d}\n",
            .{ frequency, duration, volume, flags });
    }

    // TODO: Implement audio output
    return .{ .i32 = 0 };
}

/// diskr(dest: ptr, size: u32) -> u32
fn diskr(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 2) return error.InvalidArgCount;
    
    const dest_ptr = Runtime.asI32(args[0]);
    const size = Runtime.asU32(args[1]);

    if (self.debug) {
        var o = Log.op("WASM4", "diskr");
        o.log("dest_ptr={d}, size={d}\n", .{ dest_ptr, size });
    }

    _ = module;
    _ = dest_ptr;
    _ = size;
    // TODO: Implement disk read
    // For now, return 0 (no bytes read)
    return .{ .i32 = 0 };
}

/// diskw(src: ptr, size: u32) -> u32
fn diskw(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 2) return error.InvalidArgCount;
    
    const src_ptr = Runtime.asI32(args[0]);
    const size = Runtime.asU32(args[1]);

    if (self.debug) {
        var o = Log.op("WASM4", "diskw");
        o.log("src_ptr={d}, size={d}\n", .{ src_ptr, size });
    }

    _ = module;
    _ = src_ptr;
    _ = size;
    // TODO: Implement disk write
    // For now, return the size (pretend all bytes were written)
    return .{ .i32 = @intCast(size) };
}

/// trace(text: ptr)
fn trace(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 1) return error.InvalidArgCount;
    
    const text_ptr = Runtime.asI32(args[0]);

    if (module.memory) |memory| {
        if (text_ptr >= 0 and text_ptr < memory.len) {
            // Read null-terminated string from memory
            var len: usize = 0;
            while (text_ptr + @as(i32, @intCast(len)) < memory.len and memory[@intCast(text_ptr + @as(i32, @intCast(len)))] != 0) {
                len += 1;
            }
            
            if (len > 0) {
                const text_slice = memory[@intCast(text_ptr)..@intCast(text_ptr + @as(i32, @intCast(len)))];
                var o = Log.op("WASM4", "trace");
                o.log("[TRACE] {s}\n", .{text_slice});
                
                // Also write to stdout
                const stdout = std.io.getStdOut();
                try stdout.writeAll("[WASM4 TRACE] ");
                try stdout.writeAll(text_slice);
                try stdout.writeAll("\n");
            }
        }
    }

    _ = self;
    return .{ .i32 = 0 };
}

/// tracef(format: ptr, args: ptr)
fn tracef(self: *WASM4, args: []const Value, module: *Module) !Value {
    if (args.len != 2) return error.InvalidArgCount;
    
    const format_ptr = Runtime.asI32(args[0]);
    const args_ptr = Runtime.asI32(args[1]);

    if (self.debug) {
        var o = Log.op("WASM4", "tracef");
        o.log("format_ptr={d}, args_ptr={d}\n", .{ format_ptr, args_ptr });
    }

    _ = module;
    _ = format_ptr;
    _ = args_ptr;
    // TODO: Implement formatted trace
    return .{ .i32 = 0 };
}
