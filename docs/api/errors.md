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

Prompt selection helpers may also return:

| Error | Description |
|-------|-------------|
| `InvalidConfig` | Prompt configuration is inconsistent |
| `InvalidChoice` | Prompt answer did not match allowed choices |
| `InvalidValue` | Prompt attempts exceeded without valid input |
| `EndOfStream` | Input stream ended before a valid answer |

Strict include/exclude helpers may also return:

| Error | Description |
|-------|-------------|
| `IncludeExcludeConflict` | Same value appeared in both include and exclude sets when conflict checks are enabled |

## Error Handling

### Duplicate Option Behavior

Singleton options (for example standard `store` options and most typed helpers) now return `DuplicateArgument` when provided multiple times.

Repeatable actions such as `count`, `append`, `extend`, and `callback_flag` continue to allow multiple occurrences.

```zig
const argv = [_][]const u8{ "--email", "a@example.com", "--email", "b@example.com" };
_ = parser.parse(&argv) catch |err| {
    if (err == error.DuplicateArgument) {
        std.debug.print("Error: duplicate argument\n", .{});
    }
    return;
};
```

### Unknown Option Suggestions

In `strict` mode, unknown long options include a "Did you mean" suggestion when a close match exists.

Built-in command options (`--help`, `--version`) are also included in suggestion candidates.

Unknown subcommands also use closest-match suggestions when the command declares subcommands and no first positional argument is defined.

Suggestion behavior is configurable through `Config`:

- `suggest_closest`
- `suggestion_max_distance`
- `suggest_builtin_commands`
- `suggest_subcommands`
- `error_prefix`
- `warning_prefix`
- `unknown_option_hint`
- `unknown_subcommand_hint`
- `unknown_option_message`
- `unknown_subcommand_message`

For value errors, you can provide option-level customization with:

- `suggestion_hint` (display a custom hint)
- `custom_error_message` (override default validation message)

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

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addOption("output", .{ .short = 'o', .required = true });

    var result = parser.parseProcess(init) catch |err| {
        const msg = args.errors.formatParseError(err);
        std.debug.print("Error: {s}\n\n", .{msg});
        try parser.printHelp();
        std.process.exit(1);
    };
    defer result.deinit();

    // Process result...
}
```
