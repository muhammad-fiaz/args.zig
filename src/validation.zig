//! Value validation and parsing for args.zig.

const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");

pub const ValueType = types.ValueType;
pub const ParsedValue = types.ParsedValue;
pub const DecodeMode = types.DecodeMode;

/// Decoded value wrapper with optional owned buffer.
pub const DecodedValue = struct {
    value: []const u8,
    owned: ?[]u8 = null,

    pub fn deinit(self: *const DecodedValue, allocator: std.mem.Allocator) void {
        if (self.owned) |buf| allocator.free(buf);
    }
};

/// Decode a value according to the requested decode mode.
/// For `.none`, the original slice is returned with no allocation.
pub fn decodeValueForMode(allocator: std.mem.Allocator, raw: []const u8, mode: DecodeMode) !DecodedValue {
    return switch (mode) {
        .none => .{ .value = raw },
        .base64_std => try decodeBase64(allocator, raw, false),
        .base64_url_safe => try decodeBase64(allocator, raw, true),
    };
}

fn decodeBase64(allocator: std.mem.Allocator, raw: []const u8, url_safe: bool) !DecodedValue {
    const decoder = if (url_safe) std.base64.url_safe.Decoder else std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(raw) catch return error.InvalidValue;
    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    decoder.decode(decoded, raw) catch return error.InvalidValue;
    return .{ .value = decoded, .owned = decoded };
}

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
pub fn validatePathExists(io: std.Io, path: []const u8) bool {
    std.Io.Dir.cwd().access(io, path, .{}) catch return false;
    return true;
}

/// Check if a path is absolute for the current platform path rules.
pub fn validateAbsolutePath(path: []const u8) bool {
    return std.fs.path.isAbsolute(path);
}

/// Check if a path exists and is a regular file.
pub fn validateFileExists(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return stat.kind == .file;
}

/// Check if a path exists and is a directory.
pub fn validateDirectoryExists(io: std.Io, path: []const u8) bool {
    const stat = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
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

/// Basic email format validation for common CLI input checks.
pub fn validateEmailAddress(value: []const u8) bool {
    const at_index = std.mem.indexOfScalar(u8, value, '@') orelse return false;
    if (at_index == 0 or at_index + 1 >= value.len) return false;
    if (std.mem.lastIndexOfScalar(u8, value, '@') != at_index) return false;

    const local = value[0..at_index];
    const domain = value[at_index + 1 ..];

    for (local) |c| {
        if (std.ascii.isAlphanumeric(c)) continue;
        if (c == '.' or c == '_' or c == '%' or c == '+' or c == '-') continue;
        return false;
    }

    var has_dot = false;
    for (domain) |c| {
        if (std.ascii.isAlphanumeric(c)) continue;
        if (c == '.') {
            has_dot = true;
            continue;
        }
        if (c == '-') continue;
        return false;
    }

    if (!has_dot) return false;
    if (domain[0] == '.' or domain[domain.len - 1] == '.') return false;
    return true;
}

/// Validates `http://` and `https://` URL inputs for command-line options.
pub fn validateHttpUrl(value: []const u8) bool {
    const http_prefix = "http://";
    const https_prefix = "https://";

    const rest = if (std.ascii.startsWithIgnoreCase(value, http_prefix))
        value[http_prefix.len..]
    else if (std.ascii.startsWithIgnoreCase(value, https_prefix))
        value[https_prefix.len..]
    else
        return false;

    if (rest.len == 0) return false;

    const separator_index = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
    const host = rest[0..separator_index];
    if (host.len == 0) return false;

    for (host) |c| {
        if (std.ascii.isAlphanumeric(c)) continue;
        if (c == '.' or c == '-' or c == ':' or c == '[' or c == ']') continue;
        return false;
    }

    return true;
}

/// Validates dotted IPv4 address strings (e.g. `192.168.1.10`).
pub fn validateIPv4Address(value: []const u8) bool {
    var it = std.mem.splitScalar(u8, value, '.');
    var count: usize = 0;

    while (it.next()) |part| {
        if (part.len == 0) return false;
        var number: u16 = 0;

        for (part) |c| {
            if (!std.ascii.isDigit(c)) return false;
            number = number * 10 + (c - '0');
            if (number > 255) return false;
        }

        count += 1;
    }

    return count == 4;
}

/// Validates canonical UUID strings (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).
pub fn validateUuid(value: []const u8) bool {
    if (value.len != 36) return false;

    for (value, 0..) |c, idx| {
        if (idx == 8 or idx == 13 or idx == 18 or idx == 23) {
            if (c != '-') return false;
            continue;
        }

        if (!std.ascii.isHex(c)) return false;
    }

    return true;
}

fn isLeapYear(year: i32) bool {
    if (@mod(year, 400) == 0) return true;
    if (@mod(year, 100) == 0) return false;
    return @mod(year, 4) == 0;
}

/// Validates `YYYY-MM-DD` format dates.
pub fn validateIsoDate(value: []const u8) bool {
    if (value.len != 10) return false;
    if (value[4] != '-' or value[7] != '-') return false;

    const year = std.fmt.parseInt(i32, value[0..4], 10) catch return false;
    const month = std.fmt.parseInt(u8, value[5..7], 10) catch return false;
    const day = std.fmt.parseInt(u8, value[8..10], 10) catch return false;

    if (month < 1 or month > 12) return false;
    if (day < 1) return false;

    const max_day: u8 = switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => return false,
    };

    return day <= max_day;
}

/// Validates `YYYY-MM-DDTHH:MM:SS` or `YYYY-MM-DDTHH:MM:SSZ` timestamps.
pub fn validateIsoDateTime(value: []const u8) bool {
    const has_z = value.len == 20 and value[value.len - 1] == 'Z';
    if (!(value.len == 19 or has_z)) return false;

    const base = if (has_z) value[0 .. value.len - 1] else value;

    if (base[10] != 'T') return false;
    if (!validateIsoDate(base[0..10])) return false;
    if (base[13] != ':' or base[16] != ':') return false;

    const hour = std.fmt.parseInt(u8, base[11..13], 10) catch return false;
    const minute = std.fmt.parseInt(u8, base[14..16], 10) catch return false;
    const second = std.fmt.parseInt(u8, base[17..19], 10) catch return false;

    return hour <= 23 and minute <= 59 and second <= 59;
}

/// Validates that a string is valid JSON text.
pub fn validateJsonValue(value: []const u8) bool {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const parsed = std.json.parseFromSlice(std.json.Value, arena.allocator(), value, .{}) catch return false;
    _ = parsed;
    return true;
}

/// Validates a four-digit year string (`YYYY`).
pub fn validateYear(value: []const u8) bool {
    if (value.len != 4) return false;
    for (value) |c| {
        if (!std.ascii.isDigit(c)) return false;
    }
    _ = std.fmt.parseInt(u16, value, 10) catch return false;
    return true;
}

/// Validates time in 24-hour format: `HH:MM` or `HH:MM:SS`.
pub fn validateTime24(value: []const u8) bool {
    if (!(value.len == 5 or value.len == 8)) return false;
    if (value[2] != ':') return false;

    const hour = std.fmt.parseInt(u8, value[0..2], 10) catch return false;
    const minute = std.fmt.parseInt(u8, value[3..5], 10) catch return false;

    if (hour > 23 or minute > 59) return false;

    if (value.len == 8) {
        if (value[5] != ':') return false;
        const second = std.fmt.parseInt(u8, value[6..8], 10) catch return false;
        if (second > 59) return false;
    }

    return true;
}

/// Validates hostnames using common DNS label constraints.
pub fn validateHostName(value: []const u8) bool {
    if (value.len == 0 or value.len > 253) return false;

    var label_start: usize = 0;
    var idx: usize = 0;
    while (idx <= value.len) : (idx += 1) {
        const is_end = idx == value.len or value[idx] == '.';
        if (!is_end) continue;

        const label = value[label_start..idx];
        if (label.len == 0 or label.len > 63) return false;

        const first = label[0];
        const last = label[label.len - 1];
        if (!std.ascii.isAlphanumeric(first) or !std.ascii.isAlphanumeric(last)) return false;

        for (label) |c| {
            if (std.ascii.isAlphanumeric(c) or c == '-') continue;
            return false;
        }

        label_start = idx + 1;
    }

    return true;
}

/// Validates port number strings in range 1..65535.
pub fn validatePort(value: []const u8) bool {
    const parsed = std.fmt.parseInt(u16, value, 10) catch return false;
    return parsed >= 1;
}

/// Validates IPv6 address literals (compressed and mixed forms).
pub fn validateIPv6Address(value: []const u8) bool {
    if (value.len < 2) return false;

    var has_colon = false;
    for (value) |c| {
        if (std.ascii.isHex(c)) continue;
        if (c == ':') {
            has_colon = true;
            continue;
        }
        if (c == '.') continue;
        return false;
    }
    return has_colon;
}

/// Validates host:port endpoint values.
/// Supports: hostname:port, ipv4:port, and [ipv6]:port.
pub fn validateEndpoint(value: []const u8) bool {
    if (value.len < 3) return false;

    if (value[0] == '[') {
        const end_idx = std.mem.indexOfScalar(u8, value, ']') orelse return false;
        if (end_idx + 2 > value.len) return false;
        if (value[end_idx + 1] != ':') return false;

        const host = value[1..end_idx];
        const port = value[end_idx + 2 ..];
        return validateIPv6Address(host) and validatePort(port);
    }

    const colon_idx = std.mem.lastIndexOfScalar(u8, value, ':') orelse return false;
    const host = value[0..colon_idx];
    const port = value[colon_idx + 1 ..];

    if (host.len == 0) return false;
    if (!validatePort(port)) return false;

    return validateHostName(host) or validateIPv4Address(host);
}

/// Validates KEY=VALUE syntax where both key and value are non-empty.
pub fn validateKeyValuePair(value: []const u8) bool {
    const idx = std.mem.indexOfScalar(u8, value, '=') orelse return false;
    if (idx == 0) return false;
    if (idx + 1 >= value.len) return false;
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
pub const ValidatorFn = *const fn (std.Io, []const u8) ValidationResult;

/// Default validators for common patterns.
pub const Validators = struct {
    pub fn nonEmpty(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (value.len > 0) .{ .ok = {} } else .{ .err = "value cannot be empty" };
    }

    pub fn alphanumeric(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c)) return .{ .err = "value must be alphanumeric" };
        }
        return .{ .ok = {} };
    }

    pub fn numeric(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        for (value) |c| {
            if (!std.ascii.isDigit(c)) return .{ .err = "value must be numeric" };
        }
        return .{ .ok = {} };
    }

    pub fn emailAddress(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateEmailAddress(value)) .{ .ok = {} } else .{ .err = "invalid email address" };
    }

    pub fn httpUrl(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateHttpUrl(value)) .{ .ok = {} } else .{ .err = "invalid URL (expected http/https)" };
    }

    pub fn ipv4(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv4Address(value)) .{ .ok = {} } else .{ .err = "invalid IPv4 address" };
    }

    pub fn ipv6(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv6Address(value)) .{ .ok = {} } else .{ .err = "invalid IPv6 address" };
    }

    pub fn ipAny(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv4Address(value) or validateIPv6Address(value)) .{ .ok = {} } else .{ .err = "invalid IP address" };
    }

    pub fn uuid(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateUuid(value)) .{ .ok = {} } else .{ .err = "invalid UUID" };
    }

    pub fn isoDate(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIsoDate(value)) .{ .ok = {} } else .{ .err = "invalid date (expected YYYY-MM-DD)" };
    }

    pub fn isoDateTime(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIsoDateTime(value)) .{ .ok = {} } else .{ .err = "invalid date-time (expected YYYY-MM-DDTHH:MM:SS[Z])" };
    }

    pub fn json(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateJsonValue(value)) .{ .ok = {} } else .{ .err = "invalid JSON" };
    }

    pub fn year(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateYear(value)) .{ .ok = {} } else .{ .err = "invalid year (expected YYYY)" };
    }

    pub fn time(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateTime24(value)) .{ .ok = {} } else .{ .err = "invalid time (expected HH:MM or HH:MM:SS)" };
    }

    pub fn hostname(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateHostName(value)) .{ .ok = {} } else .{ .err = "invalid hostname" };
    }

    pub fn port(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validatePort(value)) .{ .ok = {} } else .{ .err = "invalid port (expected 1..65535)" };
    }

    pub fn endpoint(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateEndpoint(value)) .{ .ok = {} } else .{ .err = "invalid endpoint (expected host:port)" };
    }

    pub fn keyValuePair(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateKeyValuePair(value)) .{ .ok = {} } else .{ .err = "invalid key=value pair" };
    }

    pub fn intRange(comptime min: ?i64, comptime max: ?i64) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                _ = parseIntInRange(i64, value, min, max) catch |err| {
                    return switch (err) {
                        error.InvalidValue => .{ .err = "invalid integer" },
                        error.OutOfRange => .{ .err = "integer is out of range" },
                    };
                };
                return .{ .ok = {} };
            }
        }.validate;
    }

    pub fn floatRange(comptime min: ?f64, comptime max: ?f64) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                _ = parseFloatInRange(value, min, max) catch |err| {
                    return switch (err) {
                        error.InvalidValue => .{ .err = "invalid float" },
                        error.OutOfRange => .{ .err = "float is out of range" },
                    };
                };
                return .{ .ok = {} };
            }
        }.validate;
    }

    pub fn pathExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validatePathExists(io, value)) .{ .ok = {} } else .{ .err = "path does not exist" };
    }

    pub fn absolutePath(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateAbsolutePath(value)) .{ .ok = {} } else .{ .err = "path must be absolute" };
    }

    pub fn fileExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validateFileExists(io, value)) .{ .ok = {} } else .{ .err = "file does not exist" };
    }

    pub fn directoryExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validateDirectoryExists(io, value)) .{ .ok = {} } else .{ .err = "directory does not exist" };
    }

    pub fn fileNameSafe(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateFileName(value)) .{ .ok = {} } else .{ .err = "invalid file name" };
    }

    /// Creates a validator for file name length.
    pub fn fileNameLength(comptime min_len: usize, comptime max_len: usize) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
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
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
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
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Creates a validator that requires existing file with an allowed extension.
    pub fn existingFileWithExtension(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                if (!validateFileExists(io, value)) return .{ .err = "file does not exist" };
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Creates a validator for safe file names that must use one of the allowed extensions.
    pub fn fileNameWithExtensions(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                if (!validateFileName(value)) return .{ .err = "invalid file name" };
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Compose validators with logical AND semantics.
    pub fn allOf(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                inline for (validator_list) |validator| {
                    const res = validator(io, value);
                    if (!res.isOk()) return res;
                }
                return .{ .ok = {} };
            }
        }.validate;
    }

    /// Compose validators with logical OR semantics.
    pub fn anyOf(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                inline for (validator_list) |validator| {
                    const res = validator(io, value);
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
    pub const email = emailAddress;
    pub const url = httpUrl;
    pub const ip = ipv4;
    pub const anyIp = ipAny;
    pub const keyValue = keyValuePair;
    pub const hostPort = endpoint;
    pub const date = isoDate;
    pub const dateTime = isoDateTime;
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
    try std.testing.expect(Validators.nonEmpty(std.Io.failing, "hello").isOk());
    try std.testing.expect(!Validators.nonEmpty(std.Io.failing, "").isOk());
}

test "Validators.alphanumeric" {
    try std.testing.expect(Validators.alphanumeric(std.Io.failing, "Hello123").isOk());
    try std.testing.expect(!Validators.alphanumeric(std.Io.failing, "Hello 123").isOk());
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
    try std.testing.expect(validator(std.Io.failing, "config.json").isOk());
    try std.testing.expect(validator(std.Io.failing, "CONFIG.YAML").isOk());
    try std.testing.expect(!validator(std.Io.failing, "config.txt").isOk());
    try std.testing.expect(!validator(std.Io.failing, "path/config.json").isOk());
}

test "Validators.allOf and anyOf" {
    const valid_name = Validators.allOf(&[_]ValidatorFn{
        Validators.fileNameSafe,
        Validators.fileNameLength(3, 32),
    });
    try std.testing.expect(valid_name(std.Io.failing, "cfg.json").isOk());
    try std.testing.expect(!valid_name(std.Io.failing, "a").isOk());

    const numeric_or_alnum = Validators.anyOf(&[_]ValidatorFn{
        Validators.numeric,
        Validators.alphanumeric,
    });
    try std.testing.expect(numeric_or_alnum(std.Io.failing, "123").isOk());
    try std.testing.expect(numeric_or_alnum(std.Io.failing, "abc123").isOk());
    try std.testing.expect(!numeric_or_alnum(std.Io.failing, "abc-123").isOk());
}

test "Validators.fileNamePolicy" {
    const validator = Validators.fileNamePolicy(&[_][]const u8{"json"}, false, 8, 64);
    try std.testing.expect(validator(std.Io.failing, "result.json").isOk());
    try std.testing.expect(!validator(std.Io.failing, "result.txt").isOk());
    try std.testing.expect(!validator(std.Io.failing, "ab.json").isOk());
    try std.testing.expect(!validator(std.Io.failing, "bad/name.json").isOk());
}

test "email, URL, IP, UUID validators" {
    try std.testing.expect(validateEmailAddress("user@example.com"));
    try std.testing.expect(!validateEmailAddress("user@example"));

    try std.testing.expect(validateHttpUrl("https://example.com/path"));
    try std.testing.expect(!validateHttpUrl("ftp://example.com"));

    try std.testing.expect(validateIPv4Address("192.168.1.10"));
    try std.testing.expect(!validateIPv4Address("256.1.1.1"));

    try std.testing.expect(validateIPv6Address("2001:db8::1"));
    try std.testing.expect(validateIPv6Address("::1"));
    try std.testing.expect(!validateIPv6Address("not-an-ip"));

    try std.testing.expect(validateUuid("123e4567-e89b-12d3-a456-426614174000"));
    try std.testing.expect(!validateUuid("not-a-uuid"));
}

test "date and JSON validators" {
    try std.testing.expect(validateIsoDate("2026-03-30"));
    try std.testing.expect(!validateIsoDate("2026-02-30"));

    try std.testing.expect(validateIsoDateTime("2026-03-30T14:25:59"));
    try std.testing.expect(validateIsoDateTime("2026-03-30T14:25:59Z"));
    try std.testing.expect(!validateIsoDateTime("2026/03/30 14:25:59"));

    try std.testing.expect(validateJsonValue("{\"ok\":true}"));
    try std.testing.expect(!validateJsonValue("{not-json}"));
}

test "absolute path, year, and time validators" {
    try std.testing.expect(!validateAbsolutePath("relative/path"));

    try std.testing.expect(validateYear("2026"));
    try std.testing.expect(!validateYear("26"));
    try std.testing.expect(!validateYear("20ab"));

    try std.testing.expect(validateTime24("14:30"));
    try std.testing.expect(validateTime24("14:30:59"));
    try std.testing.expect(!validateTime24("24:00"));
    try std.testing.expect(!validateTime24("14:61"));
}

test "hostname and port validators" {
    try std.testing.expect(validateHostName("api.example.com"));
    try std.testing.expect(validateHostName("localhost"));
    try std.testing.expect(!validateHostName("-bad-host"));
    try std.testing.expect(!validateHostName("bad_host"));

    try std.testing.expect(validatePort("8080"));
    try std.testing.expect(!validatePort("0"));
    try std.testing.expect(!validatePort("70000"));
}

test "endpoint validator" {
    try std.testing.expect(validateEndpoint("api.example.com:443"));
    try std.testing.expect(validateEndpoint("127.0.0.1:8080"));
    try std.testing.expect(validateEndpoint("[2001:db8::1]:443"));

    try std.testing.expect(!validateEndpoint("api.example.com"));
    try std.testing.expect(!validateEndpoint("api.example.com:0"));
    try std.testing.expect(!validateEndpoint("[2001:db8::1]"));
}

test "Validators intRange and floatRange" {
    const int_validator = Validators.intRange(1, 10);
    try std.testing.expect(int_validator(std.Io.failing, "5").isOk());
    try std.testing.expect(!int_validator(std.Io.failing, "0").isOk());
    try std.testing.expect(!int_validator(std.Io.failing, "abc").isOk());

    const float_validator = Validators.floatRange(0.1, 1.0);
    try std.testing.expect(float_validator(std.Io.failing, "0.5").isOk());
    try std.testing.expect(!float_validator(std.Io.failing, "2.0").isOk());
    try std.testing.expect(!float_validator(std.Io.failing, "bad").isOk());
}

test "Validators ipv6 and ipAny" {
    try std.testing.expect(Validators.ipv6(std.Io.failing, "2001:db8::8a2e:370:7334").isOk());
    try std.testing.expect(!Validators.ipv6(std.Io.failing, "invalid-v6").isOk());

    try std.testing.expect(Validators.ipAny(std.Io.failing, "192.168.0.1").isOk());
    try std.testing.expect(Validators.ipAny(std.Io.failing, "fe80::1").isOk());
    try std.testing.expect(!Validators.ipAny(std.Io.failing, "hostname").isOk());
}

test "Validators keyValuePair" {
    try std.testing.expect(validateKeyValuePair("env=prod"));
    try std.testing.expect(!validateKeyValuePair("env="));
    try std.testing.expect(!validateKeyValuePair("=prod"));
    try std.testing.expect(!validateKeyValuePair("novalue"));

    try std.testing.expect(Validators.keyValuePair(std.Io.failing, "k=v").isOk());
    try std.testing.expect(!Validators.keyValuePair(std.Io.failing, "k=").isOk());
}
