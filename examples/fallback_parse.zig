//! Fallback parse example demonstrating parseOr, parseProcessOr, getOrCounter, getOrKeyValue.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "fallback-demo",
        .version = "1.0.0",
        .description = "Demonstrates fallback parse API",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
    try parser.addOption("name", .{ .short = 'n', .help = "Your name", .default = "World" });
    try parser.addOption("count", .{
        .short = 'c',
        .help = "Counter value",
        .value_type = .int,
        .default = "0",
    });
    try parser.addKeyValueOption("metadata", .{
        .short = 'm',
        .help = "Key=value metadata",
    });
    try parser.addCounter("verbosity", .{
        .short = 'd',
        .help = "Verbosity level (repeatable)",
    });

    var result = parser.parseOr(&[_][]const u8{}, null);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const name = result.getString("name") orelse "World";
    const count = result.getInt("count") orelse 0;
    const counter = result.getOrCounter("verbosity", 3);
    const meta = result.getOrKeyValue("metadata", .{ .key = "key", .value = "default-val" });

    std.debug.print("Verbose:  {}\n", .{verbose});
    std.debug.print("Name:     {s}\n", .{name});
    std.debug.print("Count:    {d}\n", .{count});
    std.debug.print("Counter:  {d}\n", .{counter});
    std.debug.print("Meta:     {s}={s}\n", .{ meta.key, meta.value });

    var result2 = parser.parseProcessOr(init, null);
    defer result2.deinit();

    const p_name = result2.getOrString("name", "Fallback");
    std.debug.print("Parsed name: {s}\n", .{p_name});
}
