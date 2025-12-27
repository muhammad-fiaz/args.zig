//! Update checker example demonstrating how to configure and disable updates.
//! Shows various methods to control the update checking behavior.

const std = @import("std");
const args = @import("args");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Display library version info
    std.debug.print("args.zig Library Information:\n", .{});
    std.debug.print("  Version: {s}\n", .{args.VERSION});
    std.debug.print("  Major: {d}\n", .{args.VERSION_MAJOR});
    std.debug.print("  Minor: {d}\n", .{args.VERSION_MINOR});
    std.debug.print("  Patch: {d}\n", .{args.VERSION_PATCH});
    std.debug.print("  Min Zig: {s}\n\n", .{args.MINIMUM_ZIG_VERSION});

    // Method 1: Disable update checking globally
    std.debug.print("Method 1: Global disable\n", .{});
    std.debug.print("  args.disableUpdateCheck();\n\n", .{});

    // Method 2: Use minimal config (recommended for production)
    std.debug.print("Method 2: Minimal config (no updates, no colors)\n", .{});
    {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "my-app",
            .version = "1.0.0",
            .config = args.Config.minimal(),
        });
        defer parser.deinit();
        std.debug.print("  Created parser with Config.minimal()\n\n", .{});
    }

    // Method 3: Custom config with specific settings
    std.debug.print("Method 3: Custom config\n", .{});
    {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "my-app",
            .version = "1.0.0",
            .config = .{
                .check_for_updates = false,
                .show_update_notification = false,
                .use_colors = true,
                .show_defaults = true,
            },
        });
        defer parser.deinit();
        std.debug.print("  Created parser with custom config\n\n", .{});
    }

    // Method 4: Check environment variable to conditionally disable
    std.debug.print("Method 4: Environment-based disable\n", .{});
    std.debug.print("  Check MY_APP_NO_UPDATE_CHECK env var\n\n", .{});

    // Example of conditional disable based on environment
    const no_update = std.process.getEnvVarOwned(allocator, "MY_APP_NO_UPDATE_CHECK") catch null;
    if (no_update) |val| {
        allocator.free(val);
        args.disableUpdateCheck();
        std.debug.print("  Update checking disabled via environment variable\n", .{});
    }

    // Demonstrate re-enabling updates
    std.debug.print("\nRe-enabling updates:\n", .{});
    std.debug.print("  args.enableUpdateCheck();\n", .{});

    // Final example: Production-ready parser
    std.debug.print("\n=== Production-Ready Parser Example ===\n\n", .{});

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "production-app",
        .version = "1.0.0",
        .description = "A production-ready application",
        .config = args.Config.minimal(), // No updates, safe for CI/CD
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
    try parser.addOption("config", .{ .short = 'c', .help = "Config file", .env_var = "APP_CONFIG" });

    // Show help
    const help_text = try parser.getHelp();
    defer allocator.free(help_text);
    std.debug.print("{s}", .{help_text});
}
