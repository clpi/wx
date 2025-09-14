const std = @import("std");

pub fn SmallVec(comptime T: type, comptime INLINE: usize) type {
    return struct {
        const Self = @This();

        // Inline storage
        inline_buf: [INLINE]T = undefined,
        // Active view of elements
        items: []T = &[_]T{},
        // Mode and capacity
        using_heap: bool = false,
        heap_buf: []T = &[_]T{},
        capacity: usize = INLINE,

        pub fn init() Self {
            var s: Self = .{};
            s.items = s.inline_buf[0..0];
            s.capacity = INLINE;
            s.using_heap = false;
            return s;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.using_heap and self.heap_buf.len > 0) {
                allocator.free(self.heap_buf);
                self.heap_buf = &[_]T{};
            }
            self.items = &[_]T{};
            self.using_heap = false;
            self.capacity = INLINE;
        }

        pub fn ensureTotalCapacity(self: *Self, allocator: std.mem.Allocator, n: usize) !void {
            if (!self.using_heap) {
                if (n <= INLINE) return; // inline is enough
                // switch to heap
                var new_cap: usize = n;
                if (new_cap < INLINE * 2) new_cap = INLINE * 2;
                const buf = try allocator.alloc(T, new_cap);
                // copy inline content
                std.mem.copyForwards(T, buf[0..self.items.len], self.inline_buf[0..self.items.len]);
                self.heap_buf = buf;
                self.using_heap = true;
                self.capacity = new_cap;
                self.items = self.heap_buf[0..self.items.len];
                return;
            }
            if (n <= self.capacity) return;
            // grow heap
            var new_cap: usize = self.capacity * 2;
            if (new_cap < n) new_cap = n;
            const buf = try allocator.alloc(T, new_cap);
            std.mem.copyForwards(T, buf[0..self.items.len], self.heap_buf[0..self.items.len]);
            allocator.free(self.heap_buf);
            self.heap_buf = buf;
            self.capacity = new_cap;
            self.items = self.heap_buf[0..self.items.len];
        }

        pub fn append(self: *Self, allocator: std.mem.Allocator, v: T) !void {
            if (self.items.len == self.capacity) {
                try self.ensureTotalCapacity(allocator, self.capacity * 2);
            }
            if (self.using_heap) {
                self.heap_buf[self.items.len] = v;
                self.items = self.heap_buf[0 .. self.items.len + 1];
            } else {
                self.inline_buf[self.items.len] = v;
                self.items = self.inline_buf[0 .. self.items.len + 1];
            }
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.len == 0) return null;
            const idx = self.items.len - 1;
            const val = if (self.using_heap) self.heap_buf[idx] else self.inline_buf[idx];
            if (self.using_heap) {
                self.items = self.heap_buf[0..idx];
            } else {
                self.items = self.inline_buf[0..idx];
            }
            return val;
        }

        pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void {
            if (new_len >= self.items.len) return;
            if (self.using_heap) {
                self.items = self.heap_buf[0..new_len];
            } else {
                self.items = self.inline_buf[0..new_len];
            }
        }
    };
}
