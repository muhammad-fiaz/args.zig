const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    var parser = try args.ArgumentParser.init(init.arena.allocator(), .{
        .name = "list-example",
        .description = "Demonstrates list/array options",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addListOption("allow-hosts", .{
        .help = "Comma-separated list of allowed hosts",
        .short = 'a',
    });

    try parser.addListOption("ports", .{
        .help = "Comma-separated port numbers",
        .separator = ',',
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    if (result.getArray("allow-hosts")) |hosts| {
        std.debug.print("Allowed hosts:\n", .{});
        for (hosts) |host| {
            std.debug.print("  - {s}\n", .{host});
        }
    }
}
