---
title: Parser API
description: Complete API reference for the ArgumentParser struct in args.zig. Methods for adding arguments, parsing, and generating help.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, api, ArgumentParser, parser, reference
---

# Parser API Reference

The `ArgumentParser` is the main interface for defining and parsing command-line arguments.

## Creating a Parser

### `ArgumentParser.init`

```zig
pub fn init(allocator: std.mem.Allocator, options: InitOptions) !ArgumentParser
```

Creates a new argument parser.

**Parameters:**
- `allocator` - Memory allocator for internal data structures
- `options` - Initialization options

**InitOptions:**
```zig
pub const InitOptions = struct {
    name: []const u8,                    // Program name (required)
    version: ?[]const u8 = null,         // Version string
    description: ?[]const u8 = null,     // Program description
    epilog: ?[]const u8 = null,          // Text after help
    add_help: bool = true,               // Add --help flag
    add_version: bool = true,            // Add --version flag
    config: ?Config = null,              // Parser configuration
};
```

**Example:**
```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .version = "1.0.0",
    .description = "My application",
});
defer parser.deinit();
```

### `ArgumentParser.deinit`

```zig
pub fn deinit(self: *ArgumentParser) void
```

Releases all resources used by the parser.

## Adding Arguments

### `addFlag`

```zig
pub fn addFlag(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    hidden: bool = false,
    deprecated: ?[]const u8 = null,
}) !void
```

Adds a boolean flag (e.g., `--verbose`, `-v`).

**Example:**
```zig
try parser.addFlag("verbose", .{
    .short = 'v',
    .help = "Enable verbose output",
});
```

### `addOption`

```zig
pub fn addOption(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
    default: ?[]const u8 = null,
    required: bool = false,
    choices: []const []const u8 = &.{},
    metavar: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    hidden: bool = false,
    deprecated: ?[]const u8 = null,
}) !void
```

Adds an option that takes a value.

**Example:**
```zig
try parser.addOption("output", .{
    .short = 'o',
    .help = "Output file",
    .default = "output.txt",
});
```

### `addPositional`

```zig
pub fn addPositional(self: *ArgumentParser, name: []const u8, options: struct {
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
    required: bool = true,
    default: ?[]const u8 = null,
    nargs: Nargs = .{ .exact = 1 },
    metavar: ?[]const u8 = null,
}) !void
```

Adds a positional argument.

**Example:**
```zig
try parser.addPositional("input", .{
    .help = "Input file",
    .required = true,
});
```

### `addCounter`

```zig
pub fn addCounter(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    dest: ?[]const u8 = null,
}) !void
```

Adds a counter argument (increments each time it's used).

**Example:**
```zig
try parser.addCounter("verbose", .{
    .short = 'v',
    .help = "Increase verbosity",
});
```

### `addSubcommand`

```zig
pub fn addSubcommand(self: *ArgumentParser, spec: SubcommandSpec) !void
```

Adds a subcommand with its own arguments.

**Example:**
```zig
try parser.addSubcommand(.{
    .name = "init",
    .help = "Initialize project",
    .args = &[_]args.ArgSpec{
        .{ .name = "name", .positional = true, .required = true },
    },
});
```

### `addArg`

```zig
pub fn addArg(self: *ArgumentParser, spec: ArgSpec) !void
```

Adds an argument with full specification.

### `addRequired`

```zig
pub fn addRequired(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
    metavar: ?[]const u8 = null,
}) !void
```

Shorthand for adding a required option.

**Example:**
```zig
try parser.addRequired("config", .{
    .short = 'c',
    .help = "Configuration file (required)",
});
```

### `addHiddenFlag`

```zig
pub fn addHiddenFlag(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    dest: ?[]const u8 = null,
}) !void
```

Adds a hidden flag that won't appear in help text.

### `addDeprecated`

```zig
pub fn addDeprecated(self: *ArgumentParser, name: []const u8, warning: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
}) !void
```

Adds a deprecated option with a warning message.

**Example:**
```zig
try parser.addDeprecated("old-format", "Use --format instead", .{});
```

### `fromEnvOrDefault`

```zig
pub fn fromEnvOrDefault(
    self: *ArgumentParser,
    name: []const u8,
    env_var: []const u8,
    default_value: []const u8,
    options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
    },
) !void
```

Adds an option with environment variable fallback and programmatic default.

**Example:**
```zig
try parser.fromEnvOrDefault("token", "API_TOKEN", "default-token", .{
    .help = "API authentication token",
});
```

### `addAppend`

```zig
pub fn addAppend(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    metavar: ?[]const u8 = null,
    dest: ?[]const u8 = null,
}) !void
```

Adds an option that appends values to an array.

**Example:**
```zig
try parser.addAppend("include", .{
    .short = 'I',
    .help = "Include path (can be repeated)",
});
```

### `addMultiple`

```zig
pub fn addMultiple(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    min: usize = 1,
    max: ?usize = null,
    metavar: ?[]const u8 = null,
}) !void
```

Adds an option that accepts multiple values (e.g. `--numbers 1 2 3`).

**Example:**
```zig
try parser.addMultiple("numbers", .{
    .short = 'n',
    .min = 1,
    .max = 3,
});
```

### `setGroup`

```zig
pub fn setGroup(self: *ArgumentParser, group_name: []const u8) void
```

Sets the argument group for subsequent arguments (used for help organization).

**Example:**
```zig
parser.setGroup("Advanced Options");
try parser.addFlag("verbose", .{});
```

## Utility Methods

### `hasArg`

```zig
pub fn hasArg(self: *ArgumentParser, name: []const u8) bool
```

Checks if an argument with the given name exists.

### `argCount`

```zig
pub fn argCount(self: *ArgumentParser) usize
```

Returns the number of defined arguments.

### `subcommandCount`

```zig
pub fn subcommandCount(self: *ArgumentParser) usize
```

Returns the number of defined subcommands.

### `printVersion`

```zig
pub fn printVersion(self: *ArgumentParser) void
```

Prints the program version to stdout.

## Parsing

### `parse`

```zig
pub fn parse(self: *ArgumentParser, args_slice: []const []const u8) !ParseResult
```

Parses the provided argument slice.

**Example:**
```zig
const argv = [_][]const u8{ "-v", "--output", "file.txt" };
var result = try parser.parse(&argv);
defer result.deinit();
```

### `parseProcess`

```zig
pub fn parseProcess(self: *ArgumentParser) !ParseResult
```

Parses arguments from the current process.

**Example:**
```zig
var result = try parser.parseProcess();
defer result.deinit();
```

## Help and Completion

### `getHelp`

```zig
pub fn getHelp(self: *ArgumentParser) ![]const u8
```

Generates help text as a string.

### `printHelp`

```zig
pub fn printHelp(self: *ArgumentParser) !void
```

Prints help text to stdout.

### `getUsage`

```zig
pub fn getUsage(self: *ArgumentParser) ![]const u8
```

Generates a short usage string.

### `generateCompletion`

```zig
pub fn generateCompletion(self: *ArgumentParser, shell: Shell) ![]const u8
```

Generates shell completion script.

**Example:**
```zig
const script = try parser.generateCompletion(.bash);
defer allocator.free(script);
```

### `getVersion`

```zig
pub fn getVersion(self: *ArgumentParser) []const u8
```

Returns the parser's version string.

## ParseResult

The result of parsing arguments.

### Fields

```zig
pub const ParseResult = struct {
    values: std.StringHashMap(ParsedValue),
    positionals: std.ArrayListUnmanaged([]const u8),
    remaining: std.ArrayListUnmanaged([]const u8),
    subcommand: ?[]const u8,
    subcommand_args: ?*ParseResult,
    allocator: std.mem.Allocator,
};
```

### Methods

#### `get`

```zig
pub fn get(self: *const ParseResult, name: []const u8) ?ParsedValue
```

Gets a raw parsed value.

#### `getString`

```zig
pub fn getString(self: *const ParseResult, name: []const u8) ?[]const u8
```

Gets a string value.

#### `getInt`

```zig
pub fn getInt(self: *const ParseResult, name: []const u8) ?i64
```

Gets an integer value.

#### `getBool`

```zig
pub fn getBool(self: *const ParseResult, name: []const u8) ?bool
```

Gets a boolean value.

#### `getFloat`

```zig
pub fn getFloat(self: *const ParseResult, name: []const u8) ?f64
```

Gets a float value.

#### `contains`

```zig
pub fn contains(self: *const ParseResult, name: []const u8) bool
```

Checks if a value exists.

#### `deinit`

```zig
pub fn deinit(self: *ParseResult) void
```

Releases resources.

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "example",
        .version = "1.0.0",
        .description = "Example application",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o', .default = "out.txt" });
    try parser.addPositional("input", .{});

    var result = try parser.parseProcess();
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const output = result.getString("output").?;
    const input = result.getString("input").?;

    std.debug.print("Input: {s}, Output: {s}, Verbose: {}\n", .{
        input, output, verbose
    });
}
```
