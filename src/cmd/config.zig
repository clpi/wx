const std = @import("std");

pub const Config = struct {
    debug: bool = false,
    validate: bool = true,
    help: bool = false,
    jit: bool = false,
    aot: bool = false,
    aot_output: ?[]const u8 = null,
    version: []const u8 = "0.1.0",
};

fn is(a: []const u8, b: []const u8, s: []const u8) bool {
    return std.mem.eql(u8, a, b) or std.mem.eql(u8, a, s);
}

pub fn fromArgs(args: [][:0]u8) Config {
    var cfg: Config = .{};
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (is(arg, "--debug", "-d")) {
            cfg.debug = true;
        } else if (is(arg, "--jit", "-j")) {
            cfg.jit = true;
        } else if (is(arg, "--aot", "-a") or is(arg, "--compile", "-c")) {
            cfg.aot = true;
        } else if (is(arg, "--output", "-o")) {
            if (i + 1 < args.len) {
                i += 1;
                cfg.aot_output = args[i];
            }
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

