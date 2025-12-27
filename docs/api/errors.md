---
title: Errors Reference
description: Complete reference for all error types in args.zig including ParseError, SchemaError, and ValidationError.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, errors, error handling, ParseError, ValidationError, api reference
---

# Errors Reference

This document covers all error types in args.zig.

## ParseError

Errors that occur during argument parsing:

| Error | Description |
|-------|-------------|
| `UnknownOption` | Option not defined in schema |
| `MissingRequired` | Required argument not provided |
| `MissingValue` | Option requires a value but none given |
| `InvalidValue` | Value cannot be parsed as expected type |
| `TooManyValues` | More values than nargs allows |
| `TooFewValues` | Fewer values than nargs requires |
| `InvalidChoice` | Value not in allowed choices |
| `ConflictingArguments` | Mutually exclusive arguments used together |
| `MissingDependency` | Required dependency argument not provided |
| `DuplicateArgument` | Same argument specified multiple times |
| `InvalidFormat` | Argument format is malformed |
| `UnexpectedPositional` | Positional argument in unexpected position |
| `UnknownSubcommand` | Subcommand not defined |
| `MissingSubcommand` | Required subcommand not provided |
| `MutuallyExclusive` | Options that cannot be used together |
| `OutOfMemory` | Memory allocation failed |
| `Overflow` | Numeric value too large |
| `InvalidCharacter` | Invalid character in value |

## SchemaError

Errors that occur during schema definition:

| Error | Description |
|-------|-------------|
| `DuplicateName` | Argument name already used |
| `DuplicateAlias` | Short/long option already used |
| `InvalidConfig` | Invalid configuration value |
| `PositionalAfterVariadic` | Positional after variable-length arg |
| `RequiredAfterOptional` | Required positional after optional |
| `InvalidNargs` | Invalid nargs specification |
| `InvalidDefault` | Default value doesn't match type |
| `InvalidChoices` | Choices don't match value type |
| `CircularDependency` | Dependency creates a cycle |
| `SelfConflict` | Argument conflicts with itself |

## ValidationError

Errors that occur during value validation:

| Error | Description |
|-------|-------------|
| `OutOfRange` | Value outside allowed range |
| `TooShort` | String shorter than minimum length |
| `TooLong` | String longer than maximum length |
| `PatternMismatch` | Value doesn't match required pattern |
| `CustomValidationFailed` | Custom validator returned error |
| `FileNotFound` | Path doesn't exist |
| `DirectoryNotFound` | Directory doesn't exist |
| `PermissionDenied` | Insufficient permissions |
| `InvalidPath` | Invalid path format |

## Error Handling

### Basic Error Handling

```zig
var result = parser.parse(&args) catch |err| {
    switch (err) {
        error.MissingRequired => {
            std.debug.print("Error: Missing required argument\n", .{});
            try parser.printHelp();
        },
        error.UnknownOption => {
            std.debug.print("Error: Unknown option\n", .{});
        },
        else => {
            std.debug.print("Error: {any}\n", .{err});
        },
    }
    return;
};
```

### Getting Error Messages

```zig
const errors = @import("args").errors;

const message = errors.formatParseError(error.MissingRequired);
std.debug.print("{s}\n", .{message});
// Output: "missing required argument"
```

### Error Context

```zig
const ctx = errors.ErrorContext{
    .argument = "output",
    .message = "file not found",
    .value = "/invalid/path",
    .suggestion = "output.txt",
};

const formatted = try ctx.format(allocator);
defer allocator.free(formatted);
std.debug.print("{s}\n", .{formatted});
// Output: argument 'output': file not found (got '/invalid/path')
//         Did you mean 'output.txt'?
```

## Suggestion System

args.zig includes a Levenshtein distance-based suggestion system:

```zig
const candidates = [_][]const u8{ "verbose", "version", "help" };
const suggestion = errors.findClosestMatch("verbos", &candidates, 2);
// Returns: "verbose"
```

## Exit on Error

By default, the parser exits on errors. Disable this for custom handling:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .exit_on_error = false },
});
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addOption("output", .{ .short = 'o', .required = true });

    var result = parser.parseProcess() catch |err| {
        const msg = args.errors.formatParseError(err);
        std.debug.print("Error: {s}\n\n", .{msg});
        try parser.printHelp();
        std.process.exit(1);
    };
    defer result.deinit();

    // Process result...
}
```
