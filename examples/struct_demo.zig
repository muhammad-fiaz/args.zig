//! Example of Declarative Struct-Based Parsing.

const std = @import("std");
const args = @import("args");

// 1. Define your configuration struct
const Config = struct {
    // Flags (bool)
    verbose: bool,
    dry_run: bool,

    // Options (Optional = not required)
    output: ?[]const u8,

    // Required Option (Non-Optional, default 10 if omitted)
    count: i32 = 10,

    // Numeric Option
    timeout: ?f64,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Note: We use parseInto which calls parseProcess internally for this example.
    var parsed = args.parseInto(allocator, Config, .{
        .name = "struct-demo",
        .description = "Declarative configuration via structs",
    }, null, init) catch |err| {

        // Currently the library prints error if exit_on_error is true (default).
        std.debug.print("Failed to parse: {}\n", .{err});
        return;
    };
    defer parsed.deinit();

    const cfg = parsed.options;

    std.debug.print("Configuration Parsed:\n", .{});
    std.debug.print("  Verbose: {}\n", .{cfg.verbose});
    std.debug.print("  Dry Run: {}\n", .{cfg.dry_run});
    std.debug.print("  Output:  {s}\n", .{cfg.output orelse "(none)"});
    std.debug.print("  Count:   {d}\n", .{cfg.count});

    if (cfg.timeout) |t| {
        std.debug.print("  Timeout: {d:.2}s\n", .{t});
    }
}
