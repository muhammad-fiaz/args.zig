//! Example demonstrating prefix-matching options.
//! Shows --with-*, --enable-*, --disable-* style flags.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "prefix-example",
        .description = "Demonstrates prefix-matching options",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });

    // Note: addPrefixOption is a placeholder that registers a flag.
    // Prefix matching (--with-*, --enable-*) is handled at parse time.
    try parser.addPrefixOption("--with-", .{
        .name = "with",
        .help = "Enable features matching --with-<feature> pattern",
    });

    try parser.addPrefixOption("--enable-", .{
        .name = "enable",
        .help = "Enable components matching --enable-<component> pattern",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    if (verbose) {
        std.debug.print("Verbose mode enabled\n", .{});
    }

    if (result.contains("with")) {
        std.debug.print("With feature activated\n", .{});
    }
    if (result.contains("enable")) {
        std.debug.print("Enable component activated\n", .{});
    }
}
