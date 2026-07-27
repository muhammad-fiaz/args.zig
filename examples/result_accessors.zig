//! Example demonstrating all ParseResult accessor methods.
//! Shows getEnum, getDuration, getSize, isPresent, getCounter, contains, etc.

const std = @import("std");
const args = @import("args");

const Color = enum {
    red,
    green,
    blue,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "accessors-example",
        .description = "Demonstrates all ParseResult accessor methods",
    });
    defer parser.deinit();

    try parser.addOption("name", .{ .short = 'n', .help = "Your name", .required = true });
    try parser.addOption("color", .{ .help = "Favorite color", .choices = &[_][]const u8{ "red", "green", "blue" }, .default = "blue" });
    try parser.addDurationOption("timeout", .{ .short = 't', .help = "Timeout duration", .default = "30s" });
    try parser.addSizeOption("limit", .{ .short = 'l', .help = "Size limit", .default = "1GB" });
    try parser.addCounter("verbose", .{ .short = 'v', .help = "Verbosity level" });
    try parser.addFlag("debug", .{ .short = 'd', .help = "Debug mode" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    std.debug.print("=== ParseResult Accessor Methods ===\n\n", .{});

    // getString - get optional string
    if (result.getString("name")) |name| {
        std.debug.print("getString(\"name\"):     {s}\n", .{name});
    }

    // getEnum - convert string to enum (manual conversion shown here)
    if (result.getString("color")) |color_str| {
        const color: Color = if (std.mem.eql(u8, color_str, "red"))
            .red
        else if (std.mem.eql(u8, color_str, "green"))
            .green
        else
            .blue;
        std.debug.print("color parsed to enum:  {}\n", .{color});
    }

    // getDuration - get duration in seconds
    if (result.getDuration("timeout")) |secs| {
        std.debug.print("getDuration(\"timeout\"): {d}s\n", .{secs});
    }

    // getSize - get size in bytes
    if (result.getSize("limit")) |bytes| {
        std.debug.print("getSize(\"limit\"):      {d} bytes\n", .{bytes});
    }

    // getCounter - get counter value
    if (result.getCounter("verbose")) |level| {
        std.debug.print("getCounter(\"verbose\"):  {d}\n", .{level});
    }

    // getBool - get boolean flag
    if (result.getBool("debug")) |dbg| {
        std.debug.print("getBool(\"debug\"):      {}\n", .{dbg});
    }

    // isPresent - check if argument was provided
    std.debug.print("isPresent(\"output\"):   {}\n", .{result.isPresent("output")});
    std.debug.print("isPresent(\"name\"):     {}\n", .{result.isPresent("name")});

    // contains - check if value exists
    std.debug.print("contains(\"verbose\"):   {}\n", .{result.contains("verbose")});

    // getOrString - get with default
    const output = result.getOrString("output", "stdout");
    std.debug.print("getOrString(\"output\"): {s}\n", .{output});

    // positionalCount
    std.debug.print("positionalCount():     {d}\n", .{result.positionalCount()});

    // hasSubcommand
    std.debug.print("hasSubcommand():       {}\n", .{result.hasSubcommand()});
}
