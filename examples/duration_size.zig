//! Demonstration of duration, byte-size, and range-validated options in args.zig.
//! Run with: zig build run-duration_size -- --timeout 2h30m --buffer-size 1GB --concurrency 4

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;

    var ap = try args.ArgumentParser.init(allocator, .{
        .name = "duration-size-demo",
        .config = .{ .exit_on_error = false },
    });
    defer ap.deinit();

    ap.description = "Demonstration of typed duration, byte size, and generic range-validated options";

    // 1. Duration option: accepts "1h30m", "45s", "2d", parses to u64 seconds
    try ap.addDurationOption("timeout", .{
        .short = 't',
        .default = "30s",
        .help = "Task execution timeout (e.g. 5m, 1h30m, 45s)",
    });

    // 2. Byte size option: accepts "512MB", "1GB", "4096", parses to u64 bytes
    try ap.addSizeOption("buffer-size", .{
        .short = 'b',
        .default = "64MB",
        .help = "Internal buffer size (e.g. 512MB, 1GB, 4096)",
    });

    // 3. Range-validated option: accepts any type of integer or float within specified bounds
    try ap.addRangeOption("concurrency", i64, comptime .{
        .short = 'c',
        .default = "2",
        .min = 1,
        .max = 8,
        .help = "Worker concurrency limit (range: 1..8)",
    });

    try ap.addRangeOption("ratio", f64, comptime .{
        .short = 'r',
        .default = "0.5",
        .min = 0.0,
        .max = 1.0,
        .help = "Ratio threshold (range: 0.0 to 1.0)",
    });

    var result = ap.parseProcess(init) catch |err| {
        std.debug.print("Argument validation failed: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    const timeout_secs = result.getDuration("timeout").?;
    const buffer_bytes = result.getSize("buffer-size").?;
    const concurrency = result.get("concurrency").?.asInt().?;
    const ratio = result.get("ratio").?.asFloat().?;

    std.debug.print("Successfully parsed custom-typed arguments:\n", .{});
    std.debug.print("  - Timeout:      {d} seconds\n", .{timeout_secs});
    std.debug.print("  - Buffer size:  {d} bytes ({d} MB)\n", .{ buffer_bytes, buffer_bytes / (1024 * 1024) });
    std.debug.print("  - Concurrency:  {d} (validated in range 1..8)\n", .{concurrency});
    std.debug.print("  - Ratio:        {d:.2} (validated in range 0.0..1.0)\n", .{ratio});
}
