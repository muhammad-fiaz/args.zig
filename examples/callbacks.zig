//! Example demonstrating argument callbacks.

const std = @import("std");
const args = @import("args");

fn onVerbose(name: []const u8, value: ?[]const u8) void {
    _ = value;
    std.debug.print("Callback triggered for '{s}'! Verbosity increased.\n", .{name});
}

fn onOutput(name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        std.debug.print("Callback for '{s}': output file set to '{s}'\n", .{ name, v });
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "callback-demo",
        .description = "Demonstrates using callbacks for arguments",
    });
    defer parser.deinit();

    // Callback with option (requires value)
    try parser.addArg(.{
        .name = "output",
        .short = 'o',
        .long = "output",
        .help = "Output file (triggers callback)",
        .action = .callback,
        .callback = onOutput,
    });

    // Flag callback
    try parser.addArg(.{
        .name = "verbose",
        .long = "verbose",
        .aliases = &[_][]const u8{ "v", "loud" },
        .help = "Verbose output (supports aliases --v, --loud) [triggers callback]",
        .action = .callback_flag,
        .callback = onVerbose,
    });

    const raw_args = try init.minimal.args.toSlice(init.arena.allocator());

    var result: args.ParseResult = undefined;
    if (raw_args.len > 1) {
        result = try parser.parseProcess(init);
    } else {
        std.debug.print("No args provided. Simulating: --output results.txt --loud\n\n", .{});
        result = try parser.parse(&[_][]const u8{ "--output", "results.txt", "--loud" });
    }
    if (result.getBool("verbose")) |v| {
        if (v) std.debug.print("Verbose mode is ON\n", .{});
    }
    result.deinit();
}
