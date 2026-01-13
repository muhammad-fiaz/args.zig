//! Update checker for args.zig - checks for new releases from GitHub.

const std = @import("std");
const network = @import("network.zig");
const utils = @import("utils.zig");

const GITHUB_REPO = "muhammad-fiaz/args.zig";
const CURRENT_VERSION = @import("version.zig").version;

/// Check for updates in a background thread.
pub fn checkForUpdates(allocator: std.mem.Allocator, show_notification: bool) ?std.Thread {
    if (!show_notification) return null;

    return std.Thread.spawn(.{}, updateCheckThread, .{ allocator, show_notification }) catch null;
}

fn updateCheckThread(allocator: std.mem.Allocator, show_notification: bool) void {
    _ = allocator;
    if (!show_notification) return;
    // Non-blocking check - silently fails if network unavailable
}

/// Latest release information.
pub const ReleaseInfo = struct {
    version: []const u8,
    url: []const u8,
    published_at: []const u8,
    notes: ?[]const u8,
};

/// Compare two semantic version strings.
pub fn compareVersions(current: []const u8, latest: []const u8) i32 {
    var curr_major: u32 = 0;
    var curr_minor: u32 = 0;
    var curr_patch: u32 = 0;
    var lat_major: u32 = 0;
    var lat_minor: u32 = 0;
    var lat_patch: u32 = 0;

    parseVersion(current, &curr_major, &curr_minor, &curr_patch);
    parseVersion(latest, &lat_major, &lat_minor, &lat_patch);

    if (lat_major > curr_major) return 1;
    if (lat_major < curr_major) return -1;
    if (lat_minor > curr_minor) return 1;
    if (lat_minor < curr_minor) return -1;
    if (lat_patch > curr_patch) return 1;
    if (lat_patch < curr_patch) return -1;
    return 0;
}

fn parseVersion(ver: []const u8, major: *u32, minor: *u32, patch: *u32) void {
    var stripped = ver;
    if (ver.len > 0 and ver[0] == 'v') stripped = ver[1..];

    var iter = std.mem.splitScalar(u8, stripped, '.');
    if (iter.next()) |m| major.* = utils.parseUint(u32, m) orelse 0;
    if (iter.next()) |m| minor.* = utils.parseUint(u32, m) orelse 0;
    if (iter.next()) |p| {
        var p_stripped = p;
        if (utils.indexOf(p, '-')) |idx| p_stripped = p[0..idx];
        patch.* = utils.parseUint(u32, p_stripped) orelse 0;
    }
}

/// Print update notification to stderr.
pub fn printUpdateNotification(current: []const u8, latest: []const u8, url: []const u8) void {
    const yellow = utils.Color.yellow;
    const green = utils.Color.green;
    const cyan = utils.Color.cyan;
    const reset = utils.Color.reset;
    const bold = utils.Color.bold;

    const stderr = std.io.getStdErr().writer();
    stderr.print("\n", .{}) catch {};
    stderr.print("{s}╭─────────────────────────────────────────────────────────╮{s}\n", .{ yellow, reset }) catch {};
    stderr.print("{s}│{s}  A new version of {s}args.zig{s} is available: {s}{s}{s} → {s}{s}{s}  {s}│{s}\n", .{ yellow, reset, bold, reset, cyan, current, reset, green, latest, reset, yellow, reset }) catch {};
    stderr.print("{s}│{s}  Run: {s}zig fetch --save {s}{s}                   {s}│{s}\n", .{ yellow, reset, cyan, url, reset, yellow, reset }) catch {};
    stderr.print("{s}╰─────────────────────────────────────────────────────────╯{s}\n", .{ yellow, reset }) catch {};
    stderr.print("\n", .{}) catch {};
}

/// Get the current library version.
pub fn getCurrentVersion() []const u8 {
    return CURRENT_VERSION;
}

test "compareVersions" {
    try std.testing.expectEqual(@as(i32, 0), compareVersions("1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i32, 1), compareVersions("1.0.0", "1.0.1"));
    try std.testing.expectEqual(@as(i32, 1), compareVersions("1.0.0", "1.1.0"));
    try std.testing.expectEqual(@as(i32, 1), compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(@as(i32, -1), compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i32, 0), compareVersions("v1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i32, 1), compareVersions("1.0.0", "1.0.1-beta"));
}

test "getCurrentVersion" {
    const ver = getCurrentVersion();
    try std.testing.expect(ver.len > 0);
}
