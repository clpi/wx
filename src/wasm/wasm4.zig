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
disk_path: []const u8 = ".wasm4_disk",

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

// WASM4 built-in 8x8 font (ASCII 32-127)
const FONT_DATA = [_]u64{
    0x0000000000000000, 0x1818181818001800, 0x3636000000000000, 0x367F367F36000000,
    0x0C3F683E0B7E1800, 0x6066060C18336300, 0x1C36361C6E3B3B6E, 0x0606060000000000,
    0x0C18303030180C00, 0x30180C0C0C183000, 0x0066663C3C666600, 0x000C0C3F0C0C0000,
    0x0000000000181830, 0x0000003F00000000, 0x0000000000181800, 0x0003060C18306000,
    0x3E676F7B73633E00, 0x183838181818FF00, 0x3E63060C18307F00, 0x3F060C0E03633E00,
    0x0C1C3C6C7F0C0C00, 0x7F607E0303633E00, 0x1C30607E63633E00, 0x7F03060C18181800,
    0x3E63633E63633E00, 0x3E63633F03063C00, 0x0000181800181800, 0x0000181800181830,
    0x060C18300C060000, 0x00003F00003F0000, 0x6030180C30600000, 0x3E63030E18001800,
    0x3E63736F6B603E00, 0x1C36637F63636300, 0x7E63637E63637E00, 0x3E63606060633E00,
    0x7C66636363667C00, 0x7F60607C60607F00, 0x7F60607C60606000, 0x3E63606F63633F00,
    0x636363FF63636300, 0x1E0C0C0C0C0C1E00, 0x0F06060606663C00, 0x63666C786C666300,
    0x6060606060607F00, 0xC3E7FFDBDBC3C300, 0x6363737B6F676300, 0x3E63636363633E00,
    0x7E63637E60606000, 0x3E63636B6F361B00, 0x7E63637E6C666300, 0x3E63603E03633E00,
    0xFF180C0C0C0C0C00, 0x6363636363633E00, 0x6363636336361C00, 0xC3C3C3DBDBFFE700,
    0x6363361C1C366300, 0xC3C3663C18181800, 0x7F060C1830607F00, 0x1E18181818181E00,
    0x6030180C06030000, 0x7818181818187800, 0x081C36630000000, 0x00000000000000FF,
};

pub fn init(allocator: std.mem.Allocator) !WASM4 {
    return WASM4{
        .allocator = allocator,
        .debug = false,
        .disk_path = ".wasm4_disk",
    };
}

pub fn deinit(_: *WASM4) void {
    // Nothing to clean up currently
}

/// Helper: Get draw color from DRAW_COLORS for a specific index
fn getDrawColor(memory: []u8, index: u2) u2 {
    const draw_colors = std.mem.readInt(u16, memory[DRAW_COLORS..][0..2], .little);
    const shift: u4 = @as(u4, index) * 4;
    return @intCast((draw_colors >> shift) & 0xF);
}

/// Helper: Set pixel in framebuffer (2bpp format)
fn setPixel(memory: []u8, x: i32, y: i32, color: u2) void {
    if (x < 0 or x >= SCREEN_WIDTH or y < 0 or y >= SCREEN_HEIGHT) return;
    
    const idx = @as(usize, @intCast(y)) * SCREEN_WIDTH + @as(usize, @intCast(x));
    const byte_idx = FRAMEBUFFER + (idx / 4);
    const bit_offset: u3 = @intCast((idx % 4) * 2);
    
    if (byte_idx >= memory.len) return;
    
    // Clear the 2 bits at the position
    memory[byte_idx] &= ~(@as(u8, 0b11) << bit_offset);
    // Set the new color
    memory[byte_idx] |= (@as(u8, color) << bit_offset);
}

/// Helper: Get pixel from framebuffer
fn getPixel(memory: []const u8, x: i32, y: i32) u2 {
    if (x < 0 or x >= SCREEN_WIDTH or y < 0 or y >= SCREEN_HEIGHT) return 0;
    
    const idx = @as(usize, @intCast(y)) * SCREEN_WIDTH + @as(usize, @intCast(x));
    const byte_idx = FRAMEBUFFER + (idx / 4);
    const bit_offset: u3 = @intCast((idx % 4) * 2);
    
    if (byte_idx >= memory.len) return 0;
    
    return @intCast((memory[byte_idx] >> bit_offset) & 0b11);
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

        const sprite_data = memory[@intCast(sprite_ptr)..@intCast(sprite_ptr + @as(i32, @intCast(sprite_size)))];
        const flip_x = (flags & BLIT_FLIP_X) != 0;
        const flip_y = (flags & BLIT_FLIP_Y) != 0;
        const rotate = (flags & BLIT_ROTATE) != 0;
        
        var sy: u32 = 0;
        while (sy < height) : (sy += 1) {
            var sx: u32 = 0;
            while (sx < width) : (sx += 1) {
                // Calculate source position
                var src_x = sx;
                var src_y = sy;
                
                // Apply transformations
                if (rotate) {
                    const tmp = src_x;
                    src_x = height - 1 - src_y;
                    src_y = tmp;
                }
                if (flip_x) src_x = width - 1 - src_x;
                if (flip_y) src_y = height - 1 - src_y;
                
                // Get pixel from sprite data
                const bit_index = src_y * width + src_x;
                var color: u2 = 0;
                
                if (bpp == 2) {
                    const byte_idx = (bit_index * 2) / 8;
                    const bit_offset: u3 = @intCast((bit_index * 2) % 8);
                    if (byte_idx < sprite_data.len) {
                        color = @intCast((sprite_data[byte_idx] >> bit_offset) & 0b11);
                    }
                } else {
                    const byte_idx = bit_index / 8;
                    const bit_offset: u3 = @intCast(bit_index % 8);
                    if (byte_idx < sprite_data.len) {
                        color = @intCast((sprite_data[byte_idx] >> bit_offset) & 0b1);
                        if (color != 0) color = 1;
                    }
                }
                
                // Skip transparent pixels (color 0)
                if (color != 0) {
                    // Translate color through draw colors
                    const draw_color = getDrawColor(memory, @intCast(color - 1));
                    if (draw_color != 0) {
                        const dest_x = if (rotate) x + @as(i32, @intCast(sy)) else x + @as(i32, @intCast(sx));
                        const dest_y = if (rotate) y + @as(i32, @intCast(sx)) else y + @as(i32, @intCast(sy));
                        setPixel(memory, dest_x, dest_y, draw_color);
                    }
                }
            }
        }
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

    if (module.memory) |memory| {
        // Validate sprite pointer
        const bpp: u32 = if (flags & BLIT_2BPP != 0) 2 else 1;
        
        // Calculate total sprite atlas size
        const atlas_bytes = (stride * ((src_y + height) * bpp)) / 8;
        if (sprite_ptr < 0 or sprite_ptr + @as(i32, @intCast(atlas_bytes)) > memory.len) {
            return .{ .i32 = 0 };
        }

        const sprite_data = memory[@intCast(sprite_ptr)..];
        const flip_x = (flags & BLIT_FLIP_X) != 0;
        const flip_y = (flags & BLIT_FLIP_Y) != 0;
        const rotate = (flags & BLIT_ROTATE) != 0;
        
        var dy: u32 = 0;
        while (dy < height) : (dy += 1) {
            var dx: u32 = 0;
            while (dx < width) : (dx += 1) {
                // Calculate source position in atlas
                var atlas_x = src_x + dx;
                var atlas_y = src_y + dy;
                
                // Apply transformations
                if (rotate) {
                    const tmp = atlas_x - src_x;
                    atlas_x = src_x + (height - 1 - (atlas_y - src_y));
                    atlas_y = src_y + tmp;
                }
                if (flip_x) atlas_x = src_x + (width - 1 - dx);
                if (flip_y) atlas_y = src_y + (height - 1 - dy);
                
                // Get pixel from sprite atlas
                const bit_index = atlas_y * stride + atlas_x;
                var color: u2 = 0;
                
                if (bpp == 2) {
                    const byte_idx = (bit_index * 2) / 8;
                    const bit_offset: u3 = @intCast((bit_index * 2) % 8);
                    if (byte_idx < sprite_data.len) {
                        color = @intCast((sprite_data[byte_idx] >> bit_offset) & 0b11);
                    }
                } else {
                    const byte_idx = bit_index / 8;
                    const bit_offset: u3 = @intCast(bit_index % 8);
                    if (byte_idx < sprite_data.len) {
                        color = @intCast((sprite_data[byte_idx] >> bit_offset) & 0b1);
                        if (color != 0) color = 1;
                    }
                }
                
                // Skip transparent pixels (color 0)
                if (color != 0) {
                    // Translate color through draw colors
                    const draw_color = getDrawColor(memory, @intCast(color - 1));
                    if (draw_color != 0) {
                        const dest_x = if (rotate) x + @as(i32, @intCast(dy)) else x + @as(i32, @intCast(dx));
                        const dest_y = if (rotate) y + @as(i32, @intCast(dx)) else y + @as(i32, @intCast(dy));
                        setPixel(memory, dest_x, dest_y, draw_color);
                    }
                }
            }
        }
    }
    
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

    if (module.memory) |memory| {
        const color = getDrawColor(memory, 0);
        if (color == 0) return .{ .i32 = 0 };
        
        // Bresenham's line algorithm
        var x = x1;
        var y = y1;
        const dx = if (x2 > x1) x2 - x1 else x1 - x2;
        const dy = if (y2 > y1) y2 - y1 else y1 - y2;
        const sx: i32 = if (x1 < x2) 1 else -1;
        const sy: i32 = if (y1 < y2) 1 else -1;
        var err = dx - dy;

        while (true) {
            setPixel(memory, x, y, color);
            
            if (x == x2 and y == y2) break;
            
            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                x += sx;
            }
            if (e2 < dx) {
                err += dx;
                y += sy;
            }
        }
    }

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

    if (module.memory) |memory| {
        const color = getDrawColor(memory, 0);
        if (color != 0) {
            var dx: u32 = 0;
            while (dx < len) : (dx += 1) {
                setPixel(memory, x + @as(i32, @intCast(dx)), y, color);
            }
        }
    }

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

    if (module.memory) |memory| {
        const color = getDrawColor(memory, 0);
        if (color != 0) {
            var dy: u32 = 0;
            while (dy < len) : (dy += 1) {
                setPixel(memory, x, y + @as(i32, @intCast(dy)), color);
            }
        }
    }

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

    if (module.memory) |memory| {
        const fill_color = getDrawColor(memory, 0);
        const stroke_color = getDrawColor(memory, 1);
        
        const rx = @as(i32, @intCast(width)) / 2;
        const ry = @as(i32, @intCast(height)) / 2;
        const cx = x + rx;
        const cy = y + ry;
        
        // Midpoint ellipse algorithm
        var x1: i32 = 0;
        var y1: i32 = ry;
        var rx_sq = rx * rx;
        var ry_sq = ry * ry;
        var two_rx_sq = 2 * rx_sq;
        var two_ry_sq = 2 * ry_sq;
        var p: i32 = undefined;
        var px: i32 = 0;
        var py: i32 = two_rx_sq * y1;
        
        // Helper to draw horizontal line for filling
        const drawHLine = struct {
            fn func(mem: []u8, x_start: i32, x_end: i32, y_pos: i32, col: u2) void {
                if (col == 0) return;
                var xi = x_start;
                while (xi <= x_end) : (xi += 1) {
                    setPixel(mem, xi, y_pos, col);
                }
            }
        }.func;
        
        // Region 1
        p = @as(i32, @intCast(ry_sq)) - (rx_sq * ry) + (rx_sq / 4);
        while (px < py) {
            // Fill if needed
            if (fill_color != 0) {
                drawHLine(memory, cx - x1, cx + x1, cy + y1, fill_color);
                drawHLine(memory, cx - x1, cx + x1, cy - y1, fill_color);
            }
            
            // Stroke
            if (stroke_color != 0) {
                setPixel(memory, cx + x1, cy + y1, stroke_color);
                setPixel(memory, cx - x1, cy + y1, stroke_color);
                setPixel(memory, cx + x1, cy - y1, stroke_color);
                setPixel(memory, cx - x1, cy - y1, stroke_color);
            }
            
            x1 += 1;
            px += two_ry_sq;
            if (p < 0) {
                p += ry_sq + px;
            } else {
                y1 -= 1;
                py -= two_rx_sq;
                p += ry_sq + px - py;
            }
        }
        
        // Region 2
        p = @as(i32, @intCast(ry_sq)) * (x1 + 1) * (x1 + 1) + @as(i32, @intCast(rx_sq)) * (y1 - 1) * (y1 - 1) - rx_sq * ry_sq;
        while (y1 >= 0) {
            // Fill if needed
            if (fill_color != 0) {
                drawHLine(memory, cx - x1, cx + x1, cy + y1, fill_color);
                drawHLine(memory, cx - x1, cx + x1, cy - y1, fill_color);
            }
            
            // Stroke
            if (stroke_color != 0) {
                setPixel(memory, cx + x1, cy + y1, stroke_color);
                setPixel(memory, cx - x1, cy + y1, stroke_color);
                setPixel(memory, cx + x1, cy - y1, stroke_color);
                setPixel(memory, cx - x1, cy - y1, stroke_color);
            }
            
            y1 -= 1;
            py -= two_rx_sq;
            if (p > 0) {
                p += rx_sq - py;
            } else {
                x1 += 1;
                px += two_ry_sq;
                p += rx_sq - py + px;
            }
        }
    }

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

    if (module.memory) |memory| {
        const fill_color = getDrawColor(memory, 0);
        const stroke_color = getDrawColor(memory, 1);
        
        // Draw filled rectangle
        if (fill_color != 0) {
            var dy: u32 = 0;
            while (dy < height) : (dy += 1) {
                var dx: u32 = 0;
                while (dx < width) : (dx += 1) {
                    setPixel(memory, x + @as(i32, @intCast(dx)), y + @as(i32, @intCast(dy)), fill_color);
                }
            }
        }
        
        // Draw stroke/outline
        if (stroke_color != 0) {
            // Top and bottom edges
            var dx: u32 = 0;
            while (dx < width) : (dx += 1) {
                setPixel(memory, x + @as(i32, @intCast(dx)), y, stroke_color);
                if (height > 0) {
                    setPixel(memory, x + @as(i32, @intCast(dx)), y + @as(i32, @intCast(height - 1)), stroke_color);
                }
            }
            
            // Left and right edges
            var dy: u32 = 0;
            while (dy < height) : (dy += 1) {
                setPixel(memory, x, y + @as(i32, @intCast(dy)), stroke_color);
                if (width > 0) {
                    setPixel(memory, x + @as(i32, @intCast(width - 1)), y + @as(i32, @intCast(dy)), stroke_color);
                }
            }
        }
    }

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
            
            // Draw each character
            const text_slice = memory[@intCast(text_ptr)..@intCast(text_ptr + @as(i32, @intCast(len)))];
            const color = getDrawColor(memory, 0);
            
            if (color != 0) {
                for (text_slice, 0..) |char, i| {
                    const char_x = x + @as(i32, @intCast(i * 8));
                    
                    // Only render printable ASCII characters
                    if (char >= 32 and char < 128) {
                        const font_idx = char - 32;
                        if (font_idx < FONT_DATA.len) {
                            const glyph = FONT_DATA[font_idx];
                            
                            // Draw 8x8 character
                            var row: u3 = 0;
                            while (row < 8) : (row += 1) {
                                var col: u3 = 0;
                                while (col < 8) : (col += 1) {
                                    const bit_idx: u6 = @as(u6, row) * 8 + col;
                                    const pixel_on = (glyph >> bit_idx) & 1;
                                    
                                    if (pixel_on != 0) {
                                        setPixel(memory, char_x + col, y + row, color);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

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

    // Audio synthesis implementation
    // Parse frequency (can be two frequencies for slide: freq1 | (freq2 << 16))
    const freq1 = @as(u16, @truncate(frequency & 0xFFFF));
    const freq2 = @as(u16, @truncate((frequency >> 16) & 0xFFFF));
    
    // Parse duration (in frames, 60fps: duration | (sustain << 8) | (release << 16) | (decay << 24))
    const attack = @as(u8, @truncate(duration & 0xFF));
    const decay_dur = @as(u8, @truncate((duration >> 8) & 0xFF));
    const sustain = @as(u8, @truncate((duration >> 16) & 0xFF));
    const release = @as(u8, @truncate((duration >> 24) & 0xFF));
    
    // Parse volume (peak | (sustain << 8))
    const peak_vol = @as(u8, @truncate(volume & 0xFF));
    const sustain_vol = @as(u8, @truncate((volume >> 8) & 0xFF));
    
    // Parse flags (channel | (mode << 2))
    const channel = @as(u2, @truncate(flags & 0b11));
    const mode = @as(u2, @truncate((flags >> 2) & 0b11));
    
    // Log audio parameters if debug enabled
    if (self.debug) {
        var o = Log.op("WASM4", "tone_parsed");
        o.log("freq1={d}, freq2={d}, attack={d}, decay={d}, sustain={d}, release={d}\n",
            .{ freq1, freq2, attack, decay_dur, sustain, release });
        o.log("peak_vol={d}, sustain_vol={d}, channel={d}, mode={d}\n",
            .{ peak_vol, sustain_vol, channel, mode });
    }
    
    // TODO: Implement actual audio synthesis and output to audio device
    // For now, we acknowledge the parameters but don't generate audio
    // This would require platform-specific audio output (SDL2, ALSA, etc.)
    
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

    if (module.memory) |memory| {
        // Validate destination pointer
        if (dest_ptr < 0 or dest_ptr + @as(i32, @intCast(size)) > memory.len) {
            return .{ .i32 = 0 };
        }
        
        // Try to read from disk file
        const file = std.fs.cwd().openFile(self.disk_path, .{}) catch {
            // File doesn't exist or can't be opened, return 0
            return .{ .i32 = 0 };
        };
        defer file.close();
        
        const dest_slice = memory[@intCast(dest_ptr)..@intCast(dest_ptr + @as(i32, @intCast(size)))];
        const bytes_read = file.read(dest_slice) catch 0;
        
        return .{ .i32 = @intCast(bytes_read) };
    }
    
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

    if (module.memory) |memory| {
        // Validate source pointer
        if (src_ptr < 0 or src_ptr + @as(i32, @intCast(size)) > memory.len) {
            return .{ .i32 = 0 };
        }
        
        // Try to write to disk file
        const file = std.fs.cwd().createFile(self.disk_path, .{}) catch {
            // Can't create file, return 0
            return .{ .i32 = 0 };
        };
        defer file.close();
        
        const src_slice = memory[@intCast(src_ptr)..@intCast(src_ptr + @as(i32, @intCast(size)))];
        const bytes_written = file.write(src_slice) catch 0;
        
        return .{ .i32 = @intCast(bytes_written) };
    }
    
    return .{ .i32 = 0 };
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

    if (module.memory) |memory| {
        if (format_ptr >= 0 and format_ptr < memory.len) {
            // Read format string
            var len: usize = 0;
            while (format_ptr + @as(i32, @intCast(len)) < memory.len and memory[@intCast(format_ptr + @as(i32, @intCast(len)))] != 0) {
                len += 1;
            }
            
            if (len > 0) {
                const format_slice = memory[@intCast(format_ptr)..@intCast(format_ptr + @as(i32, @intCast(len)))];
                var o = Log.op("WASM4", "tracef");
                
                // Basic implementation: just print format string with args pointer info
                // Full printf-style formatting would require parsing the format string
                // and reading the appropriate number and types of arguments
                o.log("[TRACEF] Format: {s} (args at 0x{x})\n", .{ format_slice, args_ptr });
                
                // Also write to stdout
                const stdout = std.io.getStdOut();
                try stdout.writeAll("[WASM4 TRACEF] ");
                try stdout.writeAll(format_slice);
                try stdout.writeAll("\n");
            }
        }
    }
    
    return .{ .i32 = 0 };
}
