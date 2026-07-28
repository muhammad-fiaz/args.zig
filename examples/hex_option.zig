//! Demonstrates the hex-decode option for passing binary data as hex strings.
//! Uses addHexOption which decodes hexadecimal input before storage.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "hex-demo",
        .version = "1.0.0",
        .description = "Demonstrates hex-decode option",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addHexOption("data", .{
        .short = 'd',
        .help = "Hex-encoded binary data (e.g., 'deadbeef')",
        .metavar = "HEX",
    });

    try parser.addHexOption("key", .{
        .short = 'k',
        .help = "Hex-encoded key material",
        .metavar = "HEX",
        .required = true,
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    if (result.get("data")) |data| {
        if (data.asString()) |str| {
            std.debug.print("--data decoded: {any} ({d} bytes)\n", .{ str, str.len });
        }
    }
    if (result.get("key")) |key| {
        if (key.asString()) |str| {
            std.debug.print("--key  decoded: {any} ({d} bytes)\n", .{ str, str.len });
        }
    }
}
