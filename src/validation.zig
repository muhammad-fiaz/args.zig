//! Value validation and parsing for args.zig.

const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");

pub const ValueType = types.ValueType;
pub const ParsedValue = types.ParsedValue;

/// Parse a string value into a typed ParsedValue.
pub fn parseValue(value: []const u8, value_type: ValueType, allocator: std.mem.Allocator) !ParsedValue {
    _ = allocator;
    return switch (value_type) {
        .string, .path, .choice => .{ .string = value },
        .int => .{ .int = std.fmt.parseInt(i64, value, 10) catch return error.InvalidValue },
        .uint => .{ .uint = std.fmt.parseInt(u64, value, 10) catch return error.InvalidValue },
        .float => .{ .float = std.fmt.parseFloat(f64, value) catch return error.InvalidValue },
        .bool => .{ .boolean = utils.parseBool(value) orelse return error.InvalidValue },
        .counter => .{ .counter = std.fmt.parseInt(u32, value, 10) catch return error.InvalidValue },
        .array, .custom => .{ .string = value },
    };
}

/// Validate a value against a list of allowed choices.
pub fn validateChoice(value: []const u8, choices: []const []const u8) bool {
    return utils.inChoices(value, choices);
}

/// Parse a string into a boolean (delegates to utils).
pub const parseBool = utils.parseBool;

/// Validate that an integer is within a specified range.
pub fn validateRange(comptime T: type, value: T, min: ?T, max: ?T) bool {
    return utils.inRange(T, value, min, max);
}

/// Validate that a string length is within specified bounds.
pub fn validateLength(value: []const u8, min_len: ?usize, max_len: ?usize) bool {
    if (min_len) |m| if (value.len < m) return false;
    if (max_len) |m| if (value.len > m) return false;
    return true;
}

/// Check if a path exists on the filesystem.
pub fn validatePathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Parse and validate an integer within a range.
pub fn parseIntInRange(comptime T: type, value: []const u8, min: ?T, max: ?T) !T {
    const parsed = std.fmt.parseInt(T, value, 10) catch return error.InvalidValue;
    if (!validateRange(T, parsed, min, max)) return error.OutOfRange;
    return parsed;
}

/// Parse and validate a float within a range.
pub fn parseFloatInRange(value: []const u8, min: ?f64, max: ?f64) !f64 {
    const parsed = std.fmt.parseFloat(f64, value) catch return error.InvalidValue;
    if (min) |m| if (parsed < m) return error.OutOfRange;
    if (max) |m| if (parsed > m) return error.OutOfRange;
    return parsed;
}

/// Result of a validation check.
pub const ValidationResult = union(enum) {
    ok: void,
    err: []const u8,

    pub fn isOk(self: ValidationResult) bool {
        return self == .ok;
    }

    pub fn getMessage(self: ValidationResult) ?[]const u8 {
        return switch (self) {
            .err => |msg| msg,
            .ok => null,
        };
    }
};

/// Generic validator function type.
pub const ValidatorFn = *const fn ([]const u8) ValidationResult;

/// Default validators for common patterns.
pub const Validators = struct {
    pub fn nonEmpty(value: []const u8) ValidationResult {
        return if (value.len > 0) .{ .ok = {} } else .{ .err = "value cannot be empty" };
    }

    pub fn alphanumeric(value: []const u8) ValidationResult {
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c)) return .{ .err = "value must be alphanumeric" };
        }
        return .{ .ok = {} };
    }

    pub fn numeric(value: []const u8) ValidationResult {
        for (value) |c| {
            if (!std.ascii.isDigit(c)) return .{ .err = "value must be numeric" };
        }
        return .{ .ok = {} };
    }
};

test "parseValue string" {
    const allocator = std.testing.allocator;
    const result = try parseValue("hello", .string, allocator);
    try std.testing.expectEqualStrings("hello", result.string);
}

test "parseValue int" {
    const allocator = std.testing.allocator;
    const result = try parseValue("42", .int, allocator);
    try std.testing.expectEqual(@as(i64, 42), result.int);
}

test "parseValue int negative" {
    const allocator = std.testing.allocator;
    const result = try parseValue("-123", .int, allocator);
    try std.testing.expectEqual(@as(i64, -123), result.int);
}

test "parseValue uint" {
    const allocator = std.testing.allocator;
    const result = try parseValue("100", .uint, allocator);
    try std.testing.expectEqual(@as(u64, 100), result.uint);
}

test "parseValue float" {
    const allocator = std.testing.allocator;
    const result = try parseValue("3.14", .float, allocator);
    try std.testing.expect(@abs(result.float - 3.14) < 0.001);
}

test "parseValue bool" {
    const allocator = std.testing.allocator;
    const true_result = try parseValue("true", .bool, allocator);
    try std.testing.expect(true_result.boolean);

    const false_result = try parseValue("false", .bool, allocator);
    try std.testing.expect(!false_result.boolean);
}

test "validateChoice" {
    const choices = [_][]const u8{ "one", "two", "three" };
    try std.testing.expect(validateChoice("two", &choices));
    try std.testing.expect(!validateChoice("four", &choices));
}

test "parseBool" {
    try std.testing.expectEqual(@as(?bool, true), parseBool("true"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("yes"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("1"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("false"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("no"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("0"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("maybe"));
}

test "validateRange" {
    try std.testing.expect(validateRange(i32, 5, 0, 10));
    try std.testing.expect(!validateRange(i32, -1, 0, 10));
    try std.testing.expect(!validateRange(i32, 11, 0, 10));
    try std.testing.expect(validateRange(i32, 5, null, 10));
    try std.testing.expect(validateRange(i32, 5, 0, null));
}

test "validateLength" {
    try std.testing.expect(validateLength("hello", 3, 10));
    try std.testing.expect(!validateLength("hi", 3, 10));
    try std.testing.expect(!validateLength("hello world!", 3, 10));
}

test "parseIntInRange" {
    const val = try parseIntInRange(i32, "5", 0, 10);
    try std.testing.expectEqual(@as(i32, 5), val);

    try std.testing.expectError(error.OutOfRange, parseIntInRange(i32, "15", 0, 10));
    try std.testing.expectError(error.InvalidValue, parseIntInRange(i32, "abc", 0, 10));
}

test "Validators.nonEmpty" {
    try std.testing.expect(Validators.nonEmpty("hello").isOk());
    try std.testing.expect(!Validators.nonEmpty("").isOk());
}

test "Validators.alphanumeric" {
    try std.testing.expect(Validators.alphanumeric("Hello123").isOk());
    try std.testing.expect(!Validators.alphanumeric("Hello 123").isOk());
}
