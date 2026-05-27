---
title: Installation
description: How to install and configure args.zig in your Zig project.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, installation, setup, build.zig, package manager
---

# Installation

`args.zig` is designed to be easily integrated into your Zig projects using the Zig package manager.

## Prerequisites

- **Zig 0.16.0** or later.

## Adding to your Project

### Release Installation (Recommended)

To install the latest stable release for zig v0.16 (v0.0.7), verify the hash and add it to your `build.zig.zon` by running:

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.7.tar.gz
```

Install the supported release for zig v0.15 (v0.0.4):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.4.tar.gz
```

### Nightly Installation

If you want to use the latest features from the main branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/args.zig
```

## Configuring build.zig

Once added to `build.zig.zon`, you need to expose the module to your executable in `build.zig`.

Add the following lines to your `build.zig` file:

```zig
pub fn build(b: *std.Build) void {
    // ... setup target and optimize ...

    const args_dep = b.dependency("args", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        // ... executable config ...
    });

    // Add the args module import
    exe.root_module.addImport("args", args_dep.module("args"));

    // ... install artifact ...
}
```

## Verifying Installation

Create a simple `main.zig` to verify the installation:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "hello",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output"
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getBool("verbose") orelse false) {
        std.debug.print("Hello from args.zig!\n", .{});
    }
}
```

Run it with:

```bash
zig build run -- --verbose
```
