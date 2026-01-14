//! Example of Key-Value Pair Parsing

const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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

    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    var result: args.ParseResult = undefined;
    if (raw_args.len > 1) {
        result = try parser.parseProcess();
    } else {
        std.debug.print("No args provided. Simulating: -c db=postgres\n\n", .{});
        const sim_args = [_][]const u8{ "-c", "db=postgres" };
        result = try parser.parse(&sim_args);
    }
    defer result.deinit();

    if (result.getKeyValue("config")) |kv| {
        std.debug.print("Configuration: Key='{s}', Value='{s}'\n", .{ kv.key, kv.value });
    } else {
        std.debug.print("No config provided.\n", .{});
    }
}
