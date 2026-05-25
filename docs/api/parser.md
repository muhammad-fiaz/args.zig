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
- In `strict` mode, unknown long options and unknown subcommands can emit closest-match suggestions when `Config.suggest_closest = true`.
- Built-in names `--help` and `--version` are included in unknown-option suggestion candidates when `Config.suggest_builtin_commands = true`.
- Unknown subcommand suggestions are controlled by `Config.suggest_subcommands`.
- Help generation respects `Config.program_name`, `Config.help_indent`, and `Config.help_line_width`.

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
    aliases: []const []const u8 = &.{},
    deprecated: ?[]const u8 = null,
    validator: ?validation.ValidatorFn = null,
    expect: []const []const u8 = &.{},
    suggestion_hint: ?[]const u8 = null,
    custom_error_message: ?[]const u8 = null,
    decode_mode: DecodeMode = .none,
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
    decode_mode: DecodeMode = .none,
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

### `addDecryptionOption`

```zig
pub fn addDecryptionOption(self: *ArgumentParser, name: []const u8, options: struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    default: ?[]const u8 = null,
    required: bool = false,
    metavar: ?[]const u8 = "BASE64",
    dest: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    hidden: bool = false,
    aliases: []const []const u8 = &.{},
    deprecated: ?[]const u8 = null,
    validator: ?validation.ValidatorFn = null,
    expect: []const []const u8 = &.{},
    suggestion_hint: ?[]const u8 = null,
    custom_error_message: ?[]const u8 = null,
    url_safe: bool = false,
}) !void
```

Adds a string option that decodes incoming Base64 input before validation and storage.

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

### `addSelectCsvOption`

Adds a CSV-oriented `--select` option for multi-target workflows.

### `addSelectOrAllCsv`

Adds an exclusive helper pair around `--select <csv-list>` and `--all`.

### `addIncludeOption`

Adds a conventional `--include` option for comma-separated filters.

### `addExcludeOption`

Adds a conventional `--exclude` option for comma-separated filters.

### `addIncludeExclude`

Adds both include/exclude options under one group for help organization.

### `addPathOption`

Adds a path option (`ValueType.path`) for generic path workflows.

### `addFileOption`

Adds a file path option with optional existence validation.

### `addDirectoryOption`

Adds a directory path option with optional existence validation.

### `addFileOptionWithExtensions`

```zig
pub fn addFileOptionWithExtensions(
    self: *ArgumentParser,
    name: []const u8,
    comptime allowed_extensions: []const []const u8,
    options: struct { ... },
) !void
```

Adds a file path option with reusable extension validation and optional existence checks.

### `addFileNameOption`

Adds a file-name-only option (safe name, no path separators) with optional custom validator.

### `addFileNameOptionWithExtensions`

```zig
pub fn addFileNameOptionWithExtensions(
    self: *ArgumentParser,
    name: []const u8,
    comptime allowed_extensions: []const []const u8,
    options: struct { ... },
) !void
```

### `addEndpointOption`

Adds a validated endpoint option in `host:port` format.

Example:

```zig
try parser.addEndpointOption("service", .{
    .help = "Service endpoint (host:port)",
});
```

### Typed Input Helper Methods

The parser includes one-call helpers for common input formats:

- `addEmailOption`
- `addUrlOption`
- `addIpv4Option`
- `addIpOption`
- `addIpv6Option`
- `addHostNameOption`
- `addPortOption`
- `addEndpointOption`
- `addKeyValueOption`
- `addUuidOption`
- `addIsoDateOption`
- `addIsoDateTimeOption`
- `addYearOption`
- `addTimeOption`
- `addJsonOption`
- `addAbsolutePathOption`

Each helper adds a `.string` option with an appropriate built-in validator.

Common helper option fields:

- `short`, `help`, `default`, `required`
- `metavar`, `dest`, `env_var`
- `hidden`, `aliases`, `deprecated`
- `validator` (override default built-in validator)
- `expect`

Example:

```zig
try parser.addEmailOption("email", .{
    .short = 'e',
    .required = true,
    .env_var = "APP_EMAIL",
});

try parser.addEndpointOption("service", .{
    .help = "Service endpoint in host:port format",
    .default = "localhost:8080",
});

try parser.addIpv6Option("host-v6", .{
    .help = "Service IPv6 address",
});

try parser.addIpOption("host-any", .{
    .help = "Service IP address (IPv4 or IPv6)",
});

try parser.addKeyValueOption("label", .{
    .help = "Metadata label as key=value",
});

try parser.addOption("retries", .{
    .value_type = .int,
    .validator = args.Validators.intRange(1, 10),
    .default = "3",
});

var result = try parser.parseProcess(init);
defer result.deinit();

const email = result.getString("email") orelse "";
const service = result.getString("service") orelse "localhost:8080";
const retries = result.getInt("retries") orelse 3;
const label = result.getKeyValue("label");
```

### Validator Aliases (Top-Level)

`args.zig` re-exports validation helpers for concise client-side usage:

```zig
pub const ValidatorFn = validation.ValidatorFn;
pub const Validators = validation.Validators;
```

This allows direct usage like:

```zig
const validator = args.Validators.filePolicy(&[_][]const u8{"json"}, false, 3, 64);
```

### `PromptSelectOrAllOptions`

```zig
pub const PromptSelectOrAllOptions = struct {
    select_key: []const u8 = "select",
    all_key: []const u8 = "all",
    question: []const u8 = "Choose target",
    choices: []const []const u8,
    default_choice: ?[]const u8 = null,
    allow_all: bool = true,
    case_sensitive: ?bool = null,
    allow_prefix_match: bool = true,
    suggest_closest: bool = true,
    max_suggestion_distance: usize = 3,
    max_attempts: usize = 3,
};
```

### `SelectOrAllStrictOptions`

Configuration for strict CSV select/all resolution with optional normalization and deduplication.

### `resolveSelectOrAllStrict`

Resolves parsed `--select` and `--all` values into a canonical selection result:

```zig
var resolved = try args.resolveSelectOrAllStrict(allocator, &parsed, .{
    .choices = &[_][]const u8{ "users", "groups", "logs" },
    .allow_prefix_match = true,
    .dedupe = true,
});
defer resolved.deinit();
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
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    io: std.Io,
) !PromptSelectOrAllDecision
```

Uses parsed `--select` / `--all` first. If missing, prompts the user interactively and validates the answer. The `io` parameter provides the I/O context (pass `init.io` from your `main` function).

### `resolveSelectOrAllWithPromptIO`

```zig
pub fn resolveSelectOrAllWithPromptIO(
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
) !PromptSelectOrAllDecision
```

Same behavior as `resolveSelectOrAllWithPrompt`, but with explicit reader/writer references for tests and embedded runtimes.

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
pub fn parseProcess(self: *ArgumentParser, proc_init: std.process.Init) !ParseResult
```

Parses arguments from the current process using the process initialization context.

**Example:**
```zig
var result = try parser.parseProcess(init);
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
    positionals: std.ArrayList([]const u8),
    remaining: std.ArrayList([]const u8),
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

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "example",
        .version = "1.0.0",
        .description = "Example application",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o', .default = "out.txt" });
    try parser.addPositional("input", .{});

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const output = result.getString("output").?;
    const input = result.getString("input").?;

    std.debug.print("Input: {s}, Output: {s}, Verbose: {}\n", .{
        input, output, verbose
    });
}
```
