---
title: ParseResult API
description: Complete API reference for the ParseResult struct in args.zig. Methods for retrieving parsed argument values with type-safe accessors and defaults.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, api, ParseResult, parsed, result, reference
---

# ParseResult API Reference

`ParseResult` holds the output of argument parsing. It stores parsed values in a hash map keyed by argument name and provides type-safe accessor methods.

## Struct Definition

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

## Lifecycle Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator) ParseResult
```

Creates an empty `ParseResult`. Normally called internally by the parser, but can be used to create a result manually.

### `deinit`

```zig
pub fn deinit(self: *ParseResult) void
```

Releases all resources owned by the result, including owned slices, arrays, and any subcommand results.

> [!WARNING]
> Always call `deinit` when you are done with a `ParseResult` to avoid memory leaks.

### `ownSlice`

```zig
pub fn ownSlice(self: *ParseResult, slice: []const u8) !void
```

Registers an allocated slice as owned by this result. Owned slices are freed automatically when `deinit` is called.

### `ownArray`

```zig
pub fn ownArray(self: *ParseResult, arr: [][]const u8) !void
```

Registers an allocated array buffer as owned by this result.

### `put`

```zig
pub fn put(self: *ParseResult, name: []const u8, value: ParsedValue) !void
```

Inserts or replaces a value in the result. Useful when you need to inject values programmatically.

**Example:**
```zig
var result = ParseResult.init(allocator);
defer result.deinit();

try result.put("output", .{ .string = "file.txt" });
try result.put("count", .{ .int = 42 });
```

## Raw Accessors

### `get`

```zig
pub fn get(self: *const ParseResult, name: []const u8) ?ParsedValue
```

Returns the raw `ParsedValue` for the given argument name, or `null` if not present.

**Example:**
```zig
if (result.get("verbose")) |val| {
    // val is a ParsedValue union — use asBool(), asString(), etc.
}
```

### `contains`

```zig
pub fn contains(self: *const ParseResult, name: []const u8) bool
```

Returns `true` if a value with the given name exists in the result.

**Example:**
```zig
if (result.contains("output")) {
    // value was set (by user or default)
}
```

### `isPresent`

```zig
pub fn isPresent(self: *const ParseResult, name: []const u8) bool
```

Returns `true` if the argument was explicitly provided. Identical behavior to `contains`.

> [!TIP]
> Use `isPresent` when you want to distinguish between "user provided a value" and "value came from defaults." Both `contains` and `isPresent` check the values map, which includes defaults applied at parse time.

### `positionalCount`

```zig
pub fn positionalCount(self: *const ParseResult) usize
```

Returns the number of positional arguments captured.

### `hasSubcommand`

```zig
pub fn hasSubcommand(self: *const ParseResult) bool
```

Returns `true` if a subcommand was matched during parsing.

## Typed Getters

These methods return `null` if the value is missing or the stored type doesn't match.

### `getString`

```zig
pub fn getString(self: *const ParseResult, name: []const u8) ?[]const u8
```

Returns the value as a string.

### `getInt`

```zig
pub fn getInt(self: *const ParseResult, name: []const u8) ?i64
```

Returns the value as a signed 64-bit integer. Converts from `.uint` or `.counter` when safe.

### `getUint`

```zig
pub fn getUint(self: *const ParseResult, name: []const u8) ?u64
```

Returns the value as an unsigned 64-bit integer. Converts from `.int` (if non-negative) or `.counter`.

### `getFloat`

```zig
pub fn getFloat(self: *const ParseResult, name: []const u8) ?f64
```

Returns the value as a 64-bit float. Converts from `.int` or `.uint`.

### `getBool`

```zig
pub fn getBool(self: *const ParseResult, name: []const u8) ?bool
```

Returns the value as a boolean. For `.counter` values, returns `true` if the count is > 0.

### `getCounter`

```zig
pub fn getCounter(self: *const ParseResult, name: []const u8) ?u32
```

Returns the value as a counter (unsigned 32-bit integer).

### `getKeyValue`

```zig
pub fn getKeyValue(self: *const ParseResult, name: []const u8) ?KeyValue
```

Returns a `KeyValue` pair (`{ key: []const u8, value: []const u8 }`).

### `getArray`

```zig
pub fn getArray(self: *const ParseResult, name: []const u8) ?[]const []const u8
```

Returns an array of strings (from `addListOption` or `addAppend`).

### `getEnum`

```zig
pub fn getEnum(self: *const ParseResult, comptime T: type, name: []const u8) ?T
```

Converts the stored string value to the given enum type. Returns `null` if the value is missing or doesn't match any enum variant.

**Example:**
```zig
const Mode = enum { debug, info, warn, @"error" };
const level = result.getEnum(Mode, "log-level") orelse .info;
```

### `getDuration`

```zig
pub fn getDuration(self: *const ParseResult, name: []const u8) ?u64
```

Returns the parsed duration in total seconds (from `addDurationOption`).

### `getSize`

```zig
pub fn getSize(self: *const ParseResult, name: []const u8) ?u64
```

Returns the parsed byte size in total bytes (from `addSizeOption`).

**Example:**
```zig
const timeout = result.getDuration("timeout") orelse 30; // seconds
const buffer = result.getSize("buffer") orelse 1024;     // bytes
```

## Fallback Getters (`getOr*`)

These methods return the provided default value when the argument is missing or the type doesn't match. They never return `null`.

### `getOrString`

```zig
pub fn getOrString(self: *const ParseResult, name: []const u8, default: []const u8) []const u8
```

### `getOrInt`

```zig
pub fn getOrInt(self: *const ParseResult, name: []const u8, default: i64) i64
```

### `getOrUint`

```zig
pub fn getOrUint(self: *const ParseResult, name: []const u8, default: u64) u64
```

### `getOrFloat`

```zig
pub fn getOrFloat(self: *const ParseResult, name: []const u8, default: f64) f64
```

### `getOrBool`

```zig
pub fn getOrBool(self: *const ParseResult, name: []const u8, default: bool) bool
```

### `getOrCounter`

```zig
pub fn getOrCounter(self: *const ParseResult, name: []const u8, default: u32) u32
```

### `getOrKeyValue`

```zig
pub fn getOrKeyValue(self: *const ParseResult, name: []const u8, default: KeyValue) KeyValue
```

**Example:**
```zig
const verbose = result.getOrBool("verbose", false);
const count = result.getOrInt("count", 42);
const output = result.getOrString("output", "default.txt");
const rate = result.getOrFloat("rate", 0.5);
```

> [!TIP]
> The `getOr*` methods are equivalent to `get*(name) orelse default`, but slightly more concise for inline usage.

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

const Mode = enum { fast, safe };

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "example",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o', .default = "out.txt" });
    try parser.addCounter("log-level", .{ .short = 'l' });
    try parser.addListOption("tags", .{ .short = 't' });
    try parser.addPositional("input", .{});

    var result = try parser.parseProcess(init);
    defer result.deinit();

    // Typed getters with null check
    const verbose = result.getBool("verbose") orelse false;
    const output = result.getString("output").?;
    const input = result.getString("input").?;
    const log_level = result.getCounter("log-level") orelse 0;

    // Fallback getters (inline defaults)
    const tags = result.getArray("tags") orelse &.{};

    // Raw access
    if (result.contains("verbose")) {
        std.debug.print("verbose was set\n", .{});
    }

    // Enum conversion
    // const mode = result.getEnum(Mode, "mode") orelse .safe;

    std.debug.print("Input: {s}, Output: {s}, Verbose: {}, Log: {d}\n", .{
        input, output, verbose, log_level,
    });
}
```
