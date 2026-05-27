//! Append option example demonstrating addAppend with getArray retrieval.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "append-demo",
        .version = "1.0.0",
        .description = "Demonstrates append option with array retrieval",
    });
    defer parser.deinit();

    try parser.addAppend("include", .{
        .short = 'I',
        .help = "Include path (can be repeated)",
        .metavar = "DIR",
    });

    try parser.addOption("output", .{
        .short = 'o',
        .help = "Output file",
        .default = "out",
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    const output = result.getString("output") orelse "out";

    if (result.getArray("include")) |includes| {
        std.debug.print("Include paths ({d}):\n", .{includes.len});
        for (includes, 0..) |inc, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, inc });
        }
    } else {
        std.debug.print("No include paths specified\n", .{});
    }

    std.debug.print("Output: {s}\n", .{output});
}
