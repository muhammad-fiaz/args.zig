---
title: Disabling Update Checker
description: Learn how to disable the optional update checker in args.zig for air-gapped environments or CI/CD pipelines.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, update checker, disable updates, configuration
---

# Disabling Update Checker

args.zig includes an optional non-blocking update checker that notifies users when a new version is available. This guide explains how to disable or configure this feature.

## Why Disable?

You might want to disable the update checker if:

- Your application runs in an air-gapped environment
- You want to minimize network requests
- You're running in CI/CD pipelines
- You prefer not to have automatic update checks

## Disabling Methods

### Method 1: Global Disable Function

The simplest way to disable update checking globally:

```zig
const args = @import("args");

pub fn main() !void {
    // Disable before creating any parsers
    args.disableUpdateCheck();
    
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
    });
    defer parser.deinit();
    
    // ... rest of your code
}
```

### Method 2: Per-Parser Configuration

Disable for a specific parser only:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{
        .check_for_updates = false,
        .show_update_notification = false,
    },
});
```

### Method 3: Minimal Configuration Preset

Use the minimal preset which disables updates and other features:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(),
});
```

The minimal preset sets:
- `check_for_updates = false`
- `show_update_notification = false`
- `use_colors = false`
- `show_defaults = false`
- `show_env_vars = false`
- `exit_on_error = false`

### Method 4: Global Configuration

Set global configuration before creating any parsers:

```zig
args.initConfig(.{
    .check_for_updates = false,
    .show_update_notification = false,
});

// All parsers will inherit this config
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
});
```

## Re-enabling Update Checks

If you've disabled update checks and want to re-enable them:

```zig
args.enableUpdateCheck();
```

## How Update Checking Works

When enabled, the update checker:

1. Runs in a **background thread** (non-blocking)
2. Checks GitHub releases for the latest version
3. Compares with the current library version
4. Prints a notification if a newer version is available

The check is:
- **Non-blocking**: Won't slow down your application startup
- **Silent on failure**: Network errors are silently ignored
- **Respects configuration**: Can be disabled completely

## Example: Conditional Update Checking

```zig
const args = @import("args");
const std = @import("std");

pub fn main() !void {
    // Check environment variable to decide
    const disable_updates = std.process.getEnvVarOwned(
        allocator, 
        "MYAPP_DISABLE_UPDATES"
    ) catch null;
    defer if (disable_updates) |u| allocator.free(u);
    
    if (disable_updates != null) {
        args.disableUpdateCheck();
    }
    
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
    });
    defer parser.deinit();
    
    // ... rest of your code
}
```

## Update Notification Format

When an update is available, the notification looks like:

```
╭─────────────────────────────────────────────────────────╮
│  A new version of args.zig is available: 0.0.1 → 0.1.0 │
│  Run: zig fetch --save git+https://github.com/...      │
╰─────────────────────────────────────────────────────────╯
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Option 1: Use minimal config (disables updates)
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "My application with updates disabled",
        .config = args.Config.minimal(),
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });

    var result = try parser.parseProcess();
    defer result.deinit();

    // Your application logic here
}
```
