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

> [!NOTE]
> args.zig supports both **Zig 0.16** and **Zig 0.17**. The library automatically detects your Zig version at compile-time.

- A Zig project with `build.zig` and `build.zig.zon`

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.8):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.8.tar.gz
```

Install the supported release for zig v0.15 (v0.0.4):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.4.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/args.zig
```

### Configure build.zig (Release / Nightly)

After running `zig fetch --save`, your `build.zig.zon` will have a dependency entry like:

```zon
.dependencies = .{
    .args = .{
        .url = "https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.8.tar.gz",
        .hash = "...",
    },
},
```

Now configure your `build.zig` to import the `args` module into your executable:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Add args.zig as a dependency
    const args_dep = b.dependency("args", .{
        .target = target,
        .optimize = optimize,
    });

    // 2. Create your executable
    const exe = b.addExecutable(.{
        .name = "my-cli-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // 3. Import the args module into your executable
    exe.root_module.addImport("args", args_dep.module("args"));

    // 4. Install and optionally add a run step
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(&b.installArtifact(exe).step);
    // Zig 0.17+ replaced b.args with addPassthruArgs().
    // Zig 0.16 still uses the b.args field.
    if (comptime builtin.zig_version.minor >= 17) {
        run_exe.addPassthruArgs();
    } else {
        if (b.args) |args| run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);
}
```

> [!IMPORTANT]
> - The dependency **name** in `b.dependency("args", ...)` must match the key in `build.zig.zon` (`.args = ...`).
> - The **module name** passed to `addImport("args", ...)` is what you use in your source code: `const args = @import("args");`.
> - `zig fetch --save` automatically adds the dependency to `build.zig.zon`. You only need to write the `build.zig` code manually.

### Verifying the Installation

Create a minimal `src/main.zig`:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "my-cli-app",
        .version = "1.0.0",
        .description = "My CLI application",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getBool("verbose") orelse false) {
        std.debug.print("Verbose mode enabled\n", .{});
    }
}
```

Run it:

```bash
zig build run -- --help
zig build run -- -v
```

### Configuration Presets

Choose a preset that matches your environment:

```zig
// Development - balanced defaults with colors (default)
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.default(),
});

// CI - no colors, explicit exit on error
var parser2 = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.ci(),
});

// Production - minimal overhead, no colors, no update checker
var parser3 = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.production(),
});

// Testing - silent errors, permissive parsing
var parser4 = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.testing(),
});
```

## Your First Parser

Create a simple command-line application with the **basic API** and process initialization context:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

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

    // Parse arguments from the current process
    var result = try parser.parseProcess(init);
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

> [!NOTE]
>
> In Zig 0.16, the `main` function signature changed to `pub fn main(init: std.process.Init) !void`.
>
> `std.process.Init` provides access to:
> - **`init.arena.allocator()`** â€” A scoped arena allocator tied to the process lifetime. Use this as your primary allocator; it is freed automatically on exit.
> - **`init.minimal.args`** â€” The process command-line arguments, exposed through Zig's minimal startup state.
> - **`init.io`** â€” A `std.Io` instance for the process, suitable for stdin, stdout, stderr, and other I/O work.
> - **`init.environ_map`** â€” The process environment map, which lets args.zig resolve environment-backed options automatically.
>
> Always pass `init` to `parser.parseProcess(init)` when you want the parser to use the process args, I/O context, and environment map directly. Use `parser.parse(&[_][]const u8{...})` when you need a custom argument list in tests, tools, or examples.

### Advanced: Using std.process.Init

For applications that need full control over process initialization:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    // Setup allocator (from process init)
    const allocator = init.arena.allocator();

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

    // Parse arguments with full process context
    var result = try parser.parseProcess(init);
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

### What You Get From `std.process.Init`

- **Process lifetime allocation** - `init.arena.allocator()` is ideal for one-shot CLI programs
- **Startup arguments** - `init.minimal.args` gives `args.zig` the exact command-line input from Zig's runtime
- **Process I/O** - `init.io` keeps parsing, help text, and related output aligned with the active process streams
- **Environment variables** - `init.environ_map` enables automatic env-var fallback when you configure `env_prefix` or `env_var`
- **One-liner parsing** - `parser.parseProcess(init)` is the simplest and most future-proof path for Zig 0.16+

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
# The help output is formatted for better understanding ðŸŽ¨
```

## Validation Commands

Use these commands while developing with args.zig:

```bash
# Run test suite for your current host target
zig build test

# Run all maintained examples
zig build run-all-examples
zig build run-update_check

# Cross-target compile checks
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-macos
```

For full runtime test execution on Linux/macOS targets, run `zig build test -Dtarget=...` on a matching host or CI runner.

## Version Information

You can access the library version in your code:

```zig
const args = @import("args");

std.debug.print("args.zig version: {s}\n", .{args.VERSION});
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

## Error Handling & Fallbacks

args.zig provides multiple levels of error handling to suit different needs:

### Automatic Exit on Error (Default)

By default, when a required argument is missing or an unknown option is provided, the parser prints a helpful error message and exits gracefully:

```zig
var parser = try args.ArgumentParser.init(allocator, .{ .name = "myapp" });
try parser.addOption("input", .{ .required = true });

// If --input is missing, the library prints help and exits with code 1
var result = try parser.parseProcess(init); // never returns on error
```

This behavior is controlled by `exit_on_error` in the config (enabled by default).

### Parse-Level Fallback (parseOr / parseProcessOr)

Use `parseOr` or `parseProcessOr` when you want to handle errors yourself instead of exiting:

```zig
// Returns an empty ParseResult instead of propagating the error
var result = parser.parseProcessOr(init, null);
defer result.deinit();

// With a custom error handler
fn onError(err: anyerror, parser: *ArgumentParser) void {
    std.debug.print("Parsing failed: {}\n", .{err});
}
var result2 = parser.parseProcessOr(init, onError);
defer result2.deinit();
```

### Value-Level Fallback (getOr* Methods)

For individual argument values, use the `getOr*` family of methods to provide inline defaults:

```zig
const verbose = result.getOrBool("verbose", false);
const count = result.getOrInt("count", 42);
const output = result.getOrString("output", "default.txt");
const threshold = result.getOrFloat("threshold", 0.5);
const workers = result.getOrUint("workers", 4);
```

### Environment Variable Fallback

Options can fall back to environment variables automatically:

```zig
try parser.addOption("token", .{
    .help = "API token",
    .env_var = "API_TOKEN", // Falls back to $API_TOKEN if not provided on CLI
});
```

### Custom Validator Error Handling

Validators return detailed error messages that are integrated with the parser's error output:

```zig
try parser.addIntOption("port", .{
    .min = 1024,
    .max = 65535,
    .help = "Port number (1024-65535)",
    .required = true,
});
```

## Next Steps

- Learn about [Options and Flags](/guide/options-flags)
- Try [Declarative Structs](/guide/declarative-structs) for rapid prototyping
- Explore [Subcommands](/guide/subcommands)
- Configure [Environment Variables](/guide/environment-variables)
- Understand [Error Handling & Fallbacks](#error-handling--fallbacks) above
- Check the [API Reference](/api/parser) for full method documentation
