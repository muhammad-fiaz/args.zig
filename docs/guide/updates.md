---
title: Update Checker Configuration
description: Learn how to configure the update checker in args.zig.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, update checker, disable updates, configuration
---

# Update Checker Configuration

args.zig includes an optional non-blocking update checker that notifies users when a new version is available. By default, this feature is **enabled**. This guide explains how to configure or disable it.

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
    // ...
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

### Method 3: Global Configuration

Set global configuration before creating any parsers:

```zig
args.initConfig(.{
    .check_for_updates = false,
});
```

### Method 4: Minimal Configuration Preset

Use the minimal preset which disables updates and other features:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(),
});
```

## How Update Checking Works

When enabled, the update checker:

1. Runs in a **background thread** (non-blocking)
2. Checks GitHub releases for the latest version
3. Compares with the current library version
4. Prints a notification if a newer version is available (to stderr)

The check is:
- **Non-blocking**: Won't slow down your application startup
- **Silent on failure**: Network errors are silently ignored and do not impact the application
- **Respects configuration**: Can be enabled/disabled completely

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

