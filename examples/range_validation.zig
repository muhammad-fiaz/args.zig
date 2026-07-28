//! Example demonstrating range validation for numeric and string-length options.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "range-example",
        .description = "Demonstrates range and character-length validation",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    // Integer range: 1-100
    try parser.addRangeOption("level", i64, comptime .{
        .short = 'l',
        .help = "Difficulty level (1-100)",
        .default = "50",
        .min = 1,
        .max = 100,
    });

    // Float range: 0.0-1.0
    try parser.addRangeOption("threshold", f64, comptime .{
        .short = 't',
        .help = "Detection threshold (0.0-1.0)",
        .default = "0.5",
        .min = 0.0,
        .max = 1.0,
    });

    // Character range: 3-20 characters
    try parser.addCharRangeOption("username", comptime .{
        .short = 'u',
        .help = "Username (3-20 characters)",
        .required = true,
        .min = 3,
        .max = 20,
    });

    // Unsigned integer range
    try parser.addRangeOption("port", i64, comptime .{
        .short = 'p',
        .help = "Port number (1024-65535)",
        .default = "8080",
        .min = 1024,
        .max = 65535,
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    const level = result.getInt("level") orelse 50;
    const threshold = result.getFloat("threshold") orelse 0.5;
    const username = result.getString("username") orelse "unknown";
    const port = result.getInt("port") orelse 8080;

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Level:     {d}\n", .{level});
    std.debug.print("  Threshold: {d:.2}\n", .{threshold});
    std.debug.print("  Username:  {s} ({d} chars)\n", .{ username, username.len });
    std.debug.print("  Port:      {d}\n", .{port});
}
