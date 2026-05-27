//! Demonstrates the --verbose / --quiet log-level helpers.
//! Uses addLogLevel which wires -v and -q to a shared counter destination.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "log-demo",
        .version = "1.0.0",
        .description = "Demonstrates the log-level (--verbose/--quiet) helper",
    });
    defer parser.deinit();

    try parser.addLogLevel(
        .{
            .name = "verbose",
            .short = 'v',
            .help = "Increase verbosity (can be repeated: -vvv)",
            .dest = "verbosity",
        },
        .{
            .name = "quiet",
            .short = 'q',
            .help = "Decrease verbosity (can be repeated: -qqq)",
            .dest = "verbosity",
        },
    );

    try parser.addFlag("dry-run", .{
        .help = "Simulate execution without making changes",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbosity = result.getInt("verbosity") orelse 0;
    std.debug.print("Verbosity level: {d}\n", .{verbosity});

    if (verbosity >= 1) std.debug.print("  verbose mode enabled\n", .{});
    if (verbosity >= 2) std.debug.print("  debug output active\n", .{});
    if (verbosity >= 3) std.debug.print("  trace logging on\n", .{});
    if (result.getBool("dry-run") orelse false) {
        std.debug.print("  DRY RUN: no changes will be made\n", .{});
    }
}
