const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize configuration.
    // By default, parsing_mode is .permissive, which causes 'expect' to warn on mismatch.
    // Uncomment the line below to enforce strict validation (treats mismatch as error).
    // args.config.initConfig(.{ .parsing_mode = .strict });

    // Note: .choices ALWAYS enforces strict validation regardless of config.

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "expect-demo",
        .description = "Demonstrates 'expect' validation (soft choices) vs 'choices'.",
    });
    defer parser.deinit();

    // 'expect' allows you to suggest values.
    // If a user provides a value NOT in this list:
    // - Default/Permissive Mode: Prints a warning, but accepts the value.
    // - Strict Mode: Returns an error/exits.
    try parser.addOption("env", .{
        .short = 'e',
        .expect = &[_][]const u8{ "dev", "prod", "staging" },
        .help = "Target environment (expected: dev, prod, staging)",
    });

    // 'choices' restricts values strictly.
    // If a user provides a value NOT in this list, it is ALWAYS an error.
    try parser.addOption("output", .{
        .short = 'o',
        .choices = &[_][]const u8{ "json", "text" },
        .help = "Output format (strict choices: json, text)",
    });

    // Parse command line arguments
    var result = try parser.parseProcess();
    defer result.deinit();

    const env = result.getString("env") orelse "default";
    const output = result.getString("output") orelse "text";

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Environment: {s}\n", .{env});
    std.debug.print("  Output:      {s}\n", .{output});
}
