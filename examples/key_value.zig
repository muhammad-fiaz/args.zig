//! Example of Key-Value Pair Parsing

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "key-value-demo",
        .description = "Demonstrates parsing key=value arguments",
        .config = .{ .exit_on_error = false },
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
        result = parser.parseProcess(init) catch |err| {
            if (err == args.ParseError.MissingRequired) {
                try parser.printHelp();
                return;
            }
            return err;
        };
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
