const Reader = @This();

bytes: []const u8,
pos: usize = 0,

pub fn init(bytes: []const u8) Reader {
    return .{ .bytes = bytes };
}

pub fn readByte(self: *Reader) !u8 {
    if (self.pos >= self.bytes.len) return error.EndOfStream;
    const byte = self.bytes[self.pos];
    self.pos += 1;
    return byte;
}

pub fn readLEB128(self: *Reader) !u32 {
    var result: u32 = 0;
    var shift: u5 = 0;
    while (true) {
        const byte = try self.readByte();
        result |= @as(u32, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) break;
        shift += 7;
    }
    return result;
}

// Read signed LEB128 into i32
pub fn readSLEB32(self: *Reader) !i32 {
    var result: u32 = 0;
    var shift: u8 = 0;
    var byte: u8 = 0;

    while (true) {
        byte = try self.readByte();
        const low = @as(u32, byte & 0x7F);
        result |= (low << @as(u5, @intCast(shift)));
        shift += 7;
        if (byte & 0x80 == 0) break;
    }

    // sign extend if needed
    if (shift < 32 and (byte & 0x40) != 0) {
        result |= (@as(u32, 0xFFFFFFFF) << @as(u5, @intCast(shift)));
    }

    return @as(i32, @bitCast(result));
}

// Read signed LEB128 into i64
pub fn readSLEB64(self: *Reader) !i64 {
    var result: i64 = 0;
    var shift: u6 = 0;
    var byte: u8 = 0;
    while (true) {
        byte = try self.readByte();
        const low = @as(i64, @intCast(byte & 0x7F));
        result |= (low << shift);
        shift += 7;
        if (byte & 0x80 == 0) break;
    }
    if (shift < 64 and (byte & 0x40) != 0) {
        result |= @as(i64, -1) << shift;
    }
    return result;
}

pub fn readBytes(self: *Reader, len: usize) ![]const u8 {
    if (self.pos + len > self.bytes.len) return error.EndOfStream;
    const slice = self.bytes[self.pos .. self.pos + len];
    self.pos += len;
    return slice;
}
