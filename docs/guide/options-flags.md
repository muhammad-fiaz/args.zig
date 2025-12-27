---
title: Options & Flags
description: Learn how to define options, flags, and positional arguments in args.zig. Comprehensive guide to argument types and configurations.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, options, flags, positional arguments, cli options
---

# Options & Flags

This guide covers how to define various types of command-line arguments in args.zig.

## Flags (Boolean Options)

Flags are boolean options that don't require a value:

```zig
try parser.addFlag("verbose", .{
    .short = 'v',
    .help = "Enable verbose output",
});

try parser.addFlag("quiet", .{
    .short = 'q',
    .help = "Suppress output",
});
```

Usage:
```bash
myapp -v           # verbose = true
myapp --verbose    # verbose = true
myapp -vq          # verbose = true, quiet = true (clustered)
```

## Options (Value-Taking Arguments)

Options accept a value:

```zig
try parser.addOption("output", .{
    .short = 'o',
    .help = "Output file path",
});

try parser.addOption("count", .{
    .short = 'n',
    .help = "Number of iterations",
    .value_type = .int,
    .default = "10",
});
```

Usage:
```bash
myapp -o file.txt
myapp --output file.txt
myapp --output=file.txt     # inline value
myapp -n 5
```

## Positional Arguments

Arguments without flags:

```zig
try parser.addPositional("input", .{
    .help = "Input file to process",
    .required = true,
});

try parser.addPositional("output", .{
    .help = "Output file (optional)",
    .required = false,
    .default = "output.txt",
});
```

Usage:
```bash
myapp input.txt              # input = "input.txt"
myapp input.txt result.txt   # input = "input.txt", output = "result.txt"
```

## Value Types

args.zig supports multiple value types:

| Type | Description | Example |
|------|-------------|---------|
| `.string` | Text value (default) | `--name Alice` |
| `.int` | Signed integer | `--count -5` |
| `.uint` | Unsigned integer | `--port 8080` |
| `.float` | Floating point | `--rate 0.5` |
| `.bool` | Boolean | `--flag true` |
| `.path` | File/directory path | `--config ./config.yml` |
| `.counter` | Incremented count | `-v -v -v` |

```zig
try parser.addOption("port", .{
    .short = 'p',
    .value_type = .int,
    .help = "Server port",
});

try parser.addOption("rate", .{
    .value_type = .float,
    .help = "Processing rate",
});
```

## Counters

Count how many times a flag is used:

```zig
try parser.addCounter("verbose", .{
    .short = 'v',
    .help = "Increase verbosity (can be repeated)",
});
```

Usage:
```bash
myapp -v      # verbose = 1
myapp -vv     # verbose = 2
myapp -vvv    # verbose = 3
```

Access:
```zig
const val = result.get("verbose").?;
const level = val.counter; // 0, 1, 2, 3, etc.
```

## Choices

Restrict values to a predefined set:

```zig
try parser.addOption("level", .{
    .short = 'l',
    .help = "Log level",
    .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
});

try parser.addOption("format", .{
    .short = 'f',
    .help = "Output format",
    .choices = &[_][]const u8{ "json", "xml", "csv", "yaml" },
});
```

## Multiple Values

Accept multiple values for a single option:

```zig
// Accepts 1 to 3 integers: --numbers 1 2 3
try parser.addMultiple("numbers", .{
    .short = 'n',
    .help = "List of numbers",
    .min = 1,
    .max = 3,
});
```

## Appended Values

Collect same flag multiple times:

```zig
// --include path1 --include path2
try parser.addAppend("include", .{
    .short = 'I',
    .help = "Include path",
});
```

## Required vs Optional

```zig
// Required option
try parser.addOption("config", .{
    .short = 'c',
    .help = "Configuration file",
    .required = true,
});

// Optional with default
try parser.addOption("timeout", .{
    .help = "Timeout in seconds",
    .value_type = .int,
    .default = "30",
});
```

## Environment Variable Fallback

```zig
try parser.addOption("token", .{
    .help = "API authentication token",
    .env_var = "API_TOKEN",
    .required = true,
});
```

If `--token` is not provided, the parser checks `$API_TOKEN`.

## Hidden Options

Options that don't appear in help text:

```zig
try parser.addOption("debug-internal", .{
    .help = "Internal debugging",
    .hidden = true,
});
```

## Deprecated Options

Mark options as deprecated:

```zig
try parser.addOption("old-format", .{
    .help = "Use old format",
    .deprecated = "Use --format instead",
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
        .name = "myapp",
        .version = "1.0.0",
        .description = "Example application",
    });
    defer parser.deinit();

    // Flags
    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
    try parser.addFlag("dry-run", .{ .short = 'n', .help = "Dry run mode" });
    
    // Options
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });
    try parser.addOption("count", .{ .short = 'c', .value_type = .int, .default = "1" });
    try parser.addOption("format", .{ 
        .short = 'f', 
        .choices = &[_][]const u8{ "json", "csv" } 
    });
    
    // Counter
    try parser.addCounter("debug", .{ .short = 'd', .help = "Debug level" });
    
    // Positional
    try parser.addPositional("input", .{ .help = "Input file", .required = true });

    var result = try parser.parseProcess();
    defer result.deinit();

    // Access values
    const verbose = result.getBool("verbose") orelse false;
    const count = result.getInt("count") orelse 1;
    const input = result.getString("input").?;
    
    std.debug.print("verbose={}, count={d}, input={s}\n", .{verbose, count, input});
}
```
