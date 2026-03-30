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
        .key_value => blk: {
            if (std.mem.indexOfScalar(u8, value, '=')) |idx| {
                const k = value[0..idx];
                const v = value[idx + 1 ..];
                break :blk .{ .key_value = .{ .key = k, .value = v } };
            } else {
                return error.InvalidValue; // Expected key=value
            }
        },
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

/// Check if a path exists and is a regular file.
pub fn validateFileExists(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .file;
}

/// Check if a path exists and is a directory.
pub fn validateDirectoryExists(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

/// Returns the extension portion without the dot (e.g. "json" for "a/b/c.json").
pub fn pathExtension(path: []const u8) ?[]const u8 {
    const file_name = std.fs.path.basename(path);
    const dot_index = std.mem.lastIndexOfScalar(u8, file_name, '.') orelse return null;
    if (dot_index + 1 >= file_name.len) return null;
    return file_name[dot_index + 1 ..];
}

/// Check if path has the given extension. `ext` may include or omit the leading dot.
pub fn hasExtension(path: []const u8, ext: []const u8, case_sensitive: bool) bool {
    const current = pathExtension(path) orelse return false;
    const normalized_ext = if (ext.len > 0 and ext[0] == '.') ext[1..] else ext;

    if (case_sensitive) return std.mem.eql(u8, current, normalized_ext);
    return std.ascii.eqlIgnoreCase(current, normalized_ext);
}

/// Check if path has any extension from the allowed list.
pub fn hasAnyExtension(path: []const u8, allowed: []const []const u8, case_sensitive: bool) bool {
    for (allowed) |ext| {
        if (hasExtension(path, ext, case_sensitive)) return true;
    }
    return false;
}

/// Validates that a value is a safe file name (not a path).
pub fn validateFileName(file_name: []const u8) bool {
    if (file_name.len == 0) return false;
    if (std.mem.eql(u8, file_name, ".") or std.mem.eql(u8, file_name, "..")) return false;

    // Disallow path separators and common invalid filename characters.
    for (file_name) |c| {
        if (c < 32) return false;
        if (c == '/' or c == '\\') return false;
        if (c == '<' or c == '>' or c == ':' or c == '"' or c == '|' or c == '?' or c == '*') return false;
    }

    // Windows compatibility: no trailing dot or space.
    const last = file_name[file_name.len - 1];
    if (last == '.' or last == ' ') return false;

    return true;
}

fn ensureAllowedExtension(value: []const u8, allowed_extensions: []const []const u8, case_sensitive: bool) ValidationResult {
    if (hasAnyExtension(value, allowed_extensions, case_sensitive)) return .{ .ok = {} };
    return .{ .err = "file extension is not allowed" };
}

fn ensureLength(value: []const u8, min_len: ?usize, max_len: ?usize, msg: []const u8) ValidationResult {
    if (!validateLength(value, min_len, max_len)) return .{ .err = msg };
    return .{ .ok = {} };
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

    pub fn pathExists(value: []const u8) ValidationResult {
        return if (validatePathExists(value)) .{ .ok = {} } else .{ .err = "path does not exist" };
    }

    pub fn fileExists(value: []const u8) ValidationResult {
        return if (validateFileExists(value)) .{ .ok = {} } else .{ .err = "file does not exist" };
    }

    pub fn directoryExists(value: []const u8) ValidationResult {
        return if (validateDirectoryExists(value)) .{ .ok = {} } else .{ .err = "directory does not exist" };
    }

    pub fn fileNameSafe(value: []const u8) ValidationResult {
        return if (validateFileName(value)) .{ .ok = {} } else .{ .err = "invalid file name" };
    }

    /// Creates a validator for file name length.
    pub fn fileNameLength(comptime min_len: usize, comptime max_len: usize) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                return ensureLength(value, min_len, max_len, "file name length is out of range");
            }
        }.validate;
    }

    /// One-call filename policy validator for common CLI output/input file-name checks.
    /// - Always enforces safe file-name rules (no path separators/invalid chars)
    /// - Optionally enforces extension membership
    /// - Optionally enforces min/max length
    pub fn fileNamePolicy(
        comptime allowed_extensions: []const []const u8,
        comptime case_sensitive_extensions: bool,
        comptime min_len: ?usize,
        comptime max_len: ?usize,
    ) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                if (!validateFileName(value)) return .{ .err = "invalid file name" };

                if (allowed_extensions.len > 0) {
                    const extension_result = ensureAllowedExtension(value, allowed_extensions, case_sensitive_extensions);
                    if (!extension_result.isOk()) return extension_result;
                }

                const length_result = ensureLength(value, min_len, max_len, "file name length is out of range");
                if (!length_result.isOk()) return length_result;

                return .{ .ok = {} };
            }
        }.validate;
    }

    /// Creates a validator that checks file extension membership.
    pub fn extension(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Creates a validator that requires existing file with an allowed extension.
    pub fn existingFileWithExtension(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                if (!validateFileExists(value)) return .{ .err = "file does not exist" };
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Creates a validator for safe file names that must use one of the allowed extensions.
    pub fn fileNameWithExtensions(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                if (!validateFileName(value)) return .{ .err = "invalid file name" };
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Compose validators with logical AND semantics.
    pub fn allOf(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                inline for (validator_list) |validator| {
                    const res = validator(value);
                    if (!res.isOk()) return res;
                }
                return .{ .ok = {} };
            }
        }.validate;
    }

    /// Compose validators with logical OR semantics.
    pub fn anyOf(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return struct {
            fn validate(value: []const u8) ValidationResult {
                inline for (validator_list) |validator| {
                    const res = validator(value);
                    if (res.isOk()) return .{ .ok = {} };
                }
                return .{ .err = "value did not satisfy any validator" };
            }
        }.validate;
    }

    // Aliases for concise client-side usage.
    pub fn all(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return allOf(validator_list);
    }

    pub fn any(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return anyOf(validator_list);
    }

    pub const fileName = fileNameSafe;
    pub const ext = extension;
    pub const fileExt = fileNameWithExtensions;
    pub const filePolicy = fileNamePolicy;
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

test "hasExtension and hasAnyExtension" {
    try std.testing.expect(hasExtension("config.json", "json", true));
    try std.testing.expect(hasExtension("config.JSON", "json", false));
    try std.testing.expect(hasExtension("config.json", ".json", true));
    try std.testing.expect(!hasExtension("config.json", "yaml", false));

    const allowed = [_][]const u8{ "json", "yaml" };
    try std.testing.expect(hasAnyExtension("config.yml", &allowed, false) == false);
    try std.testing.expect(hasAnyExtension("config.yaml", &allowed, false));
}

test "validateFileName" {
    try std.testing.expect(validateFileName("report.json"));
    try std.testing.expect(validateFileName("build-config.toml"));
    try std.testing.expect(!validateFileName(""));
    try std.testing.expect(!validateFileName("../report.json"));
    try std.testing.expect(!validateFileName("bad:name.json"));
    try std.testing.expect(!validateFileName("name. "));
}

test "Validators.fileNameWithExtensions" {
    const validator = Validators.fileNameWithExtensions(&[_][]const u8{ "json", "yaml" }, false);
    try std.testing.expect(validator("config.json").isOk());
    try std.testing.expect(validator("CONFIG.YAML").isOk());
    try std.testing.expect(!validator("config.txt").isOk());
    try std.testing.expect(!validator("path/config.json").isOk());
}

test "Validators.allOf and anyOf" {
    const valid_name = Validators.allOf(&[_]ValidatorFn{
        Validators.fileNameSafe,
        Validators.fileNameLength(3, 32),
    });
    try std.testing.expect(valid_name("cfg.json").isOk());
    try std.testing.expect(!valid_name("a").isOk());

    const numeric_or_alnum = Validators.anyOf(&[_]ValidatorFn{
        Validators.numeric,
        Validators.alphanumeric,
    });
    try std.testing.expect(numeric_or_alnum("123").isOk());
    try std.testing.expect(numeric_or_alnum("abc123").isOk());
    try std.testing.expect(!numeric_or_alnum("abc-123").isOk());
}

test "Validators.fileNamePolicy" {
    const validator = Validators.fileNamePolicy(&[_][]const u8{"json"}, false, 8, 64);
    try std.testing.expect(validator("result.json").isOk());
    try std.testing.expect(!validator("result.txt").isOk());
    try std.testing.expect(!validator("ab.json").isOk());
    try std.testing.expect(!validator("bad/name.json").isOk());
}
