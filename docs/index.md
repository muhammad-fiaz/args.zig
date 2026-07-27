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
  - icon: 🧾
    title: Error Formatting
    details: Shared helpers for parse, schema, and validation error messages so your CLI output stays consistent.
  - icon: 🚫
    title: Negated Flags
    details: Native `--no-flag` support for long boolean options, with config control for strict compatibility.
  - icon: 🧹
    title: Strict Filter Workflows
    details: Built-in include/exclude helpers with optional canonicalization, dedupe, and conflict detection for production CMD pipelines.
  - icon: 🎚️
    title: Inverse Flag API
    details: Use `addFalseFlag` for disable-style options that map directly to boolean false.
  - icon: 🛠️
    title: Modular Architecture
    details: Highly modular codebase with reusable utility components (internal utils.zig) and clear separation of concerns.
  - icon: 🔄
    title: Update Checker
    details: Optional non-blocking update checker that notifies users of new versions (can be disabled for air-gapped environments).
  - icon: 📋
    title: Declarative Structs
    details: Parse arguments directly into Zig structs with parseInto/derive for rapid prototyping and type-safe configuration.
  - icon: 🔄
    title: Bracket-Delimited Lists
    details: Parse inline bracket values `{a,b,c}`, `[d,e,f]`, `<g,h,i>` as arrays with automatic detection.
  - icon: 🗂️
    title: File Format Helpers
    details: Pass explicit format arrays to addFormatOption and addExtensionOption for file-format-aware CLI options.
  - icon: 🛡️
    title: Fallback Parse API
    details: Graceful error recovery with parseOr, parseProcessOr, and value-level getOr* methods for bulletproof CLI tools.
---

## Requirements

- **Zig 0.16.0** or later (compatible with Zig 0.17+)
- No external dependencies

## Related Zig Projects

- For **.env parsing** support, check out **[env.zig](https://github.com/muhammad-fiaz/env.zig)**.
- For **TUI** support, check out **[tui.zig](https://github.com/muhammad-fiaz/tui.zig)**.
- For **ZON file format** support, check out **[zon.zig](https://github.com/muhammad-fiaz/zon.zig)**.
- For **spinners/loading/progress bar** support, check out **[loaders.zig](https://github.com/muhammad-fiaz/loaders.zig)**.
- For **MCP** support, check out **[mcp.zig](https://github.com/muhammad-fiaz/mcp.zig)**.
- For **args parsing** support, check out **[args.zig](https://github.com/muhammad-fiaz/args.zig)**.
- For **HTTP client/server** support, check out **[httpx.zig](https://github.com/muhammad-fiaz/httpx.zig)**.
- For **API framework** support, check out **[api.zig](https://github.com/muhammad-fiaz/api.zig)**.
- For **web framework** support, check out **[zix](https://github.com/muhammad-fiaz/zix)**.
- For **archive/compression** support, check out **[archive.zig](https://github.com/muhammad-fiaz/archive.zig)**.
- For **compression file format** support, check out **[zigx](https://github.com/muhammad-fiaz/zigx)**.
- For **file downloading** support, check out **[downloader.zig](https://github.com/muhammad-fiaz/downloader.zig)**.
- For **update checker/auto-updater** support, check out **[updater.zig](https://github.com/muhammad-fiaz/updater.zig)**.
- For **numerical computing** support, check out **[num.zig](https://github.com/muhammad-fiaz/num.zig)**.
- For **logging** support, check out **[logly.zig](https://github.com/muhammad-fiaz/logly.zig)**.
- For **data validation and serialization** support, check out **[zigantic](https://github.com/muhammad-fiaz/zigantic)**.

## Quick Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A sample application",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getBool("verbose") orelse false) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
}
```

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.8):

zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.8.tar.gz

- **Package Version:** 0.0.8
- **Minimum Zig Version:** 0.16.0 (also compatible with Zig 0.17+)
