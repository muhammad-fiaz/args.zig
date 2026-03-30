const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "config-modes",
        .description = "Demonstrates config-driven parser behavior",
        .config = .{
            .exit_on_error = false,
            .case_sensitive = false,
            .allow_short_clusters = false,
            .allow_inline_values = true,
            .allow_interspersed = false,
            .parsing_mode = .permissive,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file", .default = "out.txt" });
    try parser.addPositional("input", .{ .help = "Input path" });

    // --verbose is accepted in this demo config.
    const argv = [_][]const u8{ "input.txt", "--verbose" };

    var result = try parser.parse(&argv);
    defer result.deinit();

    std.debug.print("input: {s}\n", .{result.getString("input") orelse "<missing>"});
    std.debug.print("output: {s}\n", .{result.getString("output") orelse "<missing>"});
    std.debug.print("verbose: {}\n", .{result.getBool("verbose") orelse false});

    if (result.remaining.items.len > 0) {
        std.debug.print("unknown/remaining:\n", .{});
        for (result.remaining.items) |item| {
            std.debug.print("  - {s}\n", .{item});
        }
    }

    if (result.positionals.items.len > 0) {
        std.debug.print("extra positionals:\n", .{});
        for (result.positionals.items) |item| {
            std.debug.print("  - {s}\n", .{item});
        }
    }
}
