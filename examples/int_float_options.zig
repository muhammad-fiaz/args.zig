//! Demonstrates typed integer and float option helpers.
//! Uses addIntOption, addFloatOption, addUintOption for type-safe numeric parsing.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "numeric-demo",
        .version = "1.0.0",
        .description = "Demonstrates typed integer and float options",
    });
    defer parser.deinit();

    try parser.addIntOption("count", .{
        .short = 'n',
        .help = "Number of items (integer)",
        .default = "10",
    });

    try parser.addIntOption("retries", .{
        .short = 'r',
        .help = "Retry count (0–10)",
        .default = "3",
        .min = 0,
        .max = 10,
    });

    try parser.addUintOption("threads", .{
        .short = 't',
        .help = "Worker thread count",
        .default = "4",
    });

    try parser.addFloatOption("threshold", .{
        .short = 's',
        .help = "Confidence threshold (0.0–1.0)",
        .default = "0.75",
        .min = 0.0,
        .max = 1.0,
    });

    try parser.addFloatOption("rate", .{
        .short = 'a',
        .help = "Processing rate",
        .default = "1.5",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    std.debug.print("count       = {d} (type: int)\n", .{result.get("count").?.asInt().?});
    std.debug.print("retries     = {d} (type: int, range 0-10)\n", .{result.get("retries").?.asInt().?});
    std.debug.print("threads     = {d} (type: uint)\n", .{result.get("threads").?.asUint().?});
    std.debug.print("threshold   = {d:.2} (type: float, range 0.0-1.0)\n", .{result.get("threshold").?.asFloat().?});
    std.debug.print("rate        = {d:.2} (type: float)\n", .{result.get("rate").?.asFloat().?});
}
