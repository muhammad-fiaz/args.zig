---
title: ArgumentParser Export API
description: API reference for ArgumentParser introspection and export methods.
---

# ArgumentParser Export API

The `ArgumentParser` provides introspection methods to enumerate and inspect all registered argument definitions at runtime.

## Methods

### getAllArgs

```zig
pub fn getAllArgs(self: *const ArgumentParser) []const ArgSpec
```

Returns a read-only slice of every registered `ArgSpec`. The returned pointers remain valid until the parser is deinitialised or the argument list is mutated.

### getAllSubcommands

```zig
pub fn getAllSubcommands(self: *const ArgumentParser) []const SubcommandSpec
```

Returns a read-only slice of every registered `SubcommandSpec`.

### getAllGroups

```zig
pub fn getAllGroups(self: *const ArgumentParser) []const ArgumentGroup
```

Returns a read-only slice of every registered `ArgumentGroup`.

### getAllMutualExclusions

```zig
pub fn getAllMutualExclusions(self: *const ArgumentParser) []const []const []const u8
```

Returns the mutual-exclusion groups (each group is a slice of arg names).

### exportSpec

```zig
pub fn exportSpec(self: *ArgumentParser) CommandSpec
```

Builds and returns the full `CommandSpec` snapshot.

### getArgSpec

```zig
pub fn getArgSpec(self: *const ArgumentParser, name: []const u8) ?ArgSpec
```

Looks up a single `ArgSpec` by name, long flag, destination, or alias. Returns `null` if no match.

### totalArgCount

```zig
pub fn totalArgCount(self: *const ArgumentParser) usize
```

Returns the number of registered arguments (including hidden ones).

### totalSubcommandCount

```zig
pub fn totalSubcommandCount(self: *const ArgumentParser) usize
```

Returns the number of registered subcommands.

### totalGroupCount

```zig
pub fn totalGroupCount(self: *const ArgumentParser) usize
```

Returns the number of registered argument groups.

## Related Methods

### buildSpec

```zig
pub fn buildSpec(self: *ArgumentParser) CommandSpec
```

Builds the internal `CommandSpec` snapshot. `exportSpec` is a convenience alias for this.
