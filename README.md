<div align="center">

<img  alt="cover" src="https://github.com/user-attachments/assets/6b4390a1-af10-4175-8c8b-c36f3868b398" />

<a href="https://muhammad-fiaz.github.io/args.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.1+-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/args.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/args.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/args.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/args.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/args.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/args.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/args.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/args.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/args.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/args.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/args.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/args.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/args.zig/actions/workflows/github-code-scanning/codeql"><img src="https://github.com/muhammad-fiaz/args.zig/actions/workflows/github-code-scanning/codeql/badge.svg" alt="CodeQL"></a>
<a href="https://github.com/muhammad-fiaz/args.zig/actions/workflows/release.yml"><img src="https://github.com/muhammad-fiaz/args.zig/actions/workflows/release.yml/badge.svg" alt="Release"></a>
<a href="https://github.com/muhammad-fiaz/args.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/args.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/muhammad-fiaz/args.zig/"><img src="https://hits.sh/muhammad-fiaz/args.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A fast, powerful, and developer-friendly command-line argument parsing library for Zig.</em></p>

[**Documentation**](https://muhammad-fiaz.github.io/args.zig/) | [**API Reference**](https://muhammad-fiaz.github.io/args.zig/api/) | [**Quick Start**](#release-installation-recommended) | [**Contributing**](CONTRIBUTING.md)


</div>

---

A production-grade, high-performance command-line argument parsing library for Zig, inspired by Python's argparse with a clean, intuitive, and developer-friendly API.

⭐ **If you love `args.zig`, make sure to give it a star!**

## Features

- [**Fast & Zero Allocations**](https://muhammad-fiaz.github.io/args.zig/guide/efficiency) - Minimal memory footprint with efficient parsing
- [**Intuitive API**](https://muhammad-fiaz.github.io/args.zig/guide/getting-started) - Python argparse-inspired fluent interface
- [**Auto-Generated Help**](https://muhammad-fiaz.github.io/args.zig/guide/getting-started) - Formatted help text for better understanding out of the box
- [**Shell Completions**](https://muhammad-fiaz.github.io/args.zig/guide/shell-completions) - Generate completions for Bash, Zsh, Fish, PowerShell, Nushell
- [**Environment Variables**](https://muhammad-fiaz.github.io/args.zig/guide/environment-variables) - Fallback to env vars for configuration
- [**Subcommands**](https://muhammad-fiaz.github.io/args.zig/guide/subcommands) - Full support for Git-style subcommands
- [**Colored Output**](https://muhammad-fiaz.github.io/args.zig/guide/configuration#display-options) - ANSI color support for beautiful terminal output
- [**Update Checker**](https://muhammad-fiaz.github.io/args.zig/guide/updates) - Automatic non-blocking update notifications (enabled by default)
- [**Comprehensive Validation**](https://muhammad-fiaz.github.io/args.zig/guide/validation) - Type checking, choices, and custom validators for complex parsing
- [**Well Tested**](CONTRIBUTING.md#running-tests) - Extensive test coverage across all modules

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

Then add it to your `build.zig`:

```zig
const args_dep = b.dependency("args", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("args", args_dep.module("args"));
```

## Quick Start

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create argument parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A sample application built with args.zig",
    });
    defer parser.deinit();

    // Add arguments
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    try parser.addOption("output", .{
        .short = 'o',
        .help = "Output file path",
        .default = "output.txt",
    });

    try parser.addPositional("input", .{
        .help = "Input file to process",
    });

    // Parse command-line arguments
    var result = try parser.parseProcess();
    defer result.deinit();

    // Use parsed values
    const verbose = result.getBool("verbose") orelse false;
    const output = result.getString("output") orelse "output.txt";
    const input = result.getString("input") orelse "unknown";

    if (verbose) {
        std.debug.print("Processing {s} -> {s}\n", .{ input, output });
    }
}
```

## Examples

### Flags and Options

```zig
// Boolean flag
try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose mode" });

// String option
try parser.addOption("config", .{ .short = 'c', .help = "Config file" });

// Integer option
try parser.addOption("count", .{
    .short = 'n',
    .value_type = .int,
    .default = "10",
});

// Choice option
try parser.addOption("format", .{
    .short = 'f',
    .choices = &[_][]const u8{ "json", "xml", "csv" },
});
```

### Counter Arguments

```zig
// -v, -vv, -vvv for increasing verbosity
try parser.addCounter("verbose", .{ .short = 'v' });

var result = try parser.parse(&[_][]const u8{ "-v", "-v", "-v" });
const verbosity = result.get("verbose").?.counter; // = 3
```

### Subcommands

```zig
try parser.addSubcommand(.{
    .name = "clone",
    .help = "Clone a repository",
    .args = &[_]args.ArgSpec{
        .{ .name = "url", .positional = true, .required = true },
        .{ .name = "depth", .short = 'd', .long = "depth", .value_type = .int },
    },
});

try parser.addSubcommand(.{
    .name = "init",
    .help = "Initialize a new repository",
});
```

### Shell Completions

```zig
// Generate Bash completion script
const bash_script = try parser.generateCompletion(.bash);
std.debug.print("{s}", .{bash_script});

// Also supports: .zsh, .fish, .powershell, .nushell
```

### Environment Variable Fallback

```zig
try parser.addOption("token", .{
    .help = "API token",
    .env_var = "API_TOKEN",  // Falls back to $API_TOKEN
});
```

### Argument Groups

```zig
// Create a named group
try parser.addArgumentGroup("Server Options", .{
    .description = "Configuration for the server",
});

// Arguments added after will belong to this group
try parser.addOption("host", .{ .help = "Bind address" });
try parser.addOption("port", .{ .value_type = .int, .help = "Port number" });

// Reset to default (ungrouped)
parser.setGroup(null);
```

### Mutually Exclusive Groups

```zig
try parser.addArgumentGroup("Mode", .{
    .exclusive = true,
    .required = true, // User MUST choose exactly one
});

try parser.addFlag("interactive", .{ .short = 'i' });
try parser.addFlag("batch", .{ .short = 'b' });
```

### Custom Validation

```zig
fn validateUser(val: []const u8) args.validation.ValidationResult {
    if (val.len < 3) return .{ .err = "username too short" };
    return .{ .ok = {} };
}

try parser.addOption("user", .{
    .help = "Username",
    .validator = validateUser,
});

// See examples/custom_parsing.zig for complex format validation
// e.g. --mode 1920x1080@60Hz
try parser.addOption("mode", .{
    .help = "Display mode",
    .validator = validateMode,
    .metavar = "<W>x<H>[@<R>Hz]",
});
```

## Configuration

### Update Checker

The update checker is **enabled by default** to keep you informed about new features and fixes. To disable it:

```zig
// Method 1: Global disable (Recommended)
args.disableUpdateCheck();

// Method 2: Per-parser configuration
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .check_for_updates = false },
});
```

### Minimal Configuration

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(), // No colors, no update check
});
```

## Building

```bash
# Build library
zig build

# Run tests
zig build test

# Run examples
zig build run-basic
zig build run-advanced

# Run benchmarks
zig build bench

# Format code
zig build fmt
```

## Benchmarks

Run benchmarks to see the performance:

```bash
zig build bench
```

### Benchmark Results

Typical results on modern hardware (10,000 iterations):

| Benchmark                    | Avg Time  | Throughput      |
|------------------------------|-----------|-----------------|
| Simple Flags (3 flags)          | ~33 μs    | ~30,000 ops/sec  |
| Multiple Options (3 options)    | ~32 μs    | ~30,700 ops/sec  |
| Positional Arguments            | ~24 μs    | ~42,000 ops/sec  |
| Counters (-vvv -dd)             | ~23 μs    | ~42,700 ops/sec  |
| Subcommands (2 subcommands)     | ~25 μs    | ~40,400 ops/sec  |
| Mixed Arguments (complex CLI)   | ~40 μs    | ~24,800 ops/sec  |
| Help Text Generation            | ~50 μs    | ~19,900 ops/sec  |
| Shell Completion (Bash)         | ~23 μs    | ~42,600 ops/sec  |

> [!NOTE]
> Results vary based on hardware and system load. Tested on Windows x86_64 with Zig 0.15.1.
> If you want the latest release benchmarks, you can find them on the repository [releases](https://github.com/muhammad-fiaz/args.zig/releases).

## Documentation

Full documentation is available at [muhammad-fiaz.github.io/args.zig](https://muhammad-fiaz.github.io/args.zig/).

- [Getting Started](https://muhammad-fiaz.github.io/args.zig/guide/getting-started)
- [API Reference](https://muhammad-fiaz.github.io/args.zig/api/parser)
- [Examples](https://muhammad-fiaz.github.io/args.zig/examples/)
- [Update Checker](https://muhammad-fiaz.github.io/args.zig/guide/updates)

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See our [Code of Conduct](CODE_OF_CONDUCT.md) for community guidelines.

## Security

For security concerns, please see our [Security Policy](SECURITY.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you find this project helpful, consider supporting it:

- Star this repository
- Report bugs and suggest features
- [Sponsor on GitHub](https://github.com/sponsors/muhammad-fiaz)
- [Buy me a coffee](https://pay.muhammadfiaz.com)


