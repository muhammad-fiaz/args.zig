//! Shared utilities for args.zig - common functions reused across modules.
//! Provides optimized string operations, memory helpers, and ANSI colors.

const std = @import("std");
const types = @import("types.zig");

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

pub const ColorTheme = struct {
    reset: []const u8,
    bold: []const u8,
    dim: []const u8,
    header: []const u8,
    section: []const u8,
    option: []const u8,
    argument: []const u8,
    meta: []const u8,
    warning: []const u8,
    error_color: []const u8,
    accent: []const u8,

    pub fn standard() ColorTheme {
        return .{
            .reset = Color.reset,
            .bold = Color.bold,
            .dim = Color.dim,
            .header = Color.yellow,
            .section = Color.yellow,
            .option = Color.green,
            .argument = Color.cyan,
            .meta = Color.dim,
            .warning = Color.yellow,
            .error_color = Color.red,
            .accent = Color.cyan,
        };
    }

    pub fn bright() ColorTheme {
        return .{
            .reset = Color.reset,
            .bold = Color.bold,
            .dim = Color.dim,
            .header = Color.bright_yellow,
            .section = Color.bright_yellow,
            .option = Color.bright_green,
            .argument = Color.bright_cyan,
            .meta = Color.dim,
            .warning = Color.bright_yellow,
            .error_color = Color.bright_red,
            .accent = Color.bright_cyan,
        };
    }

    pub fn none() ColorTheme {
        return .{
            .reset = "",
            .bold = "",
            .dim = "",
            .header = "",
            .section = "",
            .option = "",
            .argument = "",
            .meta = "",
            .warning = "",
            .error_color = "",
            .accent = "",
        };
    }
};

pub fn resolveTheme(use_colors: bool, theme: ?ColorTheme) ColorTheme {
    if (!use_colors) return ColorTheme.none();
    return theme orelse ColorTheme.standard();
}

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
pub inline fn stringWriter(allocator: std.mem.Allocator) std.ArrayList(u8).Writer {
    var list: std.ArrayList(u8) = .empty;
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

    if (b.len + 1 <= 256) {
        var prev_row: [256]usize = undefined;
        var curr_row: [256]usize = undefined;
        const width = b.len + 1;

        for (0..width) |i| prev_row[i] = i;

        for (a, 0..) |c1, i| {
            curr_row[0] = i + 1;
            for (b, 0..) |c2, j| {
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

    // Fallback path for long strings keeps behavior correct without fixed-size limits.
    const allocator = std.heap.page_allocator;
    var prev_row = allocator.alloc(usize, b.len + 1) catch return @max(a.len, b.len);
    defer allocator.free(prev_row);
    var curr_row = allocator.alloc(usize, b.len + 1) catch return @max(a.len, b.len);
    defer allocator.free(curr_row);

    for (0..b.len + 1) |i| prev_row[i] = i;

    for (a, 0..) |c1, i| {
        curr_row[0] = i + 1;
        for (b, 0..) |c2, j| {
            const cost: usize = if (c1 == c2) 0 else 1;
            curr_row[j + 1] = @min(
                @min(prev_row[j + 1] + 1, curr_row[j] + 1),
                prev_row[j] + cost,
            );
        }
        std.mem.copyForwards(usize, prev_row, curr_row);
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

/// Convert snake_case to kebab-case.
/// Caller owns the returned string memory.
pub fn toKebabCase(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    const result = try allocator.dupe(u8, s);
    for (result) |*c| {
        if (c.* == '_') c.* = '-';
    }
    return result;
}

/// Result of parsing a bracket-delimited list.
pub const BracketListResult = struct {
    items: []const []const u8,
    bracket_type: types.BracketType,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *BracketListResult) void {
        for (self.items) |item| self.allocator.free(item);
        self.allocator.free(self.items);
    }
};

/// Detect if a string is bracket-delimited and return the bracket type.
pub fn detectBracket(value: []const u8) types.BracketType {
    if (value.len < 2) return .none;
    return types.BracketType.detect(value[0]);
}

/// Strip matching brackets from a string. Returns the inner content or null.
pub fn stripBrackets(value: []const u8) ?[]const u8 {
    const bt = detectBracket(value);
    const close = bt.closing() orelse return null;
    if (value[value.len - 1] != close) return null;
    return value[1 .. value.len - 1];
}

/// Parse a bracket-delimited list value like `{a,b,c}`, `[a,b,c]`, `<a,b,c>`.
/// Returns the parsed items and the detected bracket type.
/// If the value is not bracket-delimited, returns the single item as a list of one.
pub fn parseBracketedList(allocator: std.mem.Allocator, value: []const u8, separator: u8) !BracketListResult {
    const inner = stripBrackets(value) orelse {
        // Not bracket-delimited — treat as single item
        const item = try allocator.dupe(u8, std.mem.trim(u8, value, " "));
        const items = try allocator.alloc([]const u8, 1);
        items[0] = item;
        return .{ .items = items, .bracket_type = .none, .allocator = allocator };
    };

    const bt = detectBracket(value);

    // Count items
    var count: usize = 0;
    {
        var it = std.mem.splitScalar(u8, inner, separator);
        while (it.next()) |part| {
            if (std.mem.trim(u8, part, " \t").len > 0) count += 1;
        }
    }

    const items = try allocator.alloc([]const u8, count);
    errdefer allocator.free(items);

    var idx: usize = 0;
    var it = std.mem.splitScalar(u8, inner, separator);
    while (it.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t");
        if (trimmed.len > 0) {
            items[idx] = try allocator.dupe(u8, trimmed);
            idx += 1;
        }
    }

    return .{ .items = items[0..idx], .bracket_type = bt, .allocator = allocator };
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
    try std.testing.expectEqual(@as(?bool, true), parseBool("True"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("TRUE"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("1"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("yes"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("Yes"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("YES"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("y"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("Y"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("t"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("T"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("on"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("On"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("ON"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("false"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("False"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("FALSE"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("0"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("no"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("No"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("NO"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("n"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("N"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("f"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("F"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("off"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("Off"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("OFF"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("invalid"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("maybe"));
    try std.testing.expectEqual(@as(?bool, null), parseBool(""));
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

test "resolveTheme" {
    const std_theme = resolveTheme(true, null);
    try std.testing.expectEqualStrings(Color.yellow, std_theme.header);

    const none = resolveTheme(false, null);
    try std.testing.expectEqualStrings("", none.option);
}

test "calcPadding" {
    try std.testing.expectEqual(@as(usize, 5), calcPadding(15, 20));
    try std.testing.expectEqual(@as(usize, 2), calcPadding(25, 20));
}
