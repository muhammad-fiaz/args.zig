//! Core type definitions for args.zig argument parsing.

const std = @import("std");
const constants = @import("constants.zig");
const utils = @import("utils.zig");

/// Represents all possible value types for command-line arguments.
pub const ValueType = enum {
    string,
    int,
    uint,
    float,
    bool,
    path,
    choice,
    array,
    counter,
    custom,
    key_value,
    /// Duration value — stored as u64 seconds (parsed from strings like "1h30m", "45s").
    duration,
    /// Byte size value — stored as u64 bytes (parsed from strings like "1GB", "512MB").
    byte_size,

    /// Get the default value as a string for this type.
    pub fn defaultAsString(self: ValueType) []const u8 {
        return switch (self) {
            .string => constants.TypeNames.default_string,
            .int => constants.TypeNames.default_int,
            .uint => constants.TypeNames.default_int,
            .float => constants.TypeNames.default_float,
            .bool => constants.TypeNames.default_bool,
            .path => constants.TypeNames.default_string,
            .choice => constants.TypeNames.default_string,
            .array => constants.TypeNames.default_array,
            .counter => constants.TypeNames.default_int,
            .custom => constants.TypeNames.default_string,
            .key_value => constants.TypeNames.default_string,
            .duration => constants.TypeNames.default_duration,
            .byte_size => constants.TypeNames.default_size,
        };
    }

    /// Get the type name for help text.
    pub fn typeName(self: ValueType) []const u8 {
        return switch (self) {
            .string => constants.TypeNames.string,
            .int => constants.TypeNames.int,
            .uint => constants.TypeNames.uint,
            .float => constants.TypeNames.float,
            .bool => constants.TypeNames.bool_name,
            .path => constants.TypeNames.path,
            .choice => constants.TypeNames.choice,
            .array => constants.TypeNames.array,
            .counter => constants.TypeNames.counter,
            .custom => constants.TypeNames.custom,
            .key_value => constants.TypeNames.key_value,
            .duration => constants.TypeNames.duration,
            .byte_size => constants.TypeNames.byte_size,
        };
    }

    /// Check if this type is numeric.
    pub fn isNumeric(self: ValueType) bool {
        return switch (self) {
            .int, .uint, .float, .counter, .duration, .byte_size => true,
            else => false,
        };
    }
};

/// Actions performed when an argument is encountered.
pub const ArgAction = enum {
    store,
    store_true,
    store_false,
    append,
    count,
    help,
    version,
    callback,
    callback_flag,
    extend,

    /// Check if this action requires a value.
    pub fn requiresValue(self: ArgAction) bool {
        return switch (self) {
            .store, .append, .extend, .callback => true,
            .store_true, .store_false, .count, .help, .version, .callback_flag => false,
        };
    }

    /// Check if this action is a boolean flag.
    pub fn isFlag(self: ArgAction) bool {
        return switch (self) {
            .store_true, .store_false, .count => true,
            else => false,
        };
    }
};

/// Controls optional decode/decryption processing for incoming string values.
pub const DecodeMode = enum {
    none,
    base64_std,
    base64_url_safe,
    hex,
};

/// Specifies how many values an argument accepts.
pub const Nargs = union(enum) {
    exact: usize,
    optional,
    zero_or_more,
    one_or_more,
    remainder,

    /// Get minimum required count.
    pub fn minCount(self: Nargs) usize {
        return switch (self) {
            .exact => |n| n,
            .optional, .zero_or_more => 0,
            .one_or_more => 1,
            .remainder => 0,
        };
    }

    /// Get maximum allowed count (null = unlimited).
    pub fn maxCount(self: Nargs) ?usize {
        return switch (self) {
            .exact => |n| n,
            .optional => 1,
            .zero_or_more, .one_or_more, .remainder => null,
        };
    }

    /// Check if the given count satisfies this nargs requirement.
    pub fn isSatisfied(self: Nargs, count: usize) bool {
        const min = self.minCount();
        const max = self.maxCount();
        if (count < min) return false;
        if (max) |m| {
            if (count > m) return false;
        }
        return true;
    }

    /// Check if this nargs is variadic (accepts variable number of arguments).
    pub fn isVariadic(self: Nargs) bool {
        return switch (self) {
            .zero_or_more, .one_or_more, .remainder => true,
            else => false,
        };
    }
};

/// Bracket type used for value grouping in bracket-delimited arguments.
pub const BracketType = enum {
    /// Parentheses: (value1, value2)
    parentheses,
    /// Square brackets: [value1, value2]
    square,
    /// Curly braces: {value1, value2}
    curly,
    /// Angle brackets: <value1, value2>
    angle,
    /// No bracket grouping
    none,

    /// Detect bracket type from the first character of a string.
    pub fn detect(first: u8) BracketType {
        return switch (first) {
            '(' => .parentheses,
            '[' => .square,
            '{' => .curly,
            '<' => .angle,
            else => .none,
        };
    }

    /// Get the closing bracket character for this type.
    pub fn closing(self: BracketType) ?u8 {
        return switch (self) {
            .parentheses => ')',
            .square => ']',
            .curly => '}',
            .angle => '>',
            .none => null,
        };
    }
};

/// Key-Value pair structure.
pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};

/// Represents a parsed argument value.
pub const ParsedValue = union(enum) {
    string: []const u8,
    int: i64,
    uint: u64,
    float: f64,
    boolean: bool,
    array: []const []const u8,
    counter: u32,
    key_value: KeyValue,
    none: void,

    /// Check if this value is set (not none).
    pub fn isSet(self: ParsedValue) bool {
        return self != .none;
    }

    /// Try to get as integer.
    pub fn asInt(self: ParsedValue) ?i64 {
        return switch (self) {
            .int => |i| i,
            .uint => |u| if (u <= std.math.maxInt(i64)) @intCast(u) else null,
            .counter => |c| @intCast(c),
            else => null,
        };
    }

    /// Try to get as unsigned integer.
    pub fn asUint(self: ParsedValue) ?u64 {
        return switch (self) {
            .uint => |u| u,
            .int => |i| if (i >= 0) @intCast(i) else null,
            .counter => |c| @intCast(c),
            else => null,
        };
    }

    /// Try to get as float.
    pub fn asFloat(self: ParsedValue) ?f64 {
        return switch (self) {
            .float => |f| f,
            .int => |i| @floatFromInt(i),
            .uint => |u| @floatFromInt(u),
            else => null,
        };
    }

    /// Try to get as boolean.
    pub fn asBool(self: ParsedValue) ?bool {
        return switch (self) {
            .boolean => |b| b,
            .counter => |c| c > 0,
            else => null,
        };
    }

    /// Try to get as string.
    pub fn asString(self: ParsedValue) ?[]const u8 {
        return switch (self) {
            .string => |s| s,
            else => null,
        };
    }

    /// Try to get as key-value pair.
    pub fn asKeyValue(self: ParsedValue) ?KeyValue {
        return switch (self) {
            .key_value => |kv| kv,
            else => null,
        };
    }
};

/// Controls how the parser handles unknown arguments.
pub const ParsingMode = enum {
    strict,
    permissive,
    ignore_unknown,
    interspersed,
};

/// Result of parsing command-line arguments.
pub const ParseResult = struct {
    values: std.StringHashMap(ParsedValue),
    positionals: std.ArrayList([]const u8),
    remaining: std.ArrayList([]const u8),
    owned_slices: std.ArrayList([]const u8),
    subcommand: ?[]const u8,
    subcommand_args: ?*ParseResult,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ParseResult {
        return .{
            .values = std.StringHashMap(ParsedValue).init(allocator),
            .positionals = .empty,
            .remaining = .empty,
            .owned_slices = .empty,
            .subcommand = null,
            .subcommand_args = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ParseResult) void {
        for (self.owned_slices.items) |slice| {
            self.allocator.free(slice);
        }
        self.owned_slices.deinit(self.allocator);

        self.values.deinit();
        self.positionals.deinit(self.allocator);
        self.remaining.deinit(self.allocator);

        if (self.subcommand_args) |sub| {
            sub.deinit();
            self.allocator.destroy(sub);
        }
    }

    /// Registers a slice as owned by this parse result.
    pub fn ownSlice(self: *ParseResult, slice: []const u8) !void {
        try self.owned_slices.append(self.allocator, slice);
    }

    /// Inserts or replaces a parsed value.
    pub fn put(self: *ParseResult, name: []const u8, value: ParsedValue) !void {
        try self.values.put(name, value);
    }

    /// Get a value by name.
    pub fn get(self: *const ParseResult, name: []const u8) ?ParsedValue {
        return self.values.get(name);
    }

    /// Get a string value by name.
    pub fn getString(self: *const ParseResult, name: []const u8) ?[]const u8 {
        const val = self.values.get(name) orelse return null;
        return val.asString();
    }

    /// Get an integer value by name.
    pub fn getInt(self: *const ParseResult, name: []const u8) ?i64 {
        const val = self.values.get(name) orelse return null;
        return val.asInt();
    }

    /// Get a boolean value by name.
    pub fn getBool(self: *const ParseResult, name: []const u8) ?bool {
        const val = self.values.get(name) orelse return null;
        return val.asBool();
    }

    /// Get a float value by name.
    pub fn getFloat(self: *const ParseResult, name: []const u8) ?f64 {
        const val = self.values.get(name) orelse return null;
        return val.asFloat();
    }

    /// Get an unsigned integer value by name.
    pub fn getUint(self: *const ParseResult, name: []const u8) ?u64 {
        const val = self.values.get(name) orelse return null;
        return val.asUint();
    }

    /// Get a key-value pair by name.
    pub fn getKeyValue(self: *const ParseResult, name: []const u8) ?KeyValue {
        const val = self.values.get(name) orelse return null;
        return val.asKeyValue();
    }

    /// Get an array value by name.
    pub fn getArray(self: *const ParseResult, name: []const u8) ?[]const []const u8 {
        const val = self.values.get(name) orelse return null;
        return switch (val) {
            .array => |a| a,
            else => null,
        };
    }

    /// Get an enum value by name, converting the string value to the given enum type.
    pub fn getEnum(self: *const ParseResult, comptime T: type, name: []const u8) ?T {
        const str = self.getString(name) orelse return null;
        inline for (@typeInfo(T).@"enum".fields) |field| {
            if (utils.eql(str, field.name)) return @field(T, field.name);
        }
        return null;
    }

    /// Get a string value with a default fallback.
    pub fn getOrString(self: *const ParseResult, name: []const u8, default: []const u8) []const u8 {
        return self.getString(name) orelse default;
    }

    /// Get an integer value with a default fallback.
    pub fn getOrInt(self: *const ParseResult, name: []const u8, default: i64) i64 {
        return self.getInt(name) orelse default;
    }

    /// Get a boolean value with a default fallback.
    pub fn getOrBool(self: *const ParseResult, name: []const u8, default: bool) bool {
        return self.getBool(name) orelse default;
    }

    /// Get a float value with a default fallback.
    pub fn getOrFloat(self: *const ParseResult, name: []const u8, default: f64) f64 {
        return self.getFloat(name) orelse default;
    }

    /// Get an unsigned integer value with a default fallback.
    pub fn getOrUint(self: *const ParseResult, name: []const u8, default: u64) u64 {
        return self.getUint(name) orelse default;
    }

    /// Get a counter value with a default fallback.
    pub fn getOrCounter(self: *const ParseResult, name: []const u8, default: u32) u32 {
        return self.getCounter(name) orelse default;
    }

    /// Get a key-value pair with a default fallback.
    pub fn getOrKeyValue(self: *const ParseResult, name: []const u8, default: KeyValue) KeyValue {
        return self.getKeyValue(name) orelse default;
    }

    /// Check if a value exists.
    pub fn contains(self: *const ParseResult, name: []const u8) bool {
        return self.values.contains(name);
    }

    /// Get count of positional arguments.
    pub fn positionalCount(self: *const ParseResult) usize {
        return self.positionals.items.len;
    }

    /// Get a counter value by name.
    pub fn getCounter(self: *const ParseResult, name: []const u8) ?u32 {
        const val = self.values.get(name) orelse return null;
        return switch (val) {
            .counter => |c| c,
            else => null,
        };
    }

    /// Get a duration value (in seconds) by name.
    pub fn getDuration(self: *const ParseResult, name: []const u8) ?u64 {
        const val = self.values.get(name) orelse return null;
        return switch (val) {
            .uint => |u| u,
            .int => |i| if (i >= 0) @intCast(i) else null,
            else => null,
        };
    }

    /// Get a byte-size value (in bytes) by name.
    pub fn getSize(self: *const ParseResult, name: []const u8) ?u64 {
        const val = self.values.get(name) orelse return null;
        return switch (val) {
            .uint => |u| u,
            .int => |i| if (i >= 0) @intCast(i) else null,
            else => null,
        };
    }

    /// Returns true if a subcommand was matched during parsing.
    pub fn hasSubcommand(self: *const ParseResult) bool {
        return self.subcommand != null;
    }

    /// Returns true if the argument was explicitly provided by the user
    /// (i.e., present in the values map — includes defaults applied at parse time).
    /// Use this when you need to distinguish between user-supplied and absent values.
    pub fn isPresent(self: *const ParseResult, name: []const u8) bool {
        return self.values.contains(name);
    }
};

test "ValueType.defaultAsString" {
    try std.testing.expectEqualStrings("", ValueType.string.defaultAsString());
    try std.testing.expectEqualStrings("0", ValueType.int.defaultAsString());
    try std.testing.expectEqualStrings("false", ValueType.bool.defaultAsString());
    try std.testing.expectEqualStrings("0.0", ValueType.float.defaultAsString());
}

test "ValueType.typeName" {
    try std.testing.expectEqualStrings("STRING", ValueType.string.typeName());
    try std.testing.expectEqualStrings("INT", ValueType.int.typeName());
    try std.testing.expectEqualStrings("PATH", ValueType.path.typeName());
}

test "ValueType.isNumeric" {
    try std.testing.expect(ValueType.int.isNumeric());
    try std.testing.expect(ValueType.float.isNumeric());
    try std.testing.expect(!ValueType.string.isNumeric());
}

test "ArgAction.requiresValue" {
    try std.testing.expect(ArgAction.store.requiresValue());
    try std.testing.expect(ArgAction.append.requiresValue());
    try std.testing.expect(!ArgAction.store_true.requiresValue());
    try std.testing.expect(!ArgAction.count.requiresValue());
}

test "ArgAction.isFlag" {
    try std.testing.expect(ArgAction.store_true.isFlag());
    try std.testing.expect(ArgAction.count.isFlag());
    try std.testing.expect(!ArgAction.store.isFlag());
}

test "Nargs.minCount and maxCount" {
    const exact: Nargs = .{ .exact = 3 };
    try std.testing.expectEqual(@as(usize, 3), exact.minCount());
    try std.testing.expectEqual(@as(?usize, 3), exact.maxCount());

    const optional: Nargs = .optional;
    try std.testing.expectEqual(@as(usize, 0), optional.minCount());
    try std.testing.expectEqual(@as(?usize, 1), optional.maxCount());

    const one_or_more: Nargs = .one_or_more;
    try std.testing.expectEqual(@as(usize, 1), one_or_more.minCount());
    try std.testing.expectEqual(@as(?usize, null), one_or_more.maxCount());
}

test "Nargs.isSatisfied" {
    const exact: Nargs = .{ .exact = 2 };
    try std.testing.expect(exact.isSatisfied(2));
    try std.testing.expect(!exact.isSatisfied(1));
    try std.testing.expect(!exact.isSatisfied(3));

    const optional: Nargs = .optional;
    try std.testing.expect(optional.isSatisfied(0));
    try std.testing.expect(optional.isSatisfied(1));
    try std.testing.expect(!optional.isSatisfied(2));

    const one_or_more: Nargs = .one_or_more;
    try std.testing.expect(!one_or_more.isSatisfied(0));
    try std.testing.expect(one_or_more.isSatisfied(1));
    try std.testing.expect(one_or_more.isSatisfied(100));
}

test "Nargs.isVariadic" {
    const zom: Nargs = .zero_or_more;
    const oom: Nargs = .one_or_more;
    const rem: Nargs = .remainder;
    const opt: Nargs = .optional;

    try std.testing.expect(zom.isVariadic());
    try std.testing.expect(oom.isVariadic());
    try std.testing.expect(rem.isVariadic());
    try std.testing.expect(!opt.isVariadic());
}

test "ParsedValue.isSet" {
    const str_val = ParsedValue{ .string = "hello" };
    try std.testing.expect(str_val.isSet());

    const none_val = ParsedValue{ .none = {} };
    try std.testing.expect(!none_val.isSet());
}

test "ParsedValue.asInt" {
    const int_val = ParsedValue{ .int = 42 };
    try std.testing.expectEqual(@as(?i64, 42), int_val.asInt());

    const uint_val = ParsedValue{ .uint = 100 };
    try std.testing.expectEqual(@as(?i64, 100), uint_val.asInt());

    const counter_val = ParsedValue{ .counter = 3 };
    try std.testing.expectEqual(@as(?i64, 3), counter_val.asInt());

    const str_val = ParsedValue{ .string = "hello" };
    try std.testing.expectEqual(@as(?i64, null), str_val.asInt());
}

test "ParsedValue.asFloat" {
    const float_val = ParsedValue{ .float = 3.14 };
    try std.testing.expect(@abs(float_val.asFloat().? - 3.14) < 0.001);

    const int_val = ParsedValue{ .int = 42 };
    try std.testing.expectEqual(@as(?f64, 42.0), int_val.asFloat());
}

test "ParsedValue.asBool" {
    const bool_val = ParsedValue{ .boolean = true };
    try std.testing.expectEqual(@as(?bool, true), bool_val.asBool());

    const counter_val = ParsedValue{ .counter = 3 };
    try std.testing.expectEqual(@as(?bool, true), counter_val.asBool());

    const zero_counter = ParsedValue{ .counter = 0 };
    try std.testing.expectEqual(@as(?bool, false), zero_counter.asBool());
}

test "ParsedValue.asString" {
    const str_val = ParsedValue{ .string = "hello" };
    try std.testing.expectEqualStrings("hello", str_val.asString().?);

    const int_val = ParsedValue{ .int = 42 };
    try std.testing.expectEqual(@as(?[]const u8, null), int_val.asString());
}

test "ParseResult.init and deinit" {
    var result = ParseResult.init(std.testing.allocator);
    defer result.deinit();

    try result.values.put("test", ParsedValue{ .string = "value" });
    try std.testing.expectEqualStrings("value", result.getString("test").?);
}

test "ParseResult.get methods" {
    var result = ParseResult.init(std.testing.allocator);
    defer result.deinit();

    try result.values.put("str", ParsedValue{ .string = "hello" });
    try result.values.put("num", ParsedValue{ .int = 42 });
    try result.values.put("flag", ParsedValue{ .boolean = true });
    try result.values.put("rate", ParsedValue{ .float = 3.14 });

    try std.testing.expectEqualStrings("hello", result.getString("str").?);
    try std.testing.expectEqual(@as(?i64, 42), result.getInt("num"));
    try std.testing.expectEqual(@as(?bool, true), result.getBool("flag"));
    try std.testing.expect(@abs(result.getFloat("rate").? - 3.14) < 0.001);
    try std.testing.expect(result.contains("str"));
    try std.testing.expect(!result.contains("nonexistent"));
}

test "ParseResult.getUint and getArray" {
    var result = ParseResult.init(std.testing.allocator);
    defer result.deinit();

    try result.values.put("uid", ParsedValue{ .uint = 42 });
    try result.values.put("str", ParsedValue{ .string = "debug" });
    try result.values.put("arr", ParsedValue{ .array = &.{ "a", "b", "c" } });

    try std.testing.expectEqual(@as(?u64, 42), result.getUint("uid"));
    try std.testing.expectEqual(@as(?u64, null), result.getUint("str"));

    const arr = result.getArray("arr").?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
    try std.testing.expectEqualStrings("a", arr[0]);
}

test "ParseResult.getOr* methods" {
    var result = ParseResult.init(std.testing.allocator);
    defer result.deinit();

    try result.values.put("str", ParsedValue{ .string = "hello" });
    try result.values.put("num", ParsedValue{ .int = 42 });
    try result.values.put("flag", ParsedValue{ .boolean = true });
    try result.values.put("rate", ParsedValue{ .float = 3.14 });
    try result.values.put("uid", ParsedValue{ .uint = 100 });

    try std.testing.expectEqualStrings("hello", result.getOrString("str", "default"));
    try std.testing.expectEqualStrings("default", result.getOrString("missing", "default"));

    try std.testing.expectEqual(@as(i64, 42), result.getOrInt("num", 0));
    try std.testing.expectEqual(@as(i64, -1), result.getOrInt("missing", -1));

    try std.testing.expectEqual(true, result.getOrBool("flag", false));
    try std.testing.expectEqual(false, result.getOrBool("missing", false));

    try std.testing.expect(@abs(result.getOrFloat("rate", 0.0) - 3.14) < 0.001);
    try std.testing.expect(@abs(result.getOrFloat("missing", 1.5) - 1.5) < 0.001);

    try std.testing.expectEqual(@as(u64, 100), result.getOrUint("uid", 0));
    try std.testing.expectEqual(@as(u64, 42), result.getOrUint("missing", 42));
}

test "ParseResult.positionalCount" {
    var result = ParseResult.init(std.testing.allocator);
    defer result.deinit();

    try result.positionals.append(std.testing.allocator, "file1.txt");
    try result.positionals.append(std.testing.allocator, "file2.txt");

    try std.testing.expectEqual(@as(usize, 2), result.positionalCount());
}
