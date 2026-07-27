---
title: Declarative Structs
description: Learn how to use Zig structs to define CLI arguments declaratively and parse them directly into struct instances.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, declarative parsing, struct parsing, parseInto, derive, auto-derivation
---

# Declarative Structs

Instead of manually adding options one by one, `args.zig` allows you to define your configuration as a standard Zig struct and parse arguments directly into it using `parseInto` (or its alias `derive`).

> [!TIP]
> For the simplest syntax when parsing process args, use `parseProcessInto`:
> ```zig
> var parsed = try args.parseProcessInto(allocator, Config, .{ .name = "myapp" }, init);
> ```
> Or use `parseInto` with `null` for the same result:
> ```zig
> var parsed = try args.parseInto(allocator, Config, .{ .name = "myapp" }, null, init);
> ```

## Use Cases

This approach is ideal for:

1. **Configuration-Driven CLIs** - Define your app's entire config as a struct
2. **Rapid Prototyping** - Quickly define CLI from a single struct definition
3. **Type-Safe Argument Handling** - No manual type conversion or string lookups
4. **Self-Documenting Code** - The struct definition shows exactly what CLI options exist
5. **Compile-Time Validation** - Errors caught at build time, not runtime

## How it Works

The library inspects your struct fields at compile-time and generates the corresponding `ArgSpec` list.

> [!NOTE]
> Field names are automatically converted to kebab-case (e.g., `dry_run` becomes `--dry-run`). Types are mapped to the appropriate argument type at compile-time.

- **Field Names**: Converted to kebab-case (e.g., `dry_run` becomes `--dry-run`).
- **Types**: Mapped to argument types:
    - `bool` → Flag (`.action = .store_true`)
    - `?[]const u8` → Optional String Option
    - `i32`, `i64` → Integer Option
    - `f32`, `f64` → Float Option
    - `?T` → Optional (not required)
    - `T` (non-bool) → Required Option

## Supported Field Types

| Zig Type | CLI Behavior | Example Usage |
|----------|-------------|---------------|
| `bool` | Flag, defaults to `false` | `--verbose` |
| `?bool` | Optional flag | `--debug` |
| `[]const u8` | Required string | `--name value` |
| `?[]const u8` | Optional string | `--output file.txt` |
| `i32`, `i64` | Required integer | `--count 42` |
| `?i32`, `?i64` | Optional integer | `--port 8080` |
| `f32`, `f64` | Required float | `--rate 0.5` |
| `?f64` | Optional float | `--timeout 30.5` |

## Basic Example

```zig
const std = @import("std");
const args = @import("args");

// Define your configuration struct
const Config = struct {
    // Flags (bool)
    verbose: bool,
    dry_run: bool,
    
    // Optional string options
    output: ?[]const u8,
    config_file: ?[]const u8,
    
    // Optional numeric options
    timeout: ?f64,
    port: ?i32,
    
    // Required options (non-optional)
    count: i32,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parsed = try args.parseInto(allocator, Config, .{
        .name = "myapp",
        .description = "Struct-based parsing demo",
    }, null, init);
    defer parsed.deinit();

    const cfg = parsed.options;

    std.debug.print("Verbose: {}\n", .{cfg.verbose});
    std.debug.print("Dry Run: {}\n", .{cfg.dry_run});
    std.debug.print("Count: {d}\n", .{cfg.count});
    
    if (cfg.output) |out| {
        std.debug.print("Output: {s}\n", .{out});
    }
    
    if (cfg.port) |p| {
        std.debug.print("Port: {d}\n", .{p});
    }
}
```

## Running

```bash
$ myapp --count 42 --verbose
Verbose: true
Dry Run: false
Count: 42

$ myapp --count 10 --output result.txt --dry-run --port 8080
Verbose: false
Dry Run: true
Count: 10
Output: result.txt
Port: 8080
```

## Limitations and How to Handle Complex Cases

> [!WARNING]
> The `parseInto` approach is designed for simple to moderately complex CLIs. For advanced use cases (multi-value options, choices, subcommands), combine with the `ArgumentParser` API.

### Limitation 1: No Multi-Value Options

Struct-based parsing doesn't support repeatable options (like `-I path1 -I path2`). For this, use the traditional API:

```zig
// Instead of parseInto, use ArgumentParser directly:
var parser = try args.createParser(allocator, "myapp");
defer parser.deinit();

try parser.addAppend("include", .{ .short = 'I', .help = "Include paths" });

var result = try parser.parseProcess(init);
defer result.deinit();

// Access multiple values
const includes = result.getArray("include"); // Returns slice of values
```

### Limitation 2: No Choices or Validation

Struct fields don't support `choices` or custom validators. Use the traditional API:

```zig
var parser = try args.createParser(allocator, "myapp");
defer parser.deinit();

try parser.addOption("level", .{
    .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
});
```

### Limitation 3: No Subcommands

For subcommands, use the traditional `ArgumentParser` API:

```zig
try parser.addSubcommand(.{
    .name = "build",
    .help = "Build the project",
    .args = &[_]args.ArgSpec{
        .{ .name = "target", .positional = true },
    },
});
```

## Hybrid Approach: Combining Both Methods

> [!TIP]
> You can use the derived specs as a starting point and add more options manually:

```zig
const Config = struct {
    verbose: bool,
    count: i32,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.createParser(allocator, "myapp");
    defer parser.deinit();
    
    // Add derived options from struct
    const specs = args.deriveOptions(Config);
    for (specs) |spec| {
        try parser.addArg(spec);
    }
    
    // Add additional options not in the struct
    try parser.addOption("level", .{
        .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
    });
    try parser.addAppend("include", .{ .short = 'I' });
    
    var result = try parser.parseProcess(init);
    defer result.deinit();
    
    // Access values manually
    const verbose = result.getBool("verbose") orelse false;
    const count = result.getInt("count") orelse 0;
    const level = result.getString("level");
}
```

## Using the `derive` Alias

For a more concise API, use the `derive` alias:

```zig
// These are equivalent:
var parsed = try args.parseInto(allocator, Config, options, null, init);
var parsed = try args.derive(allocator, Config, options, null, init);

// Or use parseProcessInto / deriveProcess for shorter syntax:
var parsed = try args.parseProcessInto(allocator, Config, options, init);
var parsed = try args.deriveProcess(allocator, Config, options, init);
```

## Using Global Configuration

`parseInto` respects the global configuration. You can centralize app metadata:

```zig
// Set once at application start
args.configure(.{
    .app_name = "myapp",
    .app_version = "1.0.0",
    .app_description = "My CLI tool",
});

// parseInto will use these defaults
var parsed = try args.parseInto(allocator, Config, .{
    .name = "", // Uses app_name from global config
}, null, init);
defer parsed.deinit();
```

## Advanced: Accessing Raw Parse Result

The returned `ParseIntoResult` contains both the typed options and the raw parse result:

```zig
var parsed = try args.parseInto(allocator, Config, options, null, init);
defer parsed.deinit();

// Typed access (from struct)
const cfg = parsed.options;

// Raw access (for additional features)
const remaining = parsed.result.remaining; // Unparsed/remaining args
const subcommand = parsed.result.subcommand; // If subcommand was used
```

## When to Use Each Approach

| Use Case | Recommended Approach |
|----------|---------------------|
| Simple config with flags and options | `parseInto` / `derive` |
| Need choices or validation | `ArgumentParser` with `addOption` |
| Multi-value options (`-I a -I b`) | `ArgumentParser` with `addAppend` |
| Subcommands | `ArgumentParser` with `addSubcommand` |
| Rapid prototyping | `parseInto` / `derive` |
| Production CLI with all features | `ArgumentParser` (full control) |
| Mix of simple and complex | Hybrid (use both) |
