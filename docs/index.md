---
layout: home

hero:
  name: "args.zig"
  text: "Command-Line Argument Parsing for Zig"
  tagline: Fast, powerful, and developer-friendly CLI argument parsing
  image:
    src: /logo.png
    alt: args.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/parser
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/args.zig

features:
  - icon: 🚀
    title: Lightning Fast
    details: Optimized string operations and unified utility functions for maximum efficiency and zero-allocation parsing where possible.
  - icon: 🎯
    title: Intuitive API
    details: Python argparse-inspired fluent interface that feels natural to use. Get started in minutes with less boilerplate.
  - icon: 🔤
    title: Shell Completions
    details: Generate auto-completion scripts for Bash, Zsh, Fish, and PowerShell with a single function call.
  - icon: 📦
    title: Subcommands
    details: Full support for Git-style nested subcommands, each with their own arguments, help text, and logic.
  - icon: 🌐
    title: Environment Variables
    details: Seamlessly fall back to environment variables when command-line arguments aren't provided.
  - icon: 📝
    title: Auto-Generated Help
    details: Beautiful, colorized help text generated automatically from your argument definitions and doc comments.
  - icon: ✅
    title: Robust Validation
    details: Built-in validation for types, choices, ranges, and custom rules. Comprehensive error reporting with "Did you mean?" suggestions.
  - icon: 🛠️
    title: Modular Architecture
    details: Highly modular codebase with reusable utility components (internal utils.zig) and clear separation of concerns.
  - icon: 🔄
    title: Update Checker
    details: Optional non-blocking update checker that notifies users of new versions (can be disabled for air-gapped environments).
---

## Requirements

- **Zig 0.15.0** or later
- No external dependencies

## Quick Example

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
        .description = "A sample application",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });

    var result = try parser.parseProcess();
    defer result.deinit();

    if (result.getBool("verbose") orelse false) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
}
```

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

Then in your `build.zig`:

```zig
const args_dep = b.dependency("args", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("args", args_dep.module("args"));
```

## Current Version

- **Package Version:** 0.0.2
- **Minimum Zig Version:** 0.15.0
