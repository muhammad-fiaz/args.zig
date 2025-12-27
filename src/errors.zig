//! Error types and handling for args.zig.

const std = @import("std");

/// Errors that occur during argument parsing.
pub const ParseError = error{
    UnknownOption,
    MissingRequired,
    MissingValue,
    InvalidValue,
    TooManyValues,
    TooFewValues,
    InvalidChoice,
    ConflictingArguments,
    MissingDependency,
    DuplicateArgument,
    InvalidFormat,
    UnexpectedPositional,
    UnknownSubcommand,
    MissingSubcommand,
    MutuallyExclusive,
    OutOfMemory,
    Overflow,
    InvalidCharacter,
};

/// Errors that occur during schema definition.
pub const SchemaError = error{
    DuplicateName,
    DuplicateAlias,
    InvalidConfig,
    PositionalAfterVariadic,
    RequiredAfterOptional,
    InvalidNargs,
    InvalidDefault,
    InvalidChoices,
    CircularDependency,
    SelfConflict,
    OutOfMemory,
};

/// Errors that occur during value validation.
pub const ValidationError = error{
    OutOfRange,
    TooShort,
    TooLong,
    PatternMismatch,
    CustomValidationFailed,
    FileNotFound,
    DirectoryNotFound,
    PermissionDenied,
    InvalidPath,
};

/// Context information for error reporting.
pub const ErrorContext = struct {
    argument: ?[]const u8 = null,
    value: ?[]const u8 = null,
    expected: ?[]const u8 = null,
    position: ?usize = null,
    message: ?[]const u8 = null,
    suggestion: ?[]const u8 = null,

    pub fn format(self: ErrorContext, allocator: std.mem.Allocator) ![]const u8 {
        var result: std.ArrayListUnmanaged(u8) = .empty;
        errdefer result.deinit(allocator);
        const writer = result.writer(allocator);

        if (self.argument) |arg| try writer.print("argument '{s}': ", .{arg});
        if (self.message) |msg| try writer.writeAll(msg);
        if (self.value) |val| try writer.print(" (got '{s}')", .{val});
        if (self.expected) |exp| try writer.print(" (expected {s})", .{exp});
        if (self.suggestion) |sug| try writer.print("\n  Did you mean '{s}'?", .{sug});

        return result.toOwnedSlice(allocator);
    }
};

const utils = @import("utils.zig");

/// Calculate Levenshtein distance between two strings for suggestions (delegates to utils).
pub const levenshteinDistance = utils.editDistance;

/// Find the closest match from a list of candidates (delegates to utils).
pub const findClosestMatch = utils.findClosest;

/// Format a parse error for display.
pub fn formatParseError(err: ParseError) []const u8 {
    return switch (err) {
        ParseError.UnknownOption => "unknown option",
        ParseError.MissingRequired => "missing required argument",
        ParseError.MissingValue => "missing value for option",
        ParseError.InvalidValue => "invalid value",
        ParseError.TooManyValues => "too many values provided",
        ParseError.TooFewValues => "too few values provided",
        ParseError.InvalidChoice => "invalid choice",
        ParseError.ConflictingArguments => "conflicting arguments",
        ParseError.MissingDependency => "missing required dependency",
        ParseError.DuplicateArgument => "duplicate argument",
        ParseError.InvalidFormat => "invalid argument format",
        ParseError.UnexpectedPositional => "unexpected positional argument",
        ParseError.UnknownSubcommand => "unknown subcommand",
        ParseError.MissingSubcommand => "missing subcommand",
        ParseError.MutuallyExclusive => "mutually exclusive arguments used together",
        ParseError.OutOfMemory => "out of memory",
        ParseError.Overflow => "numeric overflow",
        ParseError.InvalidCharacter => "invalid character in value",
    };
}

test "levenshteinDistance" {
    try std.testing.expectEqual(@as(usize, 0), levenshteinDistance("hello", "hello"));
    try std.testing.expectEqual(@as(usize, 1), levenshteinDistance("hello", "hallo"));
    try std.testing.expectEqual(@as(usize, 3), levenshteinDistance("kitten", "sitting"));
    try std.testing.expectEqual(@as(usize, 5), levenshteinDistance("", "hello"));
}

test "findClosestMatch" {
    const candidates = [_][]const u8{ "verbose", "version", "help", "output" };
    try std.testing.expectEqualStrings("verbose", findClosestMatch("verbos", &candidates, 2).?);
    try std.testing.expectEqualStrings("version", findClosestMatch("versio", &candidates, 2).?);
    try std.testing.expectEqual(@as(?[]const u8, null), findClosestMatch("xyz", &candidates, 2));
}

test "ErrorContext.format" {
    const allocator = std.testing.allocator;

    const ctx = ErrorContext{
        .argument = "output",
        .message = "file not found",
        .value = "/invalid/path",
    };

    const formatted = try ctx.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "output") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "file not found") != null);
}

test "formatParseError" {
    try std.testing.expectEqualStrings("unknown option", formatParseError(ParseError.UnknownOption));
    try std.testing.expectEqualStrings("missing required argument", formatParseError(ParseError.MissingRequired));
}
