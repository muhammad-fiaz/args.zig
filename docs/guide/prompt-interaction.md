---
title: Interactive Prompt Resolution
description: Guide for interactive select/all prompt flows in args.zig. Fallback prompts when --select/--all flags are missing.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, prompt, interactive, select, all, question flow
---

# Interactive Prompt Resolution

When building CMD-style tools, you often need the user to choose between `--select <target>` and `--all`. If neither flag is provided, args.zig can fall back to an interactive terminal prompt.

## Overview

The prompt system works in three stages:

1. Parse the command line for `--select` / `--all` flags
2. If both are missing, display a numbered menu and read user input
3. Return a `PromptSelectOrAllDecision` indicating the choice

## Quick Start

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "mytool",
    });
    defer parser.deinit();

    // Add the exclusive --select/--all pair
    try parser.addSelectOrAll(.{
        .select_short = 's',
        .all_short = 'a',
        .select_choices = &[_][]const u8{ "users", "groups", "logs" },
    });

    var parsed = try parser.parseProcess(init);
    defer parsed.deinit();

    // Resolve with interactive fallback
    const decision = try args.resolveSelectOrAllWithPrompt(&parsed, .{
        .question = "Select target to process",
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .default_choice = "users",
        .allow_all = true,
        .max_attempts = 3,
    }, init.io);

    switch (decision) {
        .all => std.debug.print("Processing all targets\n", .{}),
        .selected => |name| std.debug.print("Processing: {s}\n", .{name}),
    }
}
```

## API Reference

### `resolveSelectOrAllWithPrompt`

```zig
pub fn resolveSelectOrAllWithPrompt(
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    io: std.Io,
) !PromptSelectOrAllDecision
```

Resolves the selection using parsed CLI values first. If neither `--select` nor `--all` was provided, displays an interactive prompt on stdin/stdout.

**Parameters:**
- `parsed` — The parse result from a previous `parse()` or `parseProcess()` call
- `options` — Prompt configuration (choices, question text, etc.)
- `io` — The I/O context (typically `init.io` from your `main` function)

### `resolveSelectOrAllWithPromptIO`

```zig
pub fn resolveSelectOrAllWithPromptIO(
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
) !PromptSelectOrAllDecision
```

Same behavior as `resolveSelectOrAllWithPrompt`, but accepts explicit reader/writer references. This variant is useful for:

- Unit testing with fixed input
- Embedded runtimes where stdin/stdout aren't available

> [!TIP]
> Use `resolveSelectOrAllWithPromptIO` in tests by passing `std.Io.Reader.fixed("2\n")` to simulate user input.

## Configuration

### `PromptSelectOrAllOptions`

```zig
pub const PromptSelectOrAllOptions = struct {
    select_key: []const u8 = "select",
    all_key: []const u8 = "all",
    question: []const u8 = "Choose target",
    choices: []const []const u8,
    default_choice: ?[]const u8 = null,
    allow_all: bool = true,
    case_sensitive: ?bool = null,
    allow_prefix_match: bool = true,
    suggest_closest: bool = true,
    max_suggestion_distance: usize = 3,
    max_attempts: usize = 3,
};
```

| Field | Description |
|-------|-------------|
| `select_key` | Key to look up in the parse result for `--select` value |
| `all_key` | Key to look up in the parse result for `--all` flag |
| `question` | The question text displayed at the prompt |
| `choices` | Available selection options |
| `default_choice` | Pre-selected choice when user presses Enter with empty input |
| `allow_all` | Whether "all" is a valid answer |
| `case_sensitive` | Whether matching is case-sensitive (defaults to global config) |
| `allow_prefix_match` | Allow unique prefix matching (e.g. `"gr"` matches `"groups"`) |
| `suggest_closest` | Show "did you mean..." suggestions on invalid input |
| `max_suggestion_distance` | Maximum edit distance for closest-match suggestions |
| `max_attempts` | Number of invalid attempts before returning an error |

### `PromptSelectOrAllDecision`

```zig
pub const PromptSelectOrAllDecision = union(enum) {
    all: void,
    selected: []const u8,
};
```

The result of resolution. Switch on the tag to handle each case.

## Prompt Behavior

When the interactive prompt is triggered, it displays:

```text
Select target to process:
  0) all
  1) users
  2) groups
  3) logs

Enter selection:
```

The user can respond with:

| Input | Result |
|-------|--------|
| `0` or `all` | `.all` (if `allow_all` is true) |
| `1`, `2`, `3` | `.selected` with the corresponding choice |
| `users`, `groups`, `logs` | `.selected` by exact name |
| `gr` | `.selected` as `"groups"` (unique prefix match) |
| Empty + default set | `.selected` with the `default_choice` value |
| Empty + no default | Re-prompts |
| Invalid input | Shows error, retries up to `max_attempts` |

## The question_flow.zig Pattern

The `examples/question_flow.zig` file demonstrates the complete pattern:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "question-flow",
        .description = "Interactive select/all flow for CMD-style tools",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addSelectOrAll(.{
        .select_short = 's',
        .all_short = 'a',
        .select_choices = &[_][]const u8{ "users", "groups", "logs" },
    });

    var parsed = try parser.parseProcess(init);
    defer parsed.deinit();

    const decision = try args.resolveSelectOrAllWithPrompt(&parsed, .{
        .question = "Select target to process",
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .default_choice = "users",
        .allow_all = true,
        .max_attempts = 3,
    }, init.io);

    switch (decision) {
        .all => std.debug.print("Decision: all\n", .{}),
        .selected => |name| std.debug.print("Decision: {s}\n", .{name}),
    }
}
```

> [!NOTE]
> In the example, the config disables `exit_on_error` and enables `silent_errors` so the program can handle errors gracefully rather than printing and exiting.

## Testing with Mock Input

Use `resolveSelectOrAllWithPromptIO` with a fixed reader for deterministic tests:

```zig
test "prompt selects by number" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    var input_reader: std.Io.Reader = .fixed("2\n");
    var out_buf: [512]u8 = undefined;
    var output_writer: std.Io.Writer = .fixed(&out_buf);

    const decision = try args.resolveSelectOrAllWithPromptIO(
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups", "logs" } },
        &input_reader,
        &output_writer,
    );

    try std.testing.expect(decision == .selected);
    try std.testing.expectEqualStrings("groups", decision.selected);
}

test "prompt retries on invalid input" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    // First input invalid, second valid
    var input_reader: std.Io.Reader = .fixed("bad\n1\n");
    var out_buf: [1024]u8 = undefined;
    var output_writer: std.Io.Writer = .fixed(&out_buf);

    const decision = try args.resolveSelectOrAllWithPromptIO(
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups" }, .max_attempts = 3 },
        &input_reader,
        &output_writer,
    );

    try std.testing.expectEqualStrings("users", decision.selected);
}
```
