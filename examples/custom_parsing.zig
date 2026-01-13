//! Custom parsing example demonstrating complex argument parsing.
//! Shows how to parse and validate format strings like "--mode 1920x1080@60Hz".

const std = @import("std");
const args = @import("args");

/// Struct to hold parsed display mode
const DisplayMode = struct {
    width: u32,
    height: u32,
    refresh: ?u32,

    /// Parse proper string like "1920x1080" or "1920x1080@60Hz"
    pub fn parse(text: []const u8) !DisplayMode {
        var it = std.mem.splitScalar(u8, text, '@');
        const res_part = it.next() orelse return error.InvalidFormat;
        const refresh_part = it.next();

        var res_it = std.mem.splitScalar(u8, res_part, 'x');
        const w_str = res_it.next() orelse return error.InvalidFormat;
        const h_str = res_it.next() orelse return error.InvalidFormat;

        const w = std.fmt.parseInt(u32, w_str, 10) catch return error.InvalidFormat;
        const h = std.fmt.parseInt(u32, h_str, 10) catch return error.InvalidFormat;

        var refresh: ?u32 = null;
        if (refresh_part) |rp| {
            // Trim 'Hz' if present
            const clean_rp = std.mem.trimRight(u8, rp, "Hz");
            refresh = std.fmt.parseInt(u32, clean_rp, 10) catch return error.InvalidFormat;
        }

        return .{ .width = w, .height = h, .refresh = refresh };
    }
};

/// Validator function for display mode
fn validateMode(text: []const u8) args.validation.ValidationResult {
    const mode = DisplayMode.parse(text) catch return .{ .err = "Invalid mode format. Expected <W>x<H>[@<R>Hz]" };
    _ = mode;
    return .{ .ok = {} };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "screen-tool",
        .description = "A tool to configure screen settings",
    });
    defer parser.deinit();

    try parser.addOption("mode", .{
        .short = 'm',
        .help = "Set display mode (e.g. 1920x1080@60Hz)",
        .validator = validateMode,
        .metavar = "<W>x<H>[@<R>Hz]",
    });

    try parser.addOption("output", .{
        .short = 'o',
        .help = "Output identifier",
        .metavar = "ID",
    });

    // Parse arguments
    // For demo purposes, we'll simulate arguments if none are provided
    const raw_args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, raw_args);

    var result: args.ParseResult = undefined;

    if (raw_args.len > 1) {
        result = try parser.parseProcess();
    } else {
        // Simulation for the example
        const sim_args = [_][]const u8{ "--mode", "2560x1440@144Hz", "--output", "DP-1" };
        std.debug.print("No arguments provided, simulating: {s} {s} {s} {s}\n\n", .{ sim_args[0], sim_args[1], sim_args[2], sim_args[3] });
        result = try parser.parse(&sim_args);
    }
    defer result.deinit();

    // Access and parse the value
    if (result.getString("mode")) |mode_str| {
        // We know it's valid because the validator passed
        const mode = DisplayMode.parse(mode_str) catch unreachable;

        std.debug.print("Configuration applied:\n", .{});
        std.debug.print("  Resolution: {d} x {d}\n", .{ mode.width, mode.height });
        if (mode.refresh) |r| {
            std.debug.print("  Refresh Rate: {d} Hz\n", .{r});
        } else {
            std.debug.print("  Refresh Rate: Auto\n", .{});
        }
    } else {
        std.debug.print("No mode specified.\n", .{});
    }

    if (result.getString("output")) |out| {
        std.debug.print("  Output: {s}\n", .{out});
    }
}
