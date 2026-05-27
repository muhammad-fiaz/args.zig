//! Multi-value (variadic n-args) example demonstrating addMultiple.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "multi-value",
        .version = "1.0.0",
        .description = "Demonstrates multi-value (variadic n-args) options",
    });
    defer parser.deinit();

    try parser.addMultiple("source", .{
        .short = 's',
        .help = "Source files (one or more)",
        .min = 1,
    });

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose" });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    if (result.getArray("source")) |sources| {
        std.debug.print("Sources ({d}):\n", .{sources.len});
        for (sources, 0..) |src, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, src });
        }
    }
}
