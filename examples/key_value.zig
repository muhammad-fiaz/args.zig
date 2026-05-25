//! Example of Key-Value Pair Parsing

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "key-value-demo",
        .description = "Demonstrates parsing key=value arguments",
    });
    defer parser.deinit();

    try parser.addArg(.{
        .name = "config",
        .short = 'c',
        .value_type = .key_value,
        .help = "Set configuration property (e.g., -c db=postgres)",
    });

    const raw_args = try init.minimal.args.toSlice(init.arena.allocator());

    var result: args.ParseResult = undefined;
    if (raw_args.len > 1) {
        result = try parser.parseProcess(init);
    } else {
        std.debug.print("No args provided. Simulating: -c db=postgres\n\n", .{});
        result = try parser.parse(&[_][]const u8{ "-c", "db=postgres" });
    }
    if (result.getKeyValue("config")) |kv| {
        std.debug.print("Configuration: Key='{s}', Value='{s}'\n", .{ kv.key, kv.value });
    } else {
        std.debug.print("No config provided.\n", .{});
    }
    result.deinit();
}
