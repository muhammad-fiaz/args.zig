---
title: ParsedValue API
description: API reference for the ParsedValue tagged union in args.zig. Accessor methods for type-safe value extraction.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, ParsedValue, union, accessor, api reference
---

# ParsedValue API Reference

`ParsedValue` is a tagged union representing a parsed argument value. It holds the raw value returned by the parser and provides methods for safe type conversion.

## Union Definition

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
```

Each variant corresponds to a `ValueType` used when defining arguments.

## Supporting Type

```zig
pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};
```

## Methods

### `isSet`

```zig
pub fn isSet(self: ParsedValue) bool
```

Returns `true` if the value is not `.none`. Useful for checking whether a value was actually assigned.

**Example:**
```zig
const val = result.get("output") orelse .none;
if (val.isSet()) {
    // value was assigned
}
```

### `asString`

```zig
pub fn asString(self: ParsedValue) ?[]const u8
```

Returns the value as a string if it is the `.string` variant, otherwise `null`.

### `asInt`

```zig
pub fn asInt(self: ParsedValue) ?i64
```

Returns the value as a signed 64-bit integer. Converts from:
- `.int` — direct
- `.uint` — if within `i64` range
- `.counter` — zero-extended

Returns `null` for other variants.

### `asUint`

```zig
pub fn asUint(self: ParsedValue) ?u64
```

Returns the value as an unsigned 64-bit integer. Converts from:
- `.uint` — direct
- `.int` — if non-negative
- `.counter` — zero-extended

Returns `null` for other variants.

### `asFloat`

```zig
pub fn asFloat(self: ParsedValue) ?f64
```

Returns the value as a 64-bit float. Converts from:
- `.float` — direct
- `.int` — integer-to-float conversion
- `.uint` — integer-to-float conversion

Returns `null` for other variants.

### `asBool`

```zig
pub fn asBool(self: ParsedValue) ?bool
```

Returns the value as a boolean. Converts from:
- `.boolean` — direct
- `.counter` — `true` if count > 0, `false` if count == 0

Returns `null` for other variants.

### `asKeyValue`

```zig
pub fn asKeyValue(self: ParsedValue) ?KeyValue
```

Returns the value as a `KeyValue` pair if it is the `.key_value` variant, otherwise `null`.

### `asArray`

The `.array` variant is accessed directly via the union field:

```zig
const val = result.get("tags") orelse return;
if (val == .array) {
    const items = val.array; // []const []const u8
    for (items) |item| {
        std.debug.print("{s}\n", .{item});
    }
}
```

## Type Conversion Summary

| Source Variant | `asInt` | `asUint` | `asFloat` | `asBool` | `asString` |
|---------------|---------|----------|-----------|----------|------------|
| `.string`     | —       | —        | —         | —        | direct     |
| `.int`        | direct  | if ≥ 0   | yes       | —        | —          |
| `.uint`       | if ≤ max | direct  | yes       | —        | —          |
| `.float`      | —       | —        | direct    | —        | —          |
| `.boolean`    | —       | —        | —         | direct   | —          |
| `.counter`    | yes     | yes      | —         | > 0 → true | —       |
| `.key_value`  | —       | —        | —         | —        | —          |
| `.array`      | —       | —        | —         | —        | —          |
| `.none`       | null    | null     | null      | null     | null       |

> [!NOTE]
> Cross-type conversions are lossy. For example, `asInt` on a `.uint` will return `null` if the value exceeds `i64` max.

## Examples

### Working with raw values

```zig
const val = result.get("count") orelse return error.Missing;
switch (val) {
    .int => |i| std.debug.print("int: {d}\n", .{i}),
    .uint => |u| std.debug.print("uint: {d}\n", .{u}),
    .float => |f| std.debug.print("float: {d}\n", .{f}),
    .boolean => |b| std.debug.print("bool: {}\n", .{b}),
    .string => |s| std.debug.print("string: {s}\n", .{s}),
    .counter => |c| std.debug.print("counter: {d}\n", .{c}),
    .key_value => |kv| std.debug.print("{s}={s}\n", .{ kv.key, kv.value }),
    .array => |a| std.debug.print("array len: {d}\n", .{a.len}),
    .none => std.debug.print("none\n", .{}),
}
```

### Cross-type coercion

```zig
const val = result.get("retries") orelse return;

// Try as different types — the library handles safe conversion
if (val.asInt()) |i| {
    std.debug.print("as int: {d}\n", .{i});
}
if (val.asFloat()) |f| {
    std.debug.print("as float: {d}\n", .{f});
}
if (val.asBool()) |b| {
    std.debug.print("as bool: {}\n", .{b});
}
```

### Counter as boolean

```zig
try parser.addCounter("verbose", .{ .short = 'v' });

// User passes: -v -v -v
var result = try parser.parse(&args);
defer result.deinit();

const val = result.get("verbose").?;
// val.counter == 3
// val.asBool() == true  (because counter > 0)
// val.asInt()  == 3
```
