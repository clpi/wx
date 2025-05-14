const std = @import("std");
const Log = @import("../util/fmt.zig").Log;
const str = []const u8;
pub const Config = @This();

dir: ?[]const u8 = undefined,
file: ?[]const u8 = undefined,
config: @import("../config.zig"),
debug: bool = false,
help: bool = false,
version: []const u8 = "0.1.0",

pub fn dbg() bool {
    return @This().debug;
}
pub fn init() @This() {
    return .{
        .config = .{
            .config_file = "",
            .config_dir = "",
        },
        .dir = null,
        .file = null,
        .debug = false,
        .version = "0.1.0",
        .help = false,
    };
}

pub fn getDebug(self: @This()) bool {
    return self.debug;
}

pub fn setHelp(self: @This(), b: bool) void {
    self.help = b;
}

pub fn setDebug(self: @This(), b: bool) void {
    self.debug = b;
}

pub fn getHelp(self: @This()) bool {
    return self.help;
}

pub fn getVersion(self: @This()) []const u8 {
    return self.version;
}

pub fn is(a: []const u8, b: []const u8, s: []const u8) bool {
    return std.mem.eql(u8, a, b) or std.mem.eql(u8, a, s);
}

pub fn fromArgs(args: [][:0]u8) @This() {
    var o = init();
    var ol = Log.op("Config", "fromArgs");
    for (args) |arg| {
        if (is(arg, "--debug", "-d"))
            o.debug = true
        else if (is(arg, "--version", "-v"))
            ol.log("Version: {s}\n", .{o.version})
        else if (is(arg, "--help", "-h"))
            o.help = true
        else
            ol.log("Unknown argument: {s}\n", .{arg});
    }
    return o;
}
