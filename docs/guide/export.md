---
title: Export / Introspection
description: How to enumerate, inspect, and export all registered arguments, subcommands, and groups at runtime.
---

# Export / Introspection

The export API exposes every registered argument definition at runtime. This is useful for documentation generators, client-side scaffolding, protocol-level argument exchange, and CLI tooling that needs to reason about its own schema.

## Quick Start

```zig
var parser = try args.ArgumentParser.init(allocator, .{ .name = "myapp" });
defer parser.deinit();

try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
try parser.addOption("output", .{ .short = 'o', .help = "Output file" });
try parser.addSubcommand(.{ .name = "init", .help = "Initialize project" });

// Get all arguments
const all_args = parser.getAllArgs();
for (all_args) |arg| {
    std.debug.print("{s}: {s}\n", .{ arg.name, arg.value_type.typeName() });
}

// Get all subcommands
const subs = parser.getAllSubcommands();
for (subs) |sub| {
    std.debug.print("sub: {s}\n", .{sub.name});
}
```

## API Reference

### getAllArgs

Returns a read-only slice of every registered `ArgSpec`.

```zig
pub fn getAllArgs(self: *const ArgumentParser) []const ArgSpec
```

The returned pointers remain valid until the parser is deinitialised or the argument list is mutated.

### getAllSubcommands

Returns a read-only slice of every registered `SubcommandSpec`.

```zig
pub fn getAllSubcommands(self: *const ArgumentParser) []const SubcommandSpec
```

### getAllGroups

Returns a read-only slice of every registered `ArgumentGroup`.

```zig
pub fn getAllGroups(self: *const ArgumentParser) []const ArgumentGroup
```

### getAllMutualExclusions

Returns the mutual-exclusion groups. Each group is a slice of argument names.

```zig
pub fn getAllMutualExclusions(self: *const ArgumentParser) []const []const []const u8
```

### exportSpec

Builds and returns the full `CommandSpec` snapshot.

```zig
pub fn exportSpec(self: *ArgumentParser) CommandSpec
```

This is equivalent to `buildSpec` but available as a convenience for callers who only need the snapshot without further mutation.

### getArgSpec

Looks up a single `ArgSpec` by name, long flag, destination, or alias. Returns `null` if no argument matches.

```zig
pub fn getArgSpec(self: *const ArgumentParser, name: []const u8) ?ArgSpec
```

### totalArgCount

Returns the number of registered arguments (including hidden ones).

```zig
pub fn totalArgCount(self: *const ArgumentParser) usize
```

### totalSubcommandCount

Returns the number of registered subcommands.

```zig
pub fn totalSubcommandCount(self: *const ArgumentParser) usize
```

### totalGroupCount

Returns the number of registered argument groups.

```zig
pub fn totalGroupCount(self: *const ArgumentParser) usize
```

## ArgSpec Fields

Each `ArgSpec` returned by the export methods contains:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `[]const u8` | Primary argument name |
| `short` | `?u8` | Short flag character (e.g. `'v'` for `-v`) |
| `long` | `?[]const u8` | Long flag name (e.g. `"verbose"` for `--verbose`) |
| `help` | `?[]const u8` | Help text |
| `value_type` | `ValueType` | Expected value type (string, int, float, bool, etc.) |
| `action` | `ArgAction` | How the argument is processed (store, store_true, count, etc.) |
| `required` | `bool` | Whether the argument is required |
| `default` | `?[]const u8` | Default value |
| `choices` | `[]const []const u8` | Allowed values |
| `metavar` | `?[]const u8` | Metavar for help text |
| `dest` | `?[]const u8` | Destination key for parsed result |
| `env_var` | `?[]const u8` | Environment variable fallback |
| `positional` | `bool` | Whether this is a positional argument |
| `hidden` | `bool` | Whether this is hidden from help |
| `group` | `?[]const u8` | Argument group name |
| `deprecated` | `?[]const u8` | Deprecation message |
| `conflicts_with` | `[]const []const u8` | Mutually exclusive arguments |
| `requires` | `[]const []const u8` | Required companion arguments |
| `required_if` | `[]const RequiredIf` | Conditional requirements |

## Example Output

```
=== Registered Arguments (4) ===
  verbose  (-v)  [BOOL]  -- Enable verbose output
  output   (-o)  [STRING]  (default: stdout)  -- Output file path
  port     (-p)  [INT]  (default: 8080)  -- Listen port
  config   [STRING]  REQUIRED  -- Path to configuration file

=== Subcommands (2) ===
  serve  -- Start the server
  check  -- Validate configuration

=== Argument Groups (1) ===
  Network  -- Connection-related options  (exclusive: false, required: false)

=== Full Spec Snapshot ===
  name:    export-example
  version: 1.0.0
  args:    4
  subs:    2

=== Lookup: 'port' ===
  name:      port
  type:      INT
  default:   8080
  dest:      port
```
