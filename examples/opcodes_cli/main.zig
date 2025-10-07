const std = @import("std");

pub fn main() !void {
    // Simple WASI CLI for opcodes testing
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Opcodes CLI - Basic operations test\n", .{});
    
    // Do some simple computations
    const result = compute();
    try stdout.print("Result: {d}\n", .{result});
}

fn compute() i32 {
    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        sum += i * 2;
    }
    return sum;
}
