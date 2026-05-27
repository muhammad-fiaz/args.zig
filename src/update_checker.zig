//! Update checker for args.zig - checks for new releases from GitHub.

const std = @import("std");
const network = @import("network.zig");
const utils = @import("utils.zig");
const config = @import("config.zig");
const constants = @import("constants.zig");

const GITHUB_REPO = constants.UpdateChecker.github_repo;
const CURRENT_VERSION = @import("version.zig").version;

var check_performed_once = false;

/// Check for updates in a background thread.
pub fn checkForUpdates(allocator: std.mem.Allocator, show_notification: bool, use_colors: bool) ?std.Thread {
    if (check_performed_once) return null;
    check_performed_once = true;

    if (!show_notification) return null;

    return std.Thread.spawn(.{}, updateCheckThread, .{ allocator, show_notification, use_colors }) catch null;
}

fn updateCheckThread(allocator: std.mem.Allocator, show_notification: bool, use_colors: bool) void {
    _ = allocator;
    _ = use_colors;
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
    const curr = parseSemver(current) orelse return 0;
    const lat = parseSemver(latest) orelse return 0;

    return switch (lat.order(curr)) {
        .gt => 1,
        .lt => -1,
        .eq => 0,
    };
}

fn parseSemver(text: []const u8) ?std.SemanticVersion {
    var trimmed = text;
    if (trimmed.len > 0 and trimmed[0] == 'v') trimmed = trimmed[1..];
    if (trimmed.len == 0) return null;
    return std.SemanticVersion.parse(trimmed) catch null;
}

/// Print update notification to stderr.
pub fn printUpdateNotification(current: []const u8, latest: []const u8, url: []const u8, use_colors: bool) void {
    const theme = utils.resolveTheme(use_colors, config.getConfig().colors);
    const border = theme.header;
    const current_color = theme.accent;
    const latest_color = theme.option;
    const reset = theme.reset;
    const bold = theme.bold;

    std.debug.print("{s}{s}{s}", .{ border, constants.UpdateNotification.top_border, reset });
    std.debug.print(constants.UpdateNotification.message_line, .{ border, reset, bold, reset, current_color, current, reset, latest_color, latest, reset, border, reset });
    std.debug.print(constants.UpdateNotification.command_line, .{ border, reset, current_color, url, reset, border, reset });
    std.debug.print("{s}{s}{s}", .{ border, constants.UpdateNotification.bottom_border, reset });
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
