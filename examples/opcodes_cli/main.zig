const std = @import("std");

pub fn main() !void {
    // Simple WASI CLI for opcodes testing
    const stdout = std.fs.File.stdout();
    try stdout.writeAll("Opcodes CLI - Basic operations test\n");
    
    // Do some simple computations
    const result = compute();
    
    // Print result
    var buf: [100]u8 = undefined;
    const msg = try std.fmt.bufPrint(&buf, "Result: {d}\n", .{result});
    try stdout.writeAll(msg);
}

fn compute() i32 {
    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        sum += i * 2;
    }
    return sum;
}
