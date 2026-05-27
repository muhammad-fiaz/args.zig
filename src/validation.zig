//! Value validation and parsing for args.zig.

const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

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
        .hex => try decodeHex(allocator, raw),
    };
}

fn decodeHex(allocator: std.mem.Allocator, raw: []const u8) !DecodedValue {
    if (raw.len % 2 != 0) return error.InvalidValue;
    const decoded_len = raw.len / 2;
    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    for (0..decoded_len) |i| {
        const hi = std.fmt.charToDigit(raw[i * 2], 16) catch return error.InvalidValue;
        const lo = std.fmt.charToDigit(raw[i * 2 + 1], 16) catch return error.InvalidValue;
        decoded[i] = @as(u8, @intCast(hi * 16 + lo));
    }
    return .{ .value = decoded, .owned = decoded };
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
        .duration => .{ .uint = parseDuration(value) catch return error.InvalidValue },
        .byte_size => .{ .uint = parseByteSize(value) catch return error.InvalidValue },
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

/// Validates hex color codes (`#RGB`, `#RRGGBB`, `#RGBA`, `#RRGGBBAA`).
pub fn validateHexColor(value: []const u8) bool {
    if (value.len < 2 or value[0] != '#') return false;
    const hex = value[1..];
    if (hex.len != 3 and hex.len != 4 and hex.len != 6 and hex.len != 8) return false;
    for (hex) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

/// Validates semantic version strings (`MAJOR.MINOR.PATCH` with optional pre-release/build).
pub fn validateSemver(value: []const u8) bool {
    if (value.len == 0) return false;
    _ = std.SemanticVersion.parse(value) catch return false;
    return true;
}

/// Validates base64 encoded strings.
pub fn validateBase64(value: []const u8) bool {
    if (value.len == 0) return false;
    const decoder = std.base64.standard.Decoder;
    const decoded_len = decoder.calcSizeForSlice(value) catch return false;
    const decoded = std.heap.page_allocator.alloc(u8, decoded_len) catch return false;
    defer std.heap.page_allocator.free(decoded);
    decoder.decode(decoded, value) catch return false;
    return true;
}

/// Validates MAC addresses (`XX:XX:XX:XX:XX:XX` or `XX-XX-XX-XX-XX-XX`).
pub fn validateMacAddress(value: []const u8) bool {
    if (value.len != 17) return false;
    const sep = value[2];
    if (sep != ':' and sep != '-') return false;
    for (0..6) |i| {
        const offset = i * 3;
        if (!std.ascii.isHex(value[offset]) or !std.ascii.isHex(value[offset + 1])) return false;
        if (i < 5 and value[offset + 2] != sep) return false;
    }
    return true;
}

/// Validates that a string contains only ASCII characters.
pub fn validateAsciiOnly(value: []const u8) bool {
    for (value) |c| {
        if (c > 127) return false;
    }
    return true;
}

/// Validates that a string is all lowercase ASCII.
pub fn validateLowercase(value: []const u8) bool {
    for (value) |c| {
        if (std.ascii.isUpper(c)) return false;
    }
    return true;
}

/// Validates that a string is all uppercase ASCII.
pub fn validateUppercase(value: []const u8) bool {
    for (value) |c| {
        if (std.ascii.isLower(c)) return false;
    }
    return true;
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
    return .{ .err = constants.ValidationMessages.extension_not_allowed };
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
        return if (value.len > 0) .{ .ok = {} } else .{ .err = constants.ValidationMessages.cannot_be_empty };
    }

    pub fn alphanumeric(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c)) return .{ .err = constants.ValidationMessages.must_be_alphanumeric };
        }
        return .{ .ok = {} };
    }

    pub fn numeric(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        for (value) |c| {
            if (!std.ascii.isDigit(c)) return .{ .err = constants.ValidationMessages.must_be_numeric };
        }
        return .{ .ok = {} };
    }

    pub fn emailAddress(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateEmailAddress(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_email };
    }

    pub fn httpUrl(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateHttpUrl(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_url };
    }

    pub fn ipv4(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv4Address(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_ipv4 };
    }

    pub fn ipv6(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv6Address(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_ipv6 };
    }

    pub fn ipAny(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIPv4Address(value) or validateIPv6Address(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_ip };
    }

    pub fn uuid(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateUuid(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_uuid };
    }

    pub fn isoDate(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIsoDate(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_iso_date };
    }

    pub fn isoDateTime(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateIsoDateTime(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_iso_datetime };
    }

    pub fn json(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateJsonValue(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_json };
    }

    pub fn year(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateYear(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_year };
    }

    pub fn time(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateTime24(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_time };
    }

    pub fn hostname(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateHostName(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_hostname };
    }

    pub fn port(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validatePort(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_port };
    }

    pub fn hexColor(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateHexColor(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_hex_color };
    }

    pub fn semver(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateSemver(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_semver };
    }

    pub fn base64(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateBase64(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_base64 };
    }

    pub fn macAddress(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateMacAddress(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_mac };
    }

    pub fn asciiOnlyStr(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateAsciiOnly(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.ascii_only };
    }

    pub fn lowercase(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateLowercase(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.must_be_lowercase };
    }

    pub fn uppercase(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateUppercase(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.must_be_uppercase };
    }

    pub fn endpoint(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateEndpoint(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_endpoint };
    }

    pub fn keyValuePair(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateKeyValuePair(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_kv_pair };
    }

    pub fn intRange(comptime min: ?i64, comptime max: ?i64) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                _ = parseIntInRange(i64, value, min, max) catch |err| {
                    return switch (err) {
                        error.InvalidValue => .{ .err = constants.ValidationMessages.invalid_int },
                        error.OutOfRange => .{ .err = constants.ValidationMessages.int_out_of_range },
                    };
                };
                return .{ .ok = {} };
            }
        }.validate;
    }

    pub fn uintRange(comptime min: u64, comptime max: u64) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                const parsed = std.fmt.parseInt(u64, value, 10) catch return .{ .err = constants.ValidationMessages.invalid_uint };
                if (parsed < min or parsed > max) return .{ .err = constants.ValidationMessages.uint_out_of_range };
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
                        error.InvalidValue => .{ .err = constants.ValidationMessages.invalid_float },
                        error.OutOfRange => .{ .err = constants.ValidationMessages.float_out_of_range },
                    };
                };
                return .{ .ok = {} };
            }
        }.validate;
    }

    pub fn pathExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validatePathExists(io, value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.path_not_exist };
    }

    pub fn absolutePath(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateAbsolutePath(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.path_must_be_absolute };
    }

    pub fn fileExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validateFileExists(io, value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.file_not_exist };
    }

    pub fn directoryExists(io: std.Io, value: []const u8) ValidationResult {
        return if (validateDirectoryExists(io, value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.dir_not_exist };
    }

    pub fn fileNameSafe(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        return if (validateFileName(value)) .{ .ok = {} } else .{ .err = constants.ValidationMessages.invalid_file_name };
    }

    /// Creates a validator for character length range.
    pub fn charRange(comptime min_len: usize, comptime max_len: usize) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                if (value.len < min_len or value.len > max_len) {
                    return .{ .err = constants.ValidationMessages.char_length_out_of_range };
                }
                return .{ .ok = {} };
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
                if (!validateFileName(value)) return .{ .err = constants.ValidationMessages.invalid_file_name };

                if (allowed_extensions.len > 0) {
                    const extension_result = ensureAllowedExtension(value, allowed_extensions, case_sensitive_extensions);
                    if (!extension_result.isOk()) return extension_result;
                }

                const length_result = ensureLength(value, min_len, max_len, constants.ValidationMessages.file_name_length_out_of_range);
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
                if (!validateFileExists(io, value)) return .{ .err = constants.ValidationMessages.file_not_exist };
                return ensureAllowedExtension(value, allowed_extensions, case_sensitive);
            }
        }.validate;
    }

    /// Creates a validator for safe file names that must use one of the allowed extensions.
    pub fn fileNameWithExtensions(comptime allowed_extensions: []const []const u8, comptime case_sensitive: bool) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                if (!validateFileName(value)) return .{ .err = constants.ValidationMessages.invalid_file_name };
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
                return .{ .err = constants.ValidationMessages.no_validator_matched };
            }
        }.validate;
    }

    pub const fileName = fileNameSafe;
    pub const email = emailAddress;
    pub const url = httpUrl;
    pub const ip = ipv4;
    pub const hexColour = hexColor;
    pub const asciiOnly = asciiOnlyStr;
    pub const mac = macAddress;
    pub const anyIp = ipAny;
    pub const keyValue = keyValuePair;
    pub const hostPort = endpoint;
    pub const date = isoDate;
    pub const dateTime = isoDateTime;
    pub const ext = extension;
    pub const fileExt = fileNameWithExtensions;
    pub const filePolicy = fileNamePolicy;

    // Aliases for concise client-side usage.
    pub fn all(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return allOf(validator_list);
    }

    pub fn any(comptime validator_list: []const ValidatorFn) ValidatorFn {
        return anyOf(validator_list);
    }

    // ──────────────────────────────────────────────────────────────────
    // New validators added in v0.0.6
    // ──────────────────────────────────────────────────────────────────

    /// Alias for `nonEmpty` — value must not be an empty string.
    pub const notEmpty = nonEmpty;

    /// Value must contain ONLY letters and digits ([a-zA-Z0-9]).
    /// Messages come from constants.ErrorMessages.
    pub fn alphanumericStrict(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        if (value.len == 0) return .{ .err = constants.ErrorMessages.validation_not_alphanumeric };
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c))
                return .{ .err = constants.ErrorMessages.validation_not_alphanumeric };
        }
        return .{ .ok = {} };
    }

    /// Value must be a URL-safe slug: lowercase letters, digits, hyphens only.
    pub fn slug(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        if (value.len == 0) return .{ .err = constants.ErrorMessages.validation_not_slug };
        for (value) |c| {
            const ok = std.ascii.isLower(c) or std.ascii.isDigit(c) or c == '-';
            if (!ok) return .{ .err = constants.ErrorMessages.validation_not_slug };
        }
        return .{ .ok = {} };
    }

    /// Value must not contain any whitespace (space, tab, newline, etc.).
    pub fn noWhitespace(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        for (value) |c| {
            if (std.ascii.isWhitespace(c))
                return .{ .err = constants.ErrorMessages.validation_has_whitespace };
        }
        return .{ .ok = {} };
    }

    /// Value must parse as a number > 0.
    pub fn positive(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        const f = std.fmt.parseFloat(f64, value) catch
            return .{ .err = constants.ErrorMessages.validation_not_positive };
        if (f <= 0.0) return .{ .err = constants.ErrorMessages.validation_not_positive };
        return .{ .ok = {} };
    }

    /// Value must parse as a number >= 0.
    pub fn nonNegative(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        const f = std.fmt.parseFloat(f64, value) catch
            return .{ .err = constants.ErrorMessages.validation_not_non_negative };
        if (f < 0.0) return .{ .err = constants.ErrorMessages.validation_not_non_negative };
        return .{ .ok = {} };
    }

    /// Value must have at least `n` characters.
    pub fn minLength(comptime n: usize) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                if (value.len < n) return .{ .err = constants.ErrorMessages.validation_min_length };
                return .{ .ok = {} };
            }
        }.validate;
    }

    /// Value must have at most `n` characters.
    pub fn maxLength(comptime n: usize) ValidatorFn {
        return struct {
            fn validate(io: std.Io, value: []const u8) ValidationResult {
                _ = io;
                if (value.len > n) return .{ .err = constants.ErrorMessages.validation_max_length };
                return .{ .ok = {} };
            }
        }.validate;
    }

    /// Validates duration strings like `1h30m`, `45s`, `2d`, `3h`, `10m30s`.
    pub fn duration(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        _ = parseDuration(value) catch
            return .{ .err = constants.ErrorMessages.validation_invalid_duration };
        return .{ .ok = {} };
    }

    /// Validates byte-size strings like `1GB`, `512MB`, `4096`, `2TB`.
    pub fn byteSize(io: std.Io, value: []const u8) ValidationResult {
        _ = io;
        _ = parseByteSize(value) catch
            return .{ .err = constants.ErrorMessages.validation_invalid_size };
        return .{ .ok = {} };
    }
};

// ──────────────────────────────────────────────────────────────────────────────
// Duration and byte-size parsing (standalone helpers used by Validators above)
// ──────────────────────────────────────────────────────────────────────────────

/// Parse a duration string into total seconds.
/// Supported units: d (days), h (hours), m (minutes), s (seconds).
/// Examples: "1h30m" → 5400, "45s" → 45, "2d" → 172800.
/// Returns error.InvalidValue on malformed input.
pub fn parseDuration(s: []const u8) !u64 {
    if (s.len == 0) return error.InvalidValue;

    var total: u64 = 0;
    var i: usize = 0;
    var found_any: bool = false;

    while (i < s.len) {
        // Collect digits
        const num_start = i;
        while (i < s.len and std.ascii.isDigit(s[i])) : (i += 1) {}
        if (i == num_start) return error.InvalidValue; // no digit before unit

        const num = std.fmt.parseInt(u64, s[num_start..i], 10) catch return error.InvalidValue;

        if (i >= s.len) return error.InvalidValue; // digit with no unit
        const unit = s[i];
        i += 1;

        const factor: u64 = switch (unit) {
            'd', 'D' => 86400,
            'h', 'H' => 3600,
            'm', 'M' => 60,
            's', 'S' => 1,
            else => return error.InvalidValue,
        };

        total += num * factor;
        found_any = true;
    }

    if (!found_any) return error.InvalidValue;
    return total;
}

/// Parse a byte-size string into total bytes.
/// Supports: B, KB, MB, GB, TB, PB (case-insensitive), or a plain integer (bytes).
/// Examples: "1GB" → 1073741824, "512MB" → 536870912, "4096" → 4096.
/// Returns error.InvalidValue on malformed input.
pub fn parseByteSize(s: []const u8) !u64 {
    if (s.len == 0) return error.InvalidValue;

    // Find where digits end
    var i: usize = 0;
    while (i < s.len and std.ascii.isDigit(s[i])) : (i += 1) {}

    if (i == 0) return error.InvalidValue;
    const num = std.fmt.parseInt(u64, s[0..i], 10) catch return error.InvalidValue;

    // Rest is the unit suffix (optional)
    const suffix = std.mem.trim(u8, s[i..], " \t");

    if (suffix.len == 0) return num; // plain bytes

    const kb: u64 = 1024;
    const mb: u64 = 1024 * kb;
    const gb: u64 = 1024 * mb;
    const tb: u64 = 1024 * gb;
    const pb: u64 = 1024 * tb;

    const factor: u64 = if (std.ascii.eqlIgnoreCase(suffix, "b"))
        1
    else if (std.ascii.eqlIgnoreCase(suffix, "kb"))
        kb
    else if (std.ascii.eqlIgnoreCase(suffix, "mb"))
        mb
    else if (std.ascii.eqlIgnoreCase(suffix, "gb"))
        gb
    else if (std.ascii.eqlIgnoreCase(suffix, "tb"))
        tb
    else if (std.ascii.eqlIgnoreCase(suffix, "pb"))
        pb
    else
        return error.InvalidValue;

    return num * factor;
}

/// Check whether `s` is a valid duration string.
pub fn validateDurationStr(s: []const u8) bool {
    parseDuration(s) catch return false;
    return true;
}

/// Check whether `s` is a valid byte-size string.
pub fn validateByteSizeStr(s: []const u8) bool {
    parseByteSize(s) catch return false;
    return true;
}

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
    try std.testing.expectEqual(@as(?bool, true), parseBool("True"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("TRUE"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("yes"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("Yes"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("YES"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("1"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("on"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("On"));
    try std.testing.expectEqual(@as(?bool, true), parseBool("ON"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("false"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("False"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("FALSE"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("no"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("No"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("NO"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("0"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("off"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("Off"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("OFF"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("maybe"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("invalid"));
    try std.testing.expectEqual(@as(?bool, null), parseBool(""));
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
        Validators.charRange(3, 32),
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

test "validateHexColor" {
    try std.testing.expect(validateHexColor("#FF5733"));
    try std.testing.expect(validateHexColor("#fff"));
    try std.testing.expect(validateHexColor("#FF5733AA"));
    try std.testing.expect(validateHexColor("#1234"));
    try std.testing.expect(!validateHexColor("FF5733"));
    try std.testing.expect(!validateHexColor("#GGG"));
    try std.testing.expect(!validateHexColor("#12345"));
}

test "validateSemver" {
    try std.testing.expect(validateSemver("1.2.3"));
    try std.testing.expect(validateSemver("0.0.1"));
    try std.testing.expect(validateSemver("10.20.30"));
    try std.testing.expect(validateSemver("1.2.3-beta.1"));
    try std.testing.expect(validateSemver("1.2.3+build.42"));
    try std.testing.expect(validateSemver("1.2.3-rc.1+build.42"));
    try std.testing.expect(!validateSemver("1.2"));
    try std.testing.expect(!validateSemver("1.2.3.4"));
    try std.testing.expect(!validateSemver("abc.def.ghi"));
    try std.testing.expect(!validateSemver(""));
}

test "validateBase64" {
    try std.testing.expect(validateBase64("dGVzdA=="));
    try std.testing.expect(validateBase64("aGVsbG8="));
    try std.testing.expect(!validateBase64(""));
    try std.testing.expect(!validateBase64("!!!invalid"));
}

test "validateMacAddress" {
    try std.testing.expect(validateMacAddress("00:1A:2B:3C:4D:5E"));
    try std.testing.expect(validateMacAddress("AA-BB-CC-DD-EE-FF"));
    try std.testing.expect(!validateMacAddress("00:1A:2B:3C:4D"));
    try std.testing.expect(!validateMacAddress("GG:HH:II:JJ:KK:LL"));
    try std.testing.expect(!validateMacAddress(""));
}

test "validateAsciiOnly" {
    try std.testing.expect(validateAsciiOnly("Hello, World!"));
    try std.testing.expect(!validateAsciiOnly("Hëllo"));
    try std.testing.expect(validateAsciiOnly(""));
}

test "validateLowercase" {
    try std.testing.expect(validateLowercase("hello"));
    try std.testing.expect(!validateLowercase("Hello"));
    try std.testing.expect(!validateLowercase("HELLO"));
}

test "validateUppercase" {
    try std.testing.expect(validateUppercase("HELLO"));
    try std.testing.expect(!validateUppercase("Hello"));
    try std.testing.expect(!validateUppercase("hello"));
}

test "Validators hexColor and semver" {
    try std.testing.expect(Validators.hexColor(std.Io.failing, "#FF5733").isOk());
    try std.testing.expect(!Validators.hexColor(std.Io.failing, "not-a-color").isOk());

    try std.testing.expect(Validators.semver(std.Io.failing, "1.2.3").isOk());
    try std.testing.expect(!Validators.semver(std.Io.failing, "not-semver").isOk());
}

test "Validators base64, macAddress, asciiOnly, lowercase, uppercase" {
    try std.testing.expect(Validators.base64(std.Io.failing, "dGVzdA==").isOk());
    try std.testing.expect(!Validators.base64(std.Io.failing, "!!!").isOk());

    try std.testing.expect(Validators.macAddress(std.Io.failing, "00:1A:2B:3C:4D:5E").isOk());
    try std.testing.expect(!Validators.macAddress(std.Io.failing, "invalid").isOk());

    try std.testing.expect(Validators.asciiOnly(std.Io.failing, "hello").isOk());
    try std.testing.expect(!Validators.asciiOnly(std.Io.failing, "hëllo").isOk());

    try std.testing.expect(Validators.lowercase(std.Io.failing, "hello").isOk());
    try std.testing.expect(!Validators.lowercase(std.Io.failing, "Hello").isOk());

    try std.testing.expect(Validators.uppercase(std.Io.failing, "HELLO").isOk());
    try std.testing.expect(!Validators.uppercase(std.Io.failing, "Hello").isOk());
}
