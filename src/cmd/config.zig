const std = @import("std");

pub const Config = struct {
    debug: bool = false,
    validate: bool = true,
    help: bool = false,
    version: []const u8 = "0.1.0",
};

fn is(a: []const u8, b: []const u8, s: []const u8) bool {
    return std.mem.eql(u8, a, b) or std.mem.eql(u8, a, s);
}

pub fn fromArgs(args: [][:0]u8) Config {
    var cfg: Config = .{};
    for (args) |arg| {
        if (is(arg, "--debug", "-d")) {
            cfg.debug = true;
        } else if (is(arg, "--no-validate", "")) {
            cfg.validate = false;
        } else if (is(arg, "--help", "-h")) {
            cfg.help = true;
        } else if (is(arg, "--version", "-v")) {
            // No-op here; caller decides how to handle version display.
        }
    }
    return cfg;
}

