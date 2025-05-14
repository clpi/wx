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

pub fn readBytes(self: *Reader, len: usize) ![]const u8 {
    if (self.pos + len > self.bytes.len) return error.EndOfStream;
    const slice = self.bytes[self.pos .. self.pos + len];
    self.pos += len;
    return slice;
}
