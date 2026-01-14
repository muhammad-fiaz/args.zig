---
title: Callbacks
description: Trigger custom functions immediately during argument parsing with callbacks.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, callbacks, hooks, custom actions, argument parsing
---

# Callbacks

Callbacks allow you to execute a function immediately when an argument is successfully parsed. This is useful for side effects like logging, immediate configuration updates, or triggering actions that don't need to wait for the entire parsing to complete.

## Basic Usage

A callback function must match the `CallbackFn` signature:

```zig
fn (name: []const u8, value: ?[]const u8) void
```

- **name**: The name (or destination) of the argument.
- **value**: The raw string value provided (if any).

### Example

```zig
const std = @import("std");
const args = @import("args");

fn onOutput(name: []const u8, value: ?[]const u8) void {
    if (value) |v| {
        std.debug.print("Setting output file to: {s}\n", .{v});
    }
}

pub fn main() !void {
    // ... init parser ...
    
    try parser.addArg(.{
        .name = "output",
        .long = "output",
        .action = .callback,
        .callback = onOutput,
        .help = "Output file (triggers callback)",
    });
    
    // ... parse ...
}
```

## Behavior

1.  **Immediate Execution**: The callback runs **during** the parsing loop, as soon as the argument is identified and validated.
2.  **Validation First**: If the argument has a validator or checking logic (like types), successful validation happens *before* the callback is invoked.
3.  **Value Storage**: Even with a callback, the value is typically still stored in the result map (for options with values). This allows you to check it later if needed.

## Flag Callbacks

For flags (boolean options) that don't take a value, use `.action = .callback_flag`. The callback will receive `null` as the value.

```zig
fn onVerbose(name: []const u8, value: ?[]const u8) void {
    _ = value; // null for flags
    std.debug.print("Verbosity enabled!\n", .{});
}

try parser.addArg(.{
    .name = "verbose",
    .short = 'v',
    .action = .callback_flag,
    .callback = onVerbose,
});
```

## Use Cases

- **Logging**: Print a message when a specific flag is set using a verbose logger that might be configured by a previous argument.
- **Immediate Exit**: Implement custom version or help flags that don't rely on the built-in mechanism.
- **Dynamic Configuration**: Adjust parser behavior or global state based on early arguments.
