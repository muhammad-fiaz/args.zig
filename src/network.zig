//! Network utilities for args.zig update checker.

const std = @import("std");
const utils = @import("utils.zig");

/// HTTP response.
pub const HttpResponse = struct {
    status_code: u16,
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
    }

    /// Check if response indicates success.
    pub fn isSuccess(self: HttpResponse) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    /// Check if response has a body.
    pub fn hasBody(self: HttpResponse) bool {
        return self.body.len > 0;
    }
};

/// Simple HTTP GET request (placeholder - requires platform-specific implementation).
pub fn httpGet(allocator: std.mem.Allocator, url: []const u8) !HttpResponse {
    _ = url;
    return HttpResponse{
        .status_code = 0,
        .body = try allocator.dupe(u8, ""),
        .allocator = allocator,
    };
}

/// Check if network is available.
pub fn isNetworkAvailable() bool {
    return false; // Conservative default
}

/// Build a URL from components.
pub fn buildUrl(allocator: std.mem.Allocator, base: []const u8, path: []const u8) ![]const u8 {
    if (base.len == 0) return try allocator.dupe(u8, path);
    if (path.len == 0) return try allocator.dupe(u8, base);

    const needs_slash = base[base.len - 1] != '/' and path[0] != '/';
    const has_double_slash = base[base.len - 1] == '/' and path[0] == '/';

    if (has_double_slash) {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ base, path[1..] });
    } else if (needs_slash) {
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ base, path });
    } else {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ base, path });
    }
}

test "HttpResponse.isSuccess" {
    const allocator = std.testing.allocator;

    var resp = HttpResponse{
        .status_code = 200,
        .body = try allocator.dupe(u8, "OK"),
        .allocator = allocator,
    };
    defer resp.deinit();

    try std.testing.expect(resp.isSuccess());
    try std.testing.expect(resp.hasBody());
}

test "HttpResponse.isSuccess for error" {
    const allocator = std.testing.allocator;

    var resp = HttpResponse{
        .status_code = 404,
        .body = try allocator.dupe(u8, "Not Found"),
        .allocator = allocator,
    };
    defer resp.deinit();

    try std.testing.expect(!resp.isSuccess());
}

test "isNetworkAvailable" {
    // Should return false by default (conservative)
    try std.testing.expect(!isNetworkAvailable());
}

test "buildUrl" {
    const allocator = std.testing.allocator;

    const url1 = try buildUrl(allocator, "https://api.github.com", "repos/user/repo");
    defer allocator.free(url1);
    try std.testing.expectEqualStrings("https://api.github.com/repos/user/repo", url1);

    const url2 = try buildUrl(allocator, "https://example.com/", "path");
    defer allocator.free(url2);
    try std.testing.expectEqualStrings("https://example.com/path", url2);
}

test "httpGet placeholder" {
    const allocator = std.testing.allocator;

    var resp = try httpGet(allocator, "https://example.com");
    defer resp.deinit();

    // Placeholder always returns status 0
    try std.testing.expectEqual(@as(u16, 0), resp.status_code);
}
