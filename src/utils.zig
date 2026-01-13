//! Shared utilities for args.zig - common functions reused across modules.
//! Provides optimized string operations, memory helpers, and ANSI colors.

const std = @import("std");

/// Fast string equality check.
pub inline fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// Case-insensitive string equality check.
pub inline fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(a, b);
}

/// Check if string starts with prefix.
pub inline fn startsWith(haystack: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, haystack, prefix);
}

/// Check if string ends with suffix.
pub inline fn endsWith(haystack: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, haystack, suffix);
}

/// Find index of character in string.
pub inline fn indexOf(haystack: []const u8, needle: u8) ?usize {
    return std.mem.indexOfScalar(u8, haystack, needle);
}

/// Find index of substring in string.
pub inline fn indexOfStr(haystack: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, haystack, needle);
}

/// Trim whitespace from both ends.
pub inline fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\n\r");
}

/// Duplicate a string.
pub inline fn dupe(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    return allocator.dupe(u8, s);
}

/// Join strings with separator.
pub fn join(allocator: std.mem.Allocator, strings: []const []const u8, separator: []const u8) ![]const u8 {
    if (strings.len == 0) return "";

    var total_len: usize = 0;
    for (strings) |s| total_len += s.len;
    total_len += separator.len * (strings.len - 1);

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (strings, 0..) |s, i| {
        @memcpy(result[pos..][0..s.len], s);
        pos += s.len;
        if (i < strings.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

pub const Color = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const italic = "\x1b[3m";
    pub const underline = "\x1b[4m";

    // Foreground colors
    pub const black = "\x1b[30m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const white = "\x1b[37m";

    // Bright foreground colors
    pub const bright_black = "\x1b[90m";
    pub const bright_red = "\x1b[91m";
    pub const bright_green = "\x1b[92m";
    pub const bright_yellow = "\x1b[93m";
    pub const bright_blue = "\x1b[94m";
    pub const bright_magenta = "\x1b[95m";
    pub const bright_cyan = "\x1b[96m";
    pub const bright_white = "\x1b[97m";

    /// Get color or empty string based on whether colors are enabled.
    pub inline fn get(code: []const u8, enabled: bool) []const u8 {
        return if (enabled) code else "";
    }
};

/// Parse integer with error handling.
pub inline fn parseInt(comptime T: type, s: []const u8) ?T {
    return std.fmt.parseInt(T, s, 10) catch null;
}

/// Parse unsigned integer with error handling.
pub inline fn parseUint(comptime T: type, s: []const u8) ?T {
    return std.fmt.parseInt(T, s, 10) catch null;
}

/// Parse float with error handling.
pub inline fn parseFloat(s: []const u8) ?f64 {
    return std.fmt.parseFloat(f64, s) catch null;
}

/// Create an ArrayList writer for building strings.
pub inline fn stringWriter(allocator: std.mem.Allocator) std.ArrayListUnmanaged(u8).Writer {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    return list.writer(allocator);
}

/// Calculate padding for alignment.
pub inline fn calcPadding(current_len: usize, target_len: usize) usize {
    return if (current_len < target_len) target_len - current_len else 2;
}

/// Write N spaces to a writer.
pub inline fn writeSpaces(writer: anytype, count: usize) !void {
    try writer.writeByteNTimes(' ', count);
}

/// Parse common boolean string representations.
/// Optimized with inline and early returns.
pub fn parseBool(value: []const u8) ?bool {
    if (value.len == 0) return null;

    // Single character fast path
    if (value.len == 1) {
        return switch (value[0]) {
            '1', 'y', 'Y', 't', 'T' => true,
            '0', 'n', 'N', 'f', 'F' => false,
            else => null,
        };
    }

    // Common cases
    if (eqlIgnoreCase(value, "true")) return true;
    if (eqlIgnoreCase(value, "false")) return false;
    if (eqlIgnoreCase(value, "yes")) return true;
    if (eqlIgnoreCase(value, "no")) return false;
    if (eqlIgnoreCase(value, "on")) return true;
    if (eqlIgnoreCase(value, "off")) return false;

    return null;
}

/// Calculate edit distance between two strings.
/// Optimized with early termination for common cases.
pub fn editDistance(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;
    if (eql(a, b)) return 0;

    // Use smaller array for space efficiency
    if (a.len > b.len) return editDistance(b, a);

    var prev_row: [256]usize = undefined;
    var curr_row: [256]usize = undefined;

    const width = @min(b.len + 1, 256);

    for (0..width) |i| prev_row[i] = i;

    for (a, 0..) |c1, i| {
        curr_row[0] = i + 1;
        for (b[0 .. width - 1], 0..) |c2, j| {
            const cost: usize = if (c1 == c2) 0 else 1;
            curr_row[j + 1] = @min(
                @min(prev_row[j + 1] + 1, curr_row[j] + 1),
                prev_row[j] + cost,
            );
        }
        @memcpy(prev_row[0..width], curr_row[0..width]);
    }

    return prev_row[b.len];
}

/// Find the closest matching string from candidates.
pub fn findClosest(needle: []const u8, candidates: []const []const u8, max_distance: usize) ?[]const u8 {
    var best_match: ?[]const u8 = null;
    var best_distance: usize = max_distance + 1;

    for (candidates) |candidate| {
        const dist = editDistance(needle, candidate);
        if (dist < best_distance) {
            best_distance = dist;
            best_match = candidate;
        }
    }

    return if (best_distance <= max_distance) best_match else null;
}

/// Check if value is in choices array.
pub fn inChoices(value: []const u8, choices: []const []const u8) bool {
    for (choices) |choice| {
        if (eql(value, choice)) return true;
    }
    return false;
}

/// Validate range for any integer type.
pub inline fn inRange(comptime T: type, value: T, min: ?T, max: ?T) bool {
    if (min) |m| if (value < m) return false;
    if (max) |m| if (value > m) return false;
    return true;
}

/// Check if string contains substring.
pub inline fn contains(haystack: []const u8, needle: []const u8) bool {
    return indexOfStr(haystack, needle) != null;
}

/// Wrap text to specified width.
/// Returns a list of lines allocated with the allocator.
pub fn wrapText(allocator: std.mem.Allocator, text: []const u8, max_width: usize, initial_indent: usize, subsequent_indent: usize) !std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit();
    }

    var iter = std.mem.splitScalar(u8, text, ' ');
    var current_line = std.ArrayList(u8).init(allocator);
    defer current_line.deinit();

    // Add initial indentation
    try current_line.appendNTimes(' ', initial_indent);

    var first_word = true;
    var current_width = initial_indent;

    while (iter.next()) |word| {
        if (word.len == 0) continue;

        if (first_word) {
            try current_line.appendSlice(word);
            current_width += word.len;
            first_word = false;
        } else {
            if (current_width + 1 + word.len > max_width) {
                // Push current line
                try lines.append(try current_line.toOwnedSlice());

                // Start new line
                try current_line.appendNTimes(' ', subsequent_indent);
                try current_line.appendSlice(word);
                current_width = subsequent_indent + word.len;
            } else {
                try current_line.append(' ');
                try current_line.appendSlice(word);
                current_width += 1 + word.len;
            }
        }
    }

    if (current_line.items.len > 0) {
        try lines.append(try current_line.toOwnedSlice());
    }

    return lines;
}

test "eql" {
    try std.testing.expect(eql("hello", "hello"));
    try std.testing.expect(!eql("hello", "world"));
}

test "eqlIgnoreCase" {
    try std.testing.expect(eqlIgnoreCase("Hello", "hello"));
    try std.testing.expect(eqlIgnoreCase("HELLO", "hello"));
}

test "startsWith and endsWith" {
    try std.testing.expect(startsWith("--verbose", "--"));
    try std.testing.expect(endsWith("file.txt", ".txt"));
}

test "parseBool" {
    try std.testing.expectEqual(@as(?bool, true), parseBool("true"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("1"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("yes"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("false"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("0"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("invalid"));
}

test "editDistance" {
    try std.testing.expectEqual(@as(usize, 0), editDistance("hello", "hello"));
    try std.testing.expectEqual(@as(usize, 1), editDistance("hello", "hallo"));
    try std.testing.expectEqual(@as(usize, 3), editDistance("kitten", "sitting"));
}

test "findClosest" {
    const candidates = [_][]const u8{ "verbose", "version", "help" };
    const result = findClosest("verbos", &candidates, 2);
    try std.testing.expectEqualStrings("verbose", result.?);
}

test "inChoices" {
    const choices = [_][]const u8{ "json", "xml", "csv" };
    try std.testing.expect(inChoices("json", &choices));
    try std.testing.expect(!inChoices("yaml", &choices));
}

test "inRange" {
    try std.testing.expect(inRange(i32, 5, 0, 10));
    try std.testing.expect(!inRange(i32, 15, 0, 10));
    try std.testing.expect(inRange(i32, 5, null, null));
}

test "Color.get" {
    try std.testing.expectEqualStrings("\x1b[31m", Color.get(Color.red, true));
    try std.testing.expectEqualStrings("", Color.get(Color.red, false));
}

test "calcPadding" {
    try std.testing.expectEqual(@as(usize, 5), calcPadding(15, 20));
    try std.testing.expectEqual(@as(usize, 2), calcPadding(25, 20));
}
