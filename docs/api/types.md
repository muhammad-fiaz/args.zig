---
title: Types Reference
description: Complete reference for all types in args.zig including ValueType, ArgAction, Nargs, ParsedValue, and more.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, types, ValueType, ArgAction, Nargs, ParsedValue, api reference
---

# Types Reference

This document covers all core types in args.zig.

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
    none: void,
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
    env_prefix: ?[]const u8 = null,
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
    case_sensitive: bool = false,
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
```
