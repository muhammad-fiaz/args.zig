---
title: Examples
description: Comprehensive examples demonstrating all args.zig features including basic usage, advanced patterns, and real-world scenarios.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, examples, tutorials, cli examples, usage patterns
---

# Examples

This page provides comprehensive examples demonstrating args.zig features.

## Basic Example

A simple CLI with flags, options, and positional arguments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "greet",
        .version = "1.0.0",
        .description = "A friendly greeting application",
    });
    defer parser.deinit();

    // Boolean flag
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    // String option with default
    try parser.addOption("name", .{
        .short = 'n',
        .help = "Name to greet",
        .default = "World",
    });

    // Required positional argument
    try parser.addPositional("message", .{
        .help = "Greeting message",
        .required = true,
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const name = result.getString("name") orelse "World";
    const message = result.getString("message").?;

    if (verbose) {
        std.debug.print("[VERBOSE] Preparing greeting...\n", .{});
    }

    std.debug.print("{s}, {s}!\n", .{ message, name });
}
```

**Usage:**
```bash
greet "Hello"              # Output: Hello, World!
greet -n Alice "Hi"        # Output: Hi, Alice!
greet -v --name Bob "Hey"  # [VERBOSE] Preparing... / Hey, Bob!
```

## Subcommands Example

Git-style subcommands with their own arguments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "mycli",
        .version = "2.0.0",
        .description = "A CLI with subcommands",
    });
    defer parser.deinit();

    // Global flag
    try parser.addFlag("verbose", .{ .short = 'v' });

    // Add 'init' subcommand
    try parser.addSubcommand(.{
        .name = "init",
        .help = "Initialize a new project",
        .aliases = &[_][]const u8{"i"},
        .args = &[_]args.ArgSpec{
            .{ .name = "name", .positional = true, .required = true, .help = "Project name" },
            .{ .name = "template", .short = 't', .long = "template", .default = "basic" },
        },
    });

    // Add 'build' subcommand
    try parser.addSubcommand(.{
        .name = "build",
        .help = "Build the project",
        .aliases = &[_][]const u8{"b"},
        .args = &[_]args.ArgSpec{
            .{ .name = "release", .short = 'r', .long = "release", .action = .store_true },
            .{ .name = "target", .long = "target", .default = "native" },
        },
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;

    if (result.subcommand) |cmd| {
        const sub = result.subcommand_args.?;

        if (std.mem.eql(u8, cmd, "init")) {
            const name = sub.getString("name").?;
            const template = sub.getString("template") orelse "basic";
            std.debug.print("Initializing '{s}' with template '{s}'\n", .{ name, template });
        } else if (std.mem.eql(u8, cmd, "build")) {
            const release = sub.getBool("release") orelse false;
            const target = sub.getString("target") orelse "native";
            const mode = if (release) "release" else "debug";
            std.debug.print("Building in {s} mode for {s}\n", .{ mode, target });
        }

        if (verbose) std.debug.print("(verbose mode)\n", .{});
    } else {
        try parser.printHelp();
    }
}
```

**Usage:**
```bash
mycli init myproject              # Initialize 'myproject' with template 'basic'
mycli i myapp -t advanced         # Initialize 'myapp' with template 'advanced'
mycli build --release             # Building in release mode for native
mycli -v build --target aarch64   # Building in debug mode for aarch64 (verbose mode)
```

## Environment Variables Example

Using environment variables as fallback values:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "server",
        .description = "A server with environment variable configuration",
    });
    defer parser.deinit();

    // Options with environment variable fallback
    try parser.addOption("host", .{
        .short = 'H',
        .help = "Server hostname",
        .env_var = "SERVER_HOST",
        .default = "0.0.0.0",
    });

    try parser.addOption("port", .{
        .short = 'p',
        .help = "Server port",
        .value_type = .int,
        .env_var = "SERVER_PORT",
        .default = "8080",
    });

    try parser.addOption("secret", .{
        .help = "Secret key (required)",
        .env_var = "SERVER_SECRET",
        .required = true,
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const host = result.getString("host").?;
    const port = result.getInt("port").?;
    const secret = result.getString("secret").?;

    std.debug.print("Starting server on {s}:{d}\n", .{ host, port });
    std.debug.print("Secret: {s}...\n", .{secret[0..@min(4, secret.len)]});
}
```

**Usage:**
```bash
# Using environment variables
export SERVER_SECRET="my-secret-key"
export SERVER_PORT="3000"
server --host 127.0.0.1

# Using command line (overrides env vars)
server --secret "cli-secret" --port 9000
```

## Counters and Choices Example

Using counters for verbosity and choices for validation:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "logger",
        .description = "A logging utility with verbosity levels",
    });
    defer parser.deinit();

    // Counter: -v, -vv, -vvv for increasing verbosity
    try parser.addCounter("verbose", .{
        .short = 'v',
        .help = "Increase verbosity (can be repeated)",
    });

    // Choices: restricted set of valid values
    try parser.addOption("level", .{
        .short = 'l',
        .help = "Log level",
        .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
        .default = "info",
    });

    try parser.addOption("format", .{
        .short = 'f',
        .help = "Output format",
        .choices = &[_][]const u8{ "json", "text", "csv" },
        .default = "text",
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const verbose_val = result.get("verbose");
    const verbosity: u32 = if (verbose_val) |v| v.counter else 0;
    const level = result.getString("level") orelse "info";
    const format = result.getString("format") orelse "text";

    std.debug.print("Verbosity level: {d}\n", .{verbosity});
    std.debug.print("Log level: {s}\n", .{level});
    std.debug.print("Output format: {s}\n", .{format});

    if (verbosity >= 1) std.debug.print("  [v] Basic verbose info\n", .{});
    if (verbosity >= 2) std.debug.print("  [vv] Detailed verbose info\n", .{});
    if (verbosity >= 3) std.debug.print("  [vvv] Maximum verbosity\n", .{});
}
```

**Usage:**
```bash
logger                      # Verbosity: 0, level: info, format: text
logger -v                   # Verbosity: 1
logger -vv                  # Verbosity: 2
logger -vvv -l debug        # Verbosity: 3, level: debug
logger --level error        # level: error
logger -f json              # format: json
```

## Shell Completions Example

Generating shell completion scripts:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o' });

    // Add completion subcommand
    try parser.addSubcommand(.{
        .name = "completion",
        .help = "Generate shell completion script",
        .args = &[_]args.ArgSpec{
            .{ .name = "shell", .positional = true, .required = true },
        },
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    if (result.subcommand) |cmd| {
        if (std.mem.eql(u8, cmd, "completion")) {
            const shell_str = result.subcommand_args.?.getString("shell").?;

            if (args.Shell.fromString(shell_str)) |shell| {
                const script = try parser.generateCompletion(shell);
                defer allocator.free(script);

                const stdout = std.io.getStdOut().writer();
                try stdout.writeAll(script);
            } else {
                std.debug.print("Unknown shell: {s}\n", .{shell_str});
                std.debug.print("Supported: bash, zsh, fish, powershell\n", .{});
            }
        }
    }
}
```

**Usage:**
```bash
# Generate and install Bash completions
myapp completion bash > ~/.local/share/bash-completion/completions/myapp

# Generate and install Zsh completions
myapp completion zsh > ~/.zfunc/_myapp

# Generate and install Fish completions
myapp completion fish > ~/.config/fish/completions/myapp.fish
```

## Disabling Update Checker

For production or CI/CD environments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Method 1: Global disable
    args.disableUpdateCheck();

    // Method 2: Use minimal config
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "production-app",
        .config = args.Config.minimal(),
    });
    defer parser.deinit();

    // Your argument definitions...
}
```

## Running the Examples

Build and run examples with:

```bash
# Build all examples
zig build

# Run basic example
zig build run-basic -- -v --output result.txt input.txt

# Run advanced example
zig build run-advanced -- init myproject --template advanced

# Run update check example
zig build run-update-check
```
