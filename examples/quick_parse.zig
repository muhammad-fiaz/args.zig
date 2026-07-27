//! Example demonstrating convenience constructors: quickParse, createParser, createMinimalParser.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // === quickParse: one-liner parsing with comptime specs ===
    // Ideal for simple CLIs where you define args and parse in one step.
    {
        const specs = [_]args.ArgSpec{
            .{ .name = "name", .long = "name", .short = 'n', .help = "Your name", .required = true },
            .{ .name = "verbose", .long = "verbose", .short = 'v', .help = "Verbose mode", .action = .store_true },
        };

        // Uses Config.minimal() internally — no colors, no update check
        var result = try args.quickParse(allocator, &specs, "quick-example", init);
        defer result.deinit();

        const name = result.getString("name") orelse "World";
        const verbose = result.getBool("verbose") orelse false;

        std.debug.print("Hello, {s}!\n", .{name});
        if (verbose) {
            std.debug.print("Verbose mode is ON\n", .{});
        }
    }

    // === createParser: standard parser with full defaults ===
    // Includes colors, update checking, and all features enabled.
    {
        var parser = try args.createParser(allocator, "create-example");
        defer parser.deinit();

        try parser.addOption("output", .{ .short = 'o', .help = "Output file", .default = "stdout" });

        // Simulate args since we already consumed process args above
        var res = try parser.parse(&[_][]const u8{ "--output", "result.txt" });
        defer res.deinit();

        const output = res.getString("output") orelse "stdout";
        std.debug.print("Output: {s}\n", .{output});
    }

    // === createMinimalParser: minimal config ===
    // No colors, no update checking — ideal for scripts and CI.
    {
        var parser = try args.createMinimalParser(allocator, "minimal-example");
        defer parser.deinit();

        try parser.addFlag("quiet", .{ .short = 'q', .help = "Quiet mode" });

        var res = try parser.parse(&[_][]const u8{"--quiet"});
        defer res.deinit();

        const quiet = res.getBool("quiet") orelse false;
        std.debug.print("Quiet: {}\n", .{quiet});
    }
}
