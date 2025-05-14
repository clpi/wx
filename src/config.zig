const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const proc = std.process;

const Config = @This();

subcmd: [:0]u8 = undefined,
args: std.ArrayList(Opt) = std.ArrayList(Opt).init(heap.page_allocator),
cmds: std.ArrayList(Opt) = std.ArrayList(Opt).init(heap.page_allocator),
config: std.StringHashMap([]const u8) = std.StringHashMap([]const u8).init(heap.page_allocator),
config_file: []const u8,
config_dir: []const u8,

pub const Opt = struct { long: []const u8, short: []const u8, desc: []const u8, cb: *const fn (c: *Config) void = undefined };

const ARGS = &[9]Opt{
    .{
        .long = "--config",
        .short = "-C",
        .desc = "Edit config",
    },
    .{
        .long = "--help",
        .short = "-h",
        .desc = "Show help",
    },
    .{
        .long = "--version",
        .short = "-v",
        .desc = "Show version",
    },
    .{
        .long = "--debug",
        .short = "-d",
        .desc = "Show debug",
    },
    .{
        .long = "--input",
        .short = "-i",
        .desc = "Show input",
    },
    .{
        .long = "--color",
        .short = "-C",
        .desc = "Show color",
    },
    .{
        .long = "--profile",
        .short = "-P",
        .desc = "Show profile",
    },
    .{
        .long = "--optimize",
        .short = "-O",
        .desc = "Show optimize",
    },
    .{
        .long = "--output",
        .short = "-o",
        .desc = "Show output",
    },
};

const CMDS = &[13]Opt{
    .{
        .long = "init",
        .short = "i",
        .desc = "Initialize the project",
    },
    .{
        .long = "build",
        .short = "b",
        .desc = "Build the program",
    },
    .{
        .long = "run",
        .short = "r",
        .desc = "Run the program",
    },
    .{
        .long = "bench",
        .short = "B",
        .desc = "Benchmark the program",
    },
    .{
        .long = "rm",
        .short = "remove",
        .desc = "Remove the program",
    },
    .{
        .long = "add",
        .short = "a",
        .desc = "Add a dependency",
    },
    .{
        .long = "test",
        .short = "t",
        .desc = "Test the program",
    },
    .{
        .long = "serve",
        .short = "S",
        .desc = "Serve",
    },
    .{
        .long = "list",
        .short = "ls",
        .desc = "List the program",
    },
    .{
        .long = "info",
        .short = "i",
        .desc = "Show information about the project",
    },
    .{
        .long = "profile",
        .short = "p",
        .desc = "Profile the program",
    },
    .{
        .long = "clean",
        .short = "c",
        .desc = "Clean the program",
    },
    .{
        .long = "help",
        .short = "h",
        .desc = "Show help",
    },
    .{
        .long = "version",
        .short = "v",
        .desc = "Show version",
    },
};

pub fn eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

pub fn match(a: []const u8, l: []const u8, s: []const u8) bool {
    return eq(a, l) or eq(a, s);
}

pub fn parseCmd(l: [:0]u8) bool {
    for (CMDS) |cmd|
        if (match(l, cmd.long, cmd.short))
            return true;
    return false;
}
pub fn parseArg(l: [:0]u8) bool {
    for (ARGS) |arg|
        if (match(l, arg.long, arg.short))
            return true;
    return false;
}

pub fn parseArgs(a: mem.Allocator, args: []const [:0]u8) !@This() {
    var c = Config{
        .config = std.StringHashMap([]const u8).init(a),
        .args = std.ArrayList(Opt).init(a),
        .cmds = std.ArrayList(Opt).init(a),
        .subcmd = undefined,
    };

    var first = true;
    for (args) |ag| {
        const pcmd = parseCmd(ag);
        const parg = parseArg(ag);
        const r = pcmd or parg;
        if (r) {
            std.debug.print("arg: {s}\n", .{ag});
            if (first and pcmd) {
                c.subcmd = ag;
                std.debug.print("subcmd: {s}\n", .{ag});
                try c.cmds.append(Opt{ .long = ag, .short = undefined, .desc = undefined, .cb = undefined });
                continue;
            } else if (pcmd) {
                try c.cmds.append(Opt{ .long = ag, .short = undefined, .desc = undefined, .cb = undefined });
            } else if (parg) {
                try c.args.append(Opt{ .long = ag, .short = undefined, .desc = undefined, .cb = undefined });
            }
        }
        first = false;
    }
    return c;
}

pub fn parse(a: mem.Allocator) !@This() {
    const as = try std.process.argsAlloc(a);
    return parseArgs(a, as);
}

test "parse cmd" {

    // std.debug.print("c: {s}\n", .{c.subcmd});
    // std.debug.print("c.subcmd: {any}\n", .{c.subcmd});
    // std.debug.print("c.opts: {any}\n", .{c.opts});
    // std.debug.print("c.csting: {any}\n", .{c.csting});

    // try std.testing.expectEqual(c.subcmd, "--config");
    return true;
}
