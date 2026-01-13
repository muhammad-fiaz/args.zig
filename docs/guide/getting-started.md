---
title: Getting Started
description: Learn how to install and set up args.zig in your Zig project. Quick start guide for command-line argument parsing.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, installation, getting started, setup, argument parser
---

# Getting Started

This guide will help you get started with args.zig in your Zig project.

## Requirements

- **Zig 0.15.1** or later
- A Zig project with `build.zig` and `build.zig.zon`

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.2):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.2.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/args.zig
```

### Configure build.zig

Add the dependency to your executable in `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add args.zig dependency
    const args_dep = b.dependency("args", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import args module
    exe.root_module.addImport("args", args_dep.module("args"));

    b.installArtifact(exe);
}
```

## Your First Parser

Create a simple command-line application:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "greet",
        .version = "1.0.0",
        .description = "A friendly greeting application",
    });
    defer parser.deinit();

    // Add arguments
    try parser.addOption("name", .{
        .short = 'n',
        .help = "Name to greet",
        .default = "World",
    });

    try parser.addFlag("excited", .{
        .short = 'e',
        .help = "Add excitement to greeting",
    });

    // Parse arguments
    var result = try parser.parseProcess();
    defer result.deinit();

    // Use the results
    const name = result.getString("name") orelse "World";
    const excited = result.getBool("excited") orelse false;

    if (excited) {
        std.debug.print("Hello, {s}!!!\n", .{name});
    } else {
        std.debug.print("Hello, {s}.\n", .{name});
    }
}
```

## Running Your App

```bash
# Default greeting
zig build run
# Output: Hello, World.

# Custom name
zig build run -- --name Alice
# Output: Hello, Alice.

# With excitement
zig build run -- -n Bob -e
# Output: Hello, Bob!!!

# View help
zig build run -- --help
# The help output is formatted for better understanding 🎨
```

## Version Information

You can access version information in your code:

```zig
const args = @import("args");

// Library version
std.debug.print("args.zig version: {s}\n", .{args.VERSION});

// Version components
std.debug.print("Major: {d}, Minor: {d}, Patch: {d}\n", .{
    args.VERSION_MAJOR,
    args.VERSION_MINOR,
    args.VERSION_PATCH,
});

// Minimum Zig version
std.debug.print("Requires Zig: {s}+\n", .{args.MINIMUM_ZIG_VERSION});
```

## Enabling Update Checker

By default, args.zig update checker is **disabled**. To enable it:

```zig
// Method 1: Global enable
args.enableUpdateCheck();

// Method 2: Per-parser config
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .check_for_updates = true },
});
```

See [Update Checker Configuration](/guide/updates) for more details.

## Next Steps

- Learn about [Options and Flags](/guide/options-flags)
- Explore [Subcommands](/guide/subcommands)
- Configure [Environment Variables](/guide/environment-variables)
- Check the [API Reference](/api/parser)
