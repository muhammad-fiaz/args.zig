---
title: Schema Builder
description: Guide for programmatic schema construction with SchemaBuilder in args.zig. Build CommandSpec objects with a fluent API.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, SchemaBuilder, schema, builder, fluent api, programmatic
---

# Schema Builder

`SchemaBuilder` provides a fluent API for constructing `CommandSpec` schemas programmatically. It is useful when argument definitions are built dynamically (e.g., from configuration files or plugin systems) rather than declared at compile time.

## When to Use SchemaBuilder

- Schema is loaded from external data (JSON, YAML, config files)
- Arguments are added dynamically based on runtime conditions
- Building a library or framework that exposes argument configuration to users

> [!TIP]
> For most applications, prefer `ArgumentParser` directly or `args.parseInto` with struct derivation. `SchemaBuilder` is for advanced programmatic use cases.

## Basic Usage

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var builder = args.SchemaBuilder.init(allocator, "myapp");
    defer builder.deinit();

    _ = builder
        .setVersion("1.0.0")
        .setDescription("My application");

    _ = try builder.addFlag("verbose", 'v', "Enable verbose output");
    _ = try builder.addOption("output", 'o', "Output file path");
    _ = try builder.addPositional("input", "Input file path");

    const spec = builder.build();

    // Use the spec with a parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = spec.name,
        .version = spec.version,
        .description = spec.description,
    });
    defer parser.deinit();

    for (spec.args) |arg| {
        try parser.addArg(arg);
    }
    // ... parse and use results
}
```

## API Reference

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, name: []const u8) SchemaBuilder
```

Creates a new builder for the given program name.

### `deinit`

```zig
pub fn deinit(self: *SchemaBuilder) void
```

Frees all resources owned by the builder.

### `setVersion`

```zig
pub fn setVersion(self: *SchemaBuilder, ver: []const u8) *SchemaBuilder
```

Sets the version string. Returns `self` for chaining.

### `setDescription`

```zig
pub fn setDescription(self: *SchemaBuilder, desc: []const u8) *SchemaBuilder
```

Sets the program description. Returns `self` for chaining.

### `setEpilog`

```zig
pub fn setEpilog(self: *SchemaBuilder, ep: []const u8) *SchemaBuilder
```

Sets the epilog text (displayed after help). Returns `self` for chaining.

### `addFlag`

```zig
pub fn addFlag(self: *SchemaBuilder, name: []const u8, short: ?u8, help_text: ?[]const u8) !*SchemaBuilder
```

Adds a boolean flag argument. Returns `self` for chaining.

### `addOption`

```zig
pub fn addOption(self: *SchemaBuilder, name: []const u8, short: ?u8, help_text: ?[]const u8) !*SchemaBuilder
```

Adds a value-taking option argument. Returns `self` for chaining.

### `addPositional`

```zig
pub fn addPositional(self: *SchemaBuilder, name: []const u8, help_text: ?[]const u8) !*SchemaBuilder
```

Adds a required positional argument. Returns `self` for chaining.

### `addArg`

```zig
pub fn addArg(self: *SchemaBuilder, spec: ArgSpec) !*SchemaBuilder
```

Adds a fully specified argument. Returns `self` for chaining.

> [!NOTE]
> `addArg` accepts an `ArgSpec` with all fields available (validators, choices, conflicts, etc.). Use this when you need full control over the argument specification.

### `addSubcommand`

```zig
pub fn addSubcommand(self: *SchemaBuilder, spec: SubcommandSpec) !*SchemaBuilder
```

Adds a subcommand with its own arguments. Returns `self` for chaining.

### `build`

```zig
pub fn build(self: *SchemaBuilder) CommandSpec
```

Builds and returns the final `CommandSpec`. The returned spec borrows from the builder's internal slices — do not use the spec after the builder is deinitialized.

## Chaining Example

```zig
var builder = args.SchemaBuilder.init(allocator, "deploy");
defer builder.deinit();

_ = try builder
    .setVersion("2.1.0")
    .setDescription("Deployment tool")
    .setEpilog("For more info visit docs.example.com")
    .addFlag("dry-run", 'd', "Preview changes without applying")
    .addFlag("verbose", 'v', "Verbose output")
    .addOption("config", 'c', "Config file path")
    .addOption("env", 'e', "Target environment")
    .addPositional("service", "Service name to deploy")
    .addSubcommand(.{
        .name = "rollback",
        .help = "Rollback to previous version",
        .args = &[_]args.ArgSpec{
            .{ .name = "revision", .positional = true, .help = "Revision to rollback to" },
        },
    });

const spec = builder.build();
```

## Building a Parser from a Schema

```zig
var builder = args.SchemaBuilder.init(allocator, "mytool");
defer builder.deinit();

_ = try builder
    .setVersion("1.0.0")
    .addFlag("quiet", 'q', "Suppress output")
    .addOption("format", 'f', "Output format (json, text)")
    .addPositional("source", "Source file");

const spec = builder.build();

// Create parser from the built spec
var parser = try args.ArgumentParser.init(allocator, .{
    .name = spec.name,
    .version = spec.version,
    .description = spec.description,
});
defer parser.deinit();

for (spec.args) |arg| {
    try parser.addArg(arg);
}

for (spec.subcommands) |sub| {
    try parser.addSubcommand(sub);
}

var result = try parser.parseProcess(init);
defer result.deinit();
```

## SchemaBuilder vs ArgumentParser

| Feature | `SchemaBuilder` | `ArgumentParser` |
|---------|----------------|------------------|
| Fluent API | Yes | Partially (add methods) |
| Builds `CommandSpec` | Yes | Yes (via `buildSpec`) |
| Direct parsing | No | Yes (`parse`, `parseProcess`) |
| Help generation | No | Yes (`getHelp`, `printHelp`) |
| Config/groups | No | Yes (`addArgumentGroup`) |
| Dynamic schemas | Primary use case | Not ideal |

> [!TIP]
> If you need to parse arguments immediately after defining them, use `ArgumentParser` directly. `SchemaBuilder` is best when you need to construct a `CommandSpec` first and hand it off to other code.

## Test Reference

```zig
test "SchemaBuilder builds correct spec" {
    const allocator = std.testing.allocator;

    var builder = args.SchemaBuilder.init(allocator, "test-app");
    defer builder.deinit();

    _ = builder.setVersion("0.1.0").setDescription("Test");
    _ = try builder.addFlag("debug", 'd', "Debug mode");
    _ = try builder.addOption("port", 'p', "Port number");
    _ = try builder.addPositional("host", "Hostname");

    const spec = builder.build();

    try std.testing.expectEqualStrings("test-app", spec.name);
    try std.testing.expectEqualStrings("0.1.0", spec.version.?);
    try std.testing.expectEqual(@as(usize, 3), spec.args.len);
    try std.testing.expect(!spec.hasSubcommands());
}

test "SchemaBuilder with subcommands" {
    const allocator = std.testing.allocator;

    var builder = args.SchemaBuilder.init(allocator, "cli");
    defer builder.deinit();

    _ = try builder.addSubcommand(.{
        .name = "init",
        .help = "Initialize project",
    });
    _ = try builder.addSubcommand(.{
        .name = "build",
        .help = "Build project",
    });

    const spec = builder.build();
    try std.testing.expect(spec.hasSubcommands());
    try std.testing.expectEqual(@as(usize, 2), spec.subcommands.len);
}
```
