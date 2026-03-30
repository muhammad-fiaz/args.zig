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

## Parsing Behavior Notes

- Long boolean options support `--no-<name>` when `Config.allow_negated_flags = true` (default).
- Inline values are rejected for flag-style actions (`store_true`, `store_false`, `count`, `help`, `version`).
- When `Config.case_sensitive = false`, long option names and `choices` / `expect` checks are ASCII case-insensitive.

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
    choices: []const []const u8 = &.{},
    expect: []const []const u8 = &.{},
    validator: ?validation.ValidatorFn = null,
    hidden: bool = false,
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

### `addFalseFlag`

```zig
pub fn addFalseFlag(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    hidden: bool = false,
    aliases: []const []const u8 = &.{},
    deprecated: ?[]const u8 = null,
}) !void
```

Adds an inverse boolean flag that stores `false` when present.

**Example:**
```zig
try parser.addFalseFlag("color", .{ .help = "Disable color output" });
```

### `addAllFlag`

```zig
pub fn addAllFlag(self: *ArgumentParser, options: struct {
    name: []const u8 = "all",
    short: ?u8 = null,
    help: ?[]const u8 = "Select all items",
    dest: ?[]const u8 = null,
    hidden: bool = false,
    aliases: []const []const u8 = &.{},
    deprecated: ?[]const u8 = null,
}) !void
```

### `addSelectOption`

```zig
pub fn addSelectOption(self: *ArgumentParser, options: struct {
    name: []const u8 = "select",
    short: ?u8 = null,
    help: ?[]const u8 = "Select specific items",
    value_type: ValueType = .string,
    default: ?[]const u8 = null,
    required: bool = false,
    choices: []const []const u8 = &.{},
    metavar: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    hidden: bool = false,
    aliases: []const []const u8 = &.{},
    deprecated: ?[]const u8 = null,
    validator: ?validation.ValidatorFn = null,
    expect: []const []const u8 = &.{},
}) !void
```

### `addSelectOrAll`

Adds an exclusive helper pair around `--select` and `--all`.

### `addIncludeOption`

Adds a conventional `--include` option for comma-separated filters.

### `addExcludeOption`

Adds a conventional `--exclude` option for comma-separated filters.

### `addIncludeExclude`

Adds both include/exclude options under one group for help organization.

### `PromptSelectOrAllOptions`

```zig
pub const PromptSelectOrAllOptions = struct {
    select_key: []const u8 = "select",
    all_key: []const u8 = "all",
    question: []const u8 = "Choose target",
    choices: []const []const u8,
    default_choice: ?[]const u8 = null,
    allow_all: bool = true,
    case_sensitive: bool = false,
    allow_prefix_match: bool = true,
    suggest_closest: bool = true,
    max_suggestion_distance: usize = 3,
    max_attempts: usize = 3,
};
```

### `PromptSelectOrAllDecision`

```zig
pub const PromptSelectOrAllDecision = union(enum) {
    all: void,
    selected: []const u8,
};
```

### `resolveSelectOrAllWithPrompt`

```zig
pub fn resolveSelectOrAllWithPrompt(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
) !PromptSelectOrAllDecision
```

Uses parsed `--select` / `--all` first. If missing, prompts the user interactively and validates the answer.

### `resolveSelectOrAllWithPromptIO`

```zig
pub fn resolveSelectOrAllWithPromptIO(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    reader: anytype,
    writer: anytype,
) !PromptSelectOrAllDecision
```

Same behavior as `resolveSelectOrAllWithPrompt`, but with custom IO streams for tests and embedded runtimes.

### `parseCsvList`

```zig
pub fn parseCsvList(allocator: std.mem.Allocator, raw: []const u8) ![][]const u8
```

Parses comma-separated values into trimmed non-empty items.

### `deinitCsvList`

```zig
pub fn deinitCsvList(allocator: std.mem.Allocator, items: [][]const u8) void
```

Frees memory returned by `parseCsvList`.

### `IncludeExcludeResolved`

```zig
pub const IncludeExcludeResolved = struct {
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IncludeExcludeResolved) void
};
```

### `IncludeExcludeStrictOptions`

```zig
pub const IncludeExcludeStrictOptions = struct {
    include_key: []const u8 = "include",
    exclude_key: []const u8 = "exclude",
    choices: []const []const u8 = &.{},
    all_keyword: ?[]const u8 = "all",
    case_sensitive: bool = false,
    allow_prefix_match: bool = true,
    dedupe: bool = true,
    fail_on_conflicts: bool = true,
};
```

### `IncludeExcludeStrictResolved`

```zig
pub const IncludeExcludeStrictResolved = struct {
    all: bool,
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IncludeExcludeStrictResolved) void
};
```

### `resolveIncludeExclude`

```zig
pub fn resolveIncludeExclude(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    include_key: []const u8,
    exclude_key: []const u8,
) !IncludeExcludeResolved
```

Parses include/exclude CSV strings from parse results into reusable lists.

### `resolveIncludeExcludeStrict`

```zig
pub fn resolveIncludeExcludeStrict(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: IncludeExcludeStrictOptions,
) !IncludeExcludeStrictResolved
```

Strict resolver for filter workflows with optional choice canonicalization, deduplication, `all` keyword handling, and conflict detection.

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

### `parseInto` (Module-level Function)

```zig
pub fn parseInto(
    allocator: std.mem.Allocator,
    comptime T: type,
    options: ArgumentParser.InitOptions,
    args_slice: ?[]const []const u8,
) !ParseIntoResult(T)
```

Parses command-line arguments directly into a struct type. Derives argument specs from struct fields at compile-time.

**Parameters:**
- `allocator` - Memory allocator
- `T` - The struct type to parse into
- `options` - Parser initialization options
- `args_slice` - Argument slice to parse, or `null` to use process args

**Example:**
```zig
const Config = struct {
    verbose: bool,
    output: ?[]const u8,
    count: i32,
};

var result = try args.parseInto(allocator, Config, .{
    .name = "myapp",
}, null);
defer result.deinit();

std.debug.print("Count: {d}\n", .{result.options.count});
```

## Function Aliases

For convenience, the library provides several aliases:

| Alias | Original Function | Description |
|-------|------------------|-------------|
| `derive` | `parseInto` | Parse args directly into a struct |
| `configure` | `initConfig` | Set global configuration |
| `version` | `getLibraryVersion` | Get library version string |

**Example:**
```zig
// These are equivalent:
var parsed = try args.parseInto(allocator, Config, options, null);
var parsed = try args.derive(allocator, Config, options, null);

// These are equivalent:
args.initConfig(.{ .use_colors = false });
args.configure(.{ .use_colors = false });
```

## Convenience Functions

### `createParser`

```zig
pub fn createParser(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser
```

Creates a parser with common defaults.

**Example:**
```zig
var parser = try args.createParser(allocator, "myapp");
defer parser.deinit();
```

### `createMinimalParser`

```zig
pub fn createMinimalParser(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser
```

Creates a minimal parser (no colors, no update check).

**Example:**
```zig
var parser = try args.createMinimalParser(allocator, "myapp");
defer parser.deinit();
```

### `deriveOptions`

```zig
pub fn deriveOptions(comptime T: type) []const ArgSpec
```

Derives argument specifications from a struct type at compile-time. Useful if you need the specs without parsing.

**Example:**
```zig
const Config = struct { verbose: bool, count: i32 };
const specs = args.deriveOptions(Config);
// specs is []const ArgSpec with 2 entries
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
