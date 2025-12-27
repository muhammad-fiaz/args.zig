---
title: Subcommands
description: Learn how to create Git-style subcommands in args.zig. Nested commands, aliases, and subcommand argument parsing.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, subcommands, nested commands, cli subcommands, git style
---

# Subcommands

args.zig supports Git-style subcommands for organizing complex CLI applications.

## Basic Subcommands

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "mycli",
    .version = "1.0.0",
    .description = "CLI with subcommands",
});
defer parser.deinit();

// Add subcommands
try parser.addSubcommand(.{
    .name = "init",
    .help = "Initialize a new project",
});

try parser.addSubcommand(.{
    .name = "build",
    .help = "Build the project",
});

try parser.addSubcommand(.{
    .name = "test",
    .help = "Run tests",
});
```

Usage:
```bash
mycli init
mycli build
mycli test
```

## Subcommands with Arguments

Each subcommand can have its own arguments:

```zig
try parser.addSubcommand(.{
    .name = "clone",
    .help = "Clone a repository",
    .args = &[_]args.ArgSpec{
        .{ .name = "url", .positional = true, .required = true, .help = "Repository URL" },
        .{ .name = "directory", .positional = true, .help = "Target directory" },
        .{ .name = "depth", .short = 'd', .long = "depth", .value_type = .int, .help = "Clone depth" },
        .{ .name = "branch", .short = 'b', .long = "branch", .help = "Branch to clone" },
    },
});
```

Usage:
```bash
mycli clone https://github.com/user/repo.git
mycli clone https://github.com/user/repo.git myproject
mycli clone -b main --depth 1 https://github.com/user/repo.git
```

## Subcommand Aliases

```zig
try parser.addSubcommand(.{
    .name = "install",
    .help = "Install dependencies",
    .aliases = &[_][]const u8{ "i", "add" },
});
```

Usage:
```bash
mycli install
mycli i          # Same as install
mycli add        # Same as install
```

## Handling Subcommands

```zig
var result = try parser.parseProcess();
defer result.deinit();

if (result.subcommand) |cmd| {
    const sub_args = result.subcommand_args.?;

    if (std.mem.eql(u8, cmd, "clone")) {
        const url = sub_args.getString("url").?;
        const dir = sub_args.getString("directory");
        const depth = sub_args.getInt("depth");
        const branch = sub_args.getString("branch");

        std.debug.print("Cloning {s}", .{url});
        if (dir) |d| std.debug.print(" into {s}", .{d});
        if (branch) |b| std.debug.print(" (branch: {s})", .{b});
        if (depth) |de| std.debug.print(" (depth: {d})", .{de});
        std.debug.print("\n", .{});
    } else if (std.mem.eql(u8, cmd, "build")) {
        // Handle build
    } else if (std.mem.eql(u8, cmd, "test")) {
        // Handle test
    }
} else {
    // No subcommand provided - show help
    try parser.printHelp();
}
```

## Global Options with Subcommands

Options defined before subcommands are global:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "mycli",
});

// Global options
try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
try parser.addOption("config", .{ .short = 'c', .help = "Config file" });

// Subcommands
try parser.addSubcommand(.{
    .name = "deploy",
    .help = "Deploy application",
    .args = &[_]args.ArgSpec{
        .{ .name = "environment", .positional = true, .required = true },
    },
});
```

Usage:
```bash
mycli -v --config prod.yml deploy production
```

Access:
```zig
// Global options from main result
const verbose = result.getBool("verbose") orelse false;
const config = result.getString("config");

// Subcommand args from subcommand_args
if (result.subcommand_args) |sub| {
    const env = sub.getString("environment");
}
```

## Hidden Subcommands

```zig
try parser.addSubcommand(.{
    .name = "internal-debug",
    .help = "Internal debugging command",
    .hidden = true,  // Won't appear in help
});
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "git-like",
        .version = "1.0.0",
        .description = "A Git-like CLI example",
    });
    defer parser.deinit();

    // Global options
    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });

    // Subcommands
    try parser.addSubcommand(.{
        .name = "init",
        .help = "Initialize a new repository",
        .args = &[_]args.ArgSpec{
            .{ .name = "bare", .long = "bare", .action = .store_true, .help = "Create bare repo" },
        },
    });

    try parser.addSubcommand(.{
        .name = "clone",
        .help = "Clone a repository",
        .aliases = &[_][]const u8{"cl"},
        .args = &[_]args.ArgSpec{
            .{ .name = "url", .positional = true, .required = true, .help = "Repository URL" },
            .{ .name = "dir", .positional = true, .help = "Target directory" },
        },
    });

    try parser.addSubcommand(.{
        .name = "commit",
        .help = "Record changes",
        .aliases = &[_][]const u8{"ci"},
        .args = &[_]args.ArgSpec{
            .{ .name = "message", .short = 'm', .long = "message", .required = true, .help = "Commit message" },
            .{ .name = "all", .short = 'a', .long = "all", .action = .store_true, .help = "Commit all changes" },
        },
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;

    if (result.subcommand) |cmd| {
        const sub = result.subcommand_args.?;

        if (std.mem.eql(u8, cmd, "init")) {
            const bare = sub.getBool("bare") orelse false;
            std.debug.print("Initializing repository{s}\n", .{
                if (bare) " (bare)" else ""
            });
        } else if (std.mem.eql(u8, cmd, "clone")) {
            const url = sub.getString("url").?;
            std.debug.print("Cloning {s}\n", .{url});
        } else if (std.mem.eql(u8, cmd, "commit")) {
            const msg = sub.getString("message").?;
            std.debug.print("Committing: {s}\n", .{msg});
        }
    } else {
        try parser.printHelp();
    }

    if (verbose) {
        std.debug.print("(verbose mode)\n", .{});
    }
}
```
