---
title: Types Reference
description: Complete reference for all types in args.zig including ValueType, ArgAction, Nargs, ParsedValue, and more.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, types, ValueType, ArgAction, Nargs, ParsedValue, api reference
---

# Types Reference

This document covers all core types and compile-time version constants in args.zig.

## Version Information

The library exposes the following compile-time constants for versioning:

```zig
pub const VERSION = "0.0.7";
```

## ValueType

Represents the type of value an argument accepts.

```zig
pub const ValueType = enum {
    string,     // Text value (default)
    int,        // Signed integer (i64)
    uint,       // Unsigned integer (u64)
    float,      // Floating point (f64)
    bool,       // Boolean
    path,       // File/directory path
    choice,     // One of predefined choices
    array,      // Multiple values
    counter,    // Incremented count
    custom,     // Custom type with validator
    key_value,  // Key=Value pair
    duration,   // Duration string (e.g. 1h30m) parsed into u64 seconds
    byte_size,  // Byte size string (e.g. 512MB) parsed into u64 bytes
};
```

### Methods

| Method | Description |
|--------|-------------|
| `typeName()` | Returns human-readable type name |
| `defaultAsString()` | Returns default value as string |
| `isNumeric()` | Returns true if type is numeric |

## ArgAction

Actions performed when an argument is encountered.

```zig
pub const ArgAction = enum {
    store,        // Store the value (default)
    store_true,   // Store true
    store_false,  // Store false
    append,       // Append to array
    count,        // Increment counter
    help,         // Print help and exit
    version,      // Print version and exit
    callback,     // Call custom function
    callback_flag, // Call custom function when flag is set (requires no value)
    extend,       // Extend array with values
};
```

### Methods

| Method | Description |
|--------|-------------|
| `requiresValue()` | Returns true if action needs a value |
| `isFlag()` | Returns true if action is a flag |

## Nargs

Specifies how many values an argument accepts.

```zig
pub const Nargs = union(enum) {
    exact: usize,   // Exactly N values
    optional,       // 0 or 1 value
    zero_or_more,   // 0 or more values (*)
    one_or_more,    // 1 or more values (+)
    remainder,      // All remaining arguments
};
```

### Methods

| Method | Description |
|--------|-------------|
| `minCount()` | Minimum required values |
| `maxCount()` | Maximum allowed values (null = unlimited) |
| `isSatisfied(count)` | Check if count satisfies requirement |
| `isVariadic()` | Returns true if accepts variable count |

### Examples

```zig
// Exactly 2 files
.nargs = .{ .exact = 2 }

// Optional value
.nargs = .optional

// One or more
.nargs = .one_or_more
```

## ParseResult

The result of parsing command-line arguments.

```zig
pub const ParseResult = struct {
    // ... internal fields
};
```

### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `get(name)` | `?ParsedValue` | Get a parsed value by name |
| `getString(name)` | `?[]const u8` | Get string value (or null) |
| `getInt(name)` | `?i64` | Get integer value (or null) |
| `getBool(name)` | `?bool` | Get boolean value (or null) |
| `getFloat(name)` | `?f64` | Get float value (or null) |
| `getUint(name)` | `?u64` | Get unsigned integer value (or null) |
| `getCounter(name)` | `?u32` | Get counter value (or null) |
| `getKeyValue(name)` | `?KeyValue` | Get key-value pair (or null) |
| `getArray(name)` | `?[]const []const u8` | Get array value (or null) |
| `getEnum(T, name)` | `?T` | Get value as enum type (or null) |
| `getDuration(name)` | `?u64` | Get duration in seconds (or null) |
| `getSize(name)` | `?u64` | Get byte-size value (or null) |
| `contains(name)` | `bool` | Check if a value exists |
| `positionalCount()` | `usize` | Count of positional arguments |
| `getPositional(index)` | `?[]const u8` | Get positional argument by index |

### Fallback Methods (getOr*)

| Method | Return Type | Description |
|--------|-------------|-------------|
| `getOrString(name, default)` | `[]const u8` | Get string with fallback default |
| `getOrInt(name, default)` | `i64` | Get integer with fallback default |
| `getOrBool(name, default)` | `bool` | Get boolean with fallback default |
| `getOrFloat(name, default)` | `f64` | Get float with fallback default |
| `getOrUint(name, default)` | `u64` | Get unsigned integer with fallback default |
| `getOrCounter(name, default)` | `u32` | Get counter value with fallback default |
| `getOrKeyValue(name, default)` | `KeyValue` | Get key-value pair with fallback default |

### Example: Fallback Patterns

```zig
// Using getOr* methods (inline fallback)
const verbose = result.getOrBool("verbose", false);
const count = result.getOrInt("count", 42);
const output = result.getOrString("output", "default.txt");

// Using orelse (equivalent)
const verbose2 = result.getBool("verbose") orelse false;

// Using with parseOr (parse-level fallback)
var result = parser.parseOr(args, null); // returns empty ParseResult on error
defer result.deinit();
```

## ParsedValue

Represents a parsed argument value.

```zig
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
};

pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};
```

### Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `isSet()` | `bool` | Check if value is set |
| `asInt()` | `?i64` | Try to get as integer |
| `asUint()` | `?u64` | Try to get as unsigned integer |
| `asFloat()` | `?f64` | Try to get as float |
| `asBool()` | `?bool` | Try to get as boolean |
| `asString()` | `?[]const u8` | Try to get as string |
| `asKeyValue()` | `?KeyValue` | Try to get as key-value pair |

## ArgSpec

Specification for a single argument.

```zig
pub const ArgSpec = struct {
    name: []const u8,
    short: ?u8 = null,
    long: ?[]const u8 = null,
    aliases: []const []const u8 = &.{},
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
    action: ArgAction = .store,
    nargs: Nargs = .{ .exact = 1 },
    required: bool = false,
    default: ?[]const u8 = null,
    choices: []const []const u8 = &.{},
    metavar: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    positional: bool = false,
    hidden: bool = false,
    group: ?[]const u8 = null,
    deprecated: ?[]const u8 = null,
    validator: ?validation.ValidatorFn = null,
    callback: ?CallbackFn = null,
    expect: []const []const u8 = &.{},
};
```

### Methods

| Method | Description |
|--------|-------------|
| `getDestination()` | Get storage name |
| `isFlag()` | Check if argument is a flag |
| `isOptional()` | Check if argument is optional |
| `getMetavar()` | Get metavar for help |
| `hasChoices()` | Check if has choice restriction |

## SubcommandSpec

Specification for a subcommand.

```zig
pub const SubcommandSpec = struct {
    name: []const u8,
    help: ?[]const u8 = null,
    aliases: []const []const u8 = &.{},
    args: []const ArgSpec = &.{},
    subcommands: []const SubcommandSpec = &.{},
    hidden: bool = false,
};
```

### Methods

| Method | Description |
|--------|-------------|
| `matches(name)` | Check if name matches command or alias |

## CommandSpec

Full command specification.

```zig
pub const CommandSpec = struct {
    name: []const u8,
    version: ?[]const u8 = null,
    description: ?[]const u8 = null,
    args: []const ArgSpec = &.{},
    subcommands: []const SubcommandSpec = &.{},
    epilog: ?[]const u8 = null,
    allow_interspersed: bool = true,
    add_help: bool = true,
    add_version: bool = true,
};
```

## Config

Parser configuration.

```zig
pub const Config = struct {
    check_for_updates: bool = true,
    show_update_notification: bool = true,
    use_colors: bool = true,
    help_line_width: usize = 80,
    help_indent: usize = 24,
    show_defaults: bool = true,
    show_env_vars: bool = true,
    program_name: ?[]const u8 = null,
    exit_on_error: bool = true,
    parsing_mode: ParsingMode = .strict,
    allow_short_clusters: bool = true,
    allow_inline_values: bool = true,
    allow_interspersed: bool = true,
    allow_negated_flags: bool = true,
    case_sensitive: bool = true,
    allow_brackets: bool = true,
    env_prefix: ?[]const u8 = null,
    silent_errors: bool = false,
    suggest_closest: bool = true,
    suggestion_max_distance: usize = 3,
    suggest_builtin_commands: bool = true,
    suggest_subcommands: bool = true,
    error_prefix: []const u8 = "Error",
    warning_prefix: []const u8 = "Warning",
    unknown_option_hint: ?[]const u8 = null,
    unknown_subcommand_hint: ?[]const u8 = null,
    unknown_option_message: ?[]const u8 = null,
    unknown_subcommand_message: ?[]const u8 = null,
    app_name: ?[]const u8 = null,
    app_version: ?[]const u8 = null,
    app_description: ?[]const u8 = null,
    app_epilog: ?[]const u8 = null,
    app_author: ?[]const u8 = null,
};
```

### Presets

| Preset | Description |
|--------|-------------|
| `Config.default()` | All features enabled |
| `Config.minimal()` | No colors, updates, or auto-exit |
| `Config.verbose()` | Extra debugging info |

### Config Notes

- When `allow_negated_flags` is `true`, long boolean options support `--no-<name>`.
- When `case_sensitive` is `false`, long option names and `choices` / `expect` checks are ASCII case-insensitive.

## Shell

Supported shell types for completions.

```zig
pub const Shell = enum {
    bash,
    zsh,
    fish,
    powershell,
};
```

### Methods

| Method | Description |
|--------|-------------|
| `Shell.fromString(s)` | Parse shell name from string |

## ParsingMode

Controls how unknown arguments are handled.

```zig
pub const ParsingMode = enum {
    strict,         // Error on unknown
    permissive,     // Collect unknown
    ignore_unknown, // Silently ignore
    interspersed,   // Allow mixed order
};
```

## DecodeMode

Controls optional input decoding/decryption before validation and value storage.

```zig
pub const DecodeMode = enum {
    none,
    base64_std,
    base64_url_safe,
};
```

## SchemaBuilder

A fluent builder API for constructing `CommandSpec` schemas typically used for advanced or programmatic schema creation.

```zig
pub const SchemaBuilder = struct {
    // ... internal fields
};
```

### Methods

| Method | Return | Description |
|--------|--------|-------------|
| `init(allocator, name)` | `SchemaBuilder` | Initialize a new builder |
| `deinit()` | `void` | Free resources |
| `setVersion(ver)` | `*SchemaBuilder` | Set version string |
| `setDescription(desc)` | `*SchemaBuilder` | Set description |
| `setEpilog(ep)` | `*SchemaBuilder` | Set epilog text |
| `addArg(spec)` | `!*SchemaBuilder` | Add a full argument specification |
| `addFlag(name, short, help)` | `!*SchemaBuilder` | Add a boolean flag |
| `addOption(name, short, help)` | `!*SchemaBuilder` | Add a value option |
| `addPositional(name, help)` | `!*SchemaBuilder` | Add a positional argument |
| `addSubcommand(spec)` | `!*SchemaBuilder` | Add a subcommand |
| `build()` | `CommandSpec` | Build and return the final spec |

### Example

```zig
var builder = args.SchemaBuilder.init(allocator, "myapp");
defer builder.deinit();

_ = try builder.setVersion("1.0").setDescription("My App")
    .addFlag("verbose", 'v', "Enable verbose output");

const spec = builder.build();
// Use spec with Parser...
```

## BracketType

Represents the bracket style for inline bracket-delimited list values.

```zig
pub const BracketType = enum {
    parentheses,  // (a,b,c)
    square,       // [a,b,c]
    curly,        // {a,b,c}
    angle,        // <a,b,c>
    none,         // no brackets — plain comma-separated
};
```

Used with `addBracketedListOption` to control which bracket styles are accepted.
When set to `null` (the default), all bracket types are auto-detected.

### Methods

```zig
pub fn detect(first: u8) BracketType
pub fn closing(self: BracketType) u8
```

- `detect` — returns the `BracketType` corresponding to the character, or `.none`.
- `closing` — returns the closing character for the bracket type (e.g. `.curly.closing()` returns `'}'`).

## Prompt Selection Types

These helper types support interactive CMD-style selection flows.

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

pub const PromptSelectOrAllDecision = union(enum) {
    all: void,
    selected: []const u8,
};
```

## Include/Exclude Helper Types

These helper types support strict filter workflows.

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

pub const IncludeExcludeStrictResolved = struct {
    all: bool,
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,
};

pub const IncludeExcludeResolved = struct {
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,
};
```

## Select/All Helper Types

These helper types support strict CSV select/all filter workflows.

```zig
pub const SelectOrAllStrictOptions = struct {
    select_key: []const u8 = "select",
    all_key: []const u8 = "all",
    choices: []const []const u8 = &.{},
    case_sensitive: bool = false,
    allow_prefix_match: bool = true,
    dedupe: bool = true,
    require_selection_when_not_all: bool = false,
};

pub const SelectOrAllStrictResolved = struct {
    all: bool,
    selected: [][]const u8,
    allocator: std.mem.Allocator,
};
```
