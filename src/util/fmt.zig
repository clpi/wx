const std = @import("std");
const str = []const u8;
const debug = std.debug;
pub const Color = @import("fmt/color.zig");
const config = @import("../cmd/config.zig");

// Global logger switch. Set to true only when you want verbose tracing.
pub const ENABLE_LOG: bool = false;

pub const Error = error{
    Memory,
    FormattingError,
};

pub fn print(comptime fmt: []const u8, args: anytype, color: []const u8) void {
    var buf: [1024]u8 = undefined;
    const printed = std.fmt.bufPrint(buf[0..], fmt, args) catch "Error formatting string";
    std.debug.print("{s}{s}{s}\n", .{ color, printed, Color.reset });
}

/// Enum for the different types of messages that can be logged
pub const Message = enum(u3) {
    warning,
    @"error",
    opcode,
    debug,
    info,
    trace,
};

/// Struct for opcode messages
pub const Op = struct {
    debug: bool,
    kind: str,
    name: []const u8,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

/// Struct for error messages
pub const Err = struct {
    debug: bool,
    kind: []const u8,
    msg: str,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

/// Struct for warning messages
pub const Warning = struct {
    kind: []const u8,
    debug: bool,
    msg: str,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

/// Struct for debug messages
pub const Debug = struct {
    name: []const u8,
    debug: bool,
    msg: str,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

/// Struct for info messages
pub const Info = struct {
    name: []const u8,
    msg: str,
    debug: bool,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

/// Struct for trace messages
pub const Trace = struct {
    name: []const u8,
    msg: str,
    debug: bool,
    pub fn new(name: []const u8, msg: str) @This() {
        return .{ .name = name, .msg = msg, .debug = true };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
        };
    }
};

pub const Msg = struct {
    a: []const u8,
    b: []const u8,
    name: []const u8,

    pub fn new(a: []const u8, b: []const u8) @This() {
        return .{ .a = a, .b = b };
    }
    pub fn msg(name: []const u8, comptime fmt: []const u8, args: anytype) @This() {
        return .{ .name = name, .fmt = fmt, .args = args };
    }
    pub fn log(self: @This(), kind: Message) Log {
        return switch (kind) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = self.msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = self.msg } },
            .opcode => .{ .opcode = .{ .debug = true, .kind = "opcode", .name = self.name } },
            .debug => .{ .debug = .{ .debug = true, .kind = "debug", .msg = self.msg } },
            .info => .{ .info = .{ .debug = true, .kind = "info", .msg = self.msg } },
            .trace => .{ .trace = .{ .debug = true, .kind = "trace", .msg = self.msg } },
        };
    }

    pub fn dbg(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.debug)).log(fmt, args);
    }
    pub fn inf(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.info)).log(fmt, args);
    }
    pub fn warn(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.warning)).log(fmt, args);
    }
    pub fn trc(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.trace)).log(fmt, args);
    }
    pub fn op(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.opcode)).log(fmt, args);
    }
    pub fn err(self: @This(), comptime fmt: str, args: anytype) void {
        Log.err(self.into(.@"error")).log(fmt, args);
    }
};

/// Union for all message types
pub const Log = union(Message) {
    warning: Warning,
    @"error": Err,
    opcode: Op,
    debug: Debug,
    info: Info,
    trace: Trace,

    pub fn new(name: []const u8, msg: Message) @This() {
        return switch (msg) {
            .warning => .{ .warning = .{ .debug = true, .kind = "warning", .msg = msg } },
            .@"error" => .{ .@"error" = .{ .debug = true, .kind = "error", .msg = msg } },
            .opcode => .{ .opcode = .{ .debug = true, .kind = "opcode", .name = name } },
            .debug => .{ .debug = .{ .debug = true, .kind = "debug", .msg = msg } },
            .info => .{ .info = .{ .debug = true, .kind = "info", .msg = msg } },
            .trace => .{ .trace = .{ .debug = true, .kind = "trace", .msg = msg } },
        };
    }

    /// Logs a message based on the type of message
    pub fn log(self: @This(), comptime fmt: []const u8, args: anytype) void {
        if (!ENABLE_LOG) return;
        return switch (self) {
            Log.warning => |e| {
                if (!e.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}[WARN: {s}]{s}{s} {s}: {s}{s}\n", .{ Color.yellow, Color.bold, e.kind, Color.reset, Color.yellow, e.msg, p, Color.reset });
            },
            Log.@"error" => |e| {
                if (!e.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}[ERROR: {s}]{s}{s} {s}: {s}{s}\n", .{ Color.red, Color.bold, e.kind, Color.reset, Color.red, e.msg, p, Color.reset });
            },
            Log.opcode => |o| {
                if (!o.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}{s}.{s}{s}: {s}{s}{s}\n", .{ Color.yellow, o.kind, Color.white, Color.green, o.name, Color.cyan, p, Color.reset });
            },
            Log.debug => |e| {
                if (!e.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}[DBG: {s}]{s}{s} {s}: {s}{s}\n", .{ Color.magenta, Color.bold, e.name, Color.reset, Color.yellow, e.msg, p, Color.reset });
            },
            Log.info => |e| {
                if (!e.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}[INFO: {s}]{s}{s} {s}: {s}{s}\n", .{ Color.blue, Color.bold, e.name, Color.reset, Color.yellow, e.msg, p, Color.reset });
            },
            Log.trace => |e| {
                if (!e.debug) return;
                var b: [1024]u8 = undefined;
                const p = std.fmt.bufPrint(b[0..], fmt, args) catch "Error formatting string";
                debug.print("{s}{s}[TRC: {s}]{s}{s} {s}: {s}{s}\n", .{ Color.green, Color.bold, e.name, Color.reset, Color.yellow, e.msg, p, Color.reset });
            },
        };
    }

    /// Creates a debug message
    pub fn dbg(k: str, n: str) Log {
        return .{ .debug = .{ .debug = true, .kind = k, .msg = n } };
    }

    /// Creates an info message
    pub fn inf(k: str, n: str) Log {
        return .{ .info = .{ .debug = true, .kind = k, .msg = n } };
    }

    /// Creates an error message
    pub fn err(k: str, n: str) Log {
        return .{ .@"error" = .{ .debug = true, .kind = k, .msg = n } };
    }

    /// Creates an opcode message
    pub fn op(k: str, n: str) Log {
        return .{ .opcode = .{ .debug = true, .kind = k, .name = n } };
    }

    /// Creates a warning message
    pub fn warn(k: str, n: str) Log {
        return .{ .warning = .{ .debug = true, .kind = k, .msg = n } };
    }

    /// Creates a trace message
    pub fn trc(k: str, n: str) Log {
        return .{ .trace = .{ .debug = true, .kind = k, .msg = n } };
    }
};
