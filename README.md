<div align="center">

<img  alt="cover" src="https://github.com/user-attachments/assets/6b4390a1-af10-4175-8c8b-c36f3868b398" />

<a href="https://muhammad-fiaz.github.io/args.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16.0+-orange.svg?logo=zig" alt="Zig Version"></a>
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

> [!NOTE]
> **args.zig is a relatively new project**, but it is designed and tested with production use in mind.
> The API is intended to be stable, and the library focuses on performance, correctness, and real-world CLI needs.


**Related Zig projects:**

- For **API framework** support, check out **[api.zig](https://github.com/muhammad-fiaz/api.zig)**.
- For **web framework** support, check out **[zix](https://github.com/muhammad-fiaz/zix)**.
- For **logging** support, check out **[logly.zig](https://github.com/muhammad-fiaz/logly.zig)**.
- For **data validation and serialization** support, check out **[zigantic](https://github.com/muhammad-fiaz/zigantic)**.
- For **HTTP Server/Client** support, check out **[httpx.zig](https://github.com/muhammad-fiaz/httpx.zig)**.
- For **ZON file format** support, check out **[zon.zig](https://github.com/muhammad-fiaz/zon.zig)**  

⭐ **If you love `args.zig`, make sure to give it a star!**

## Features

- [**Fast & Zero Allocations**](https://muhammad-fiaz.github.io/args.zig/guide/efficiency) - Minimal memory footprint with efficient parsing
- [**Intuitive API**](https://muhammad-fiaz.github.io/args.zig/guide/getting-started) - Python argparse-inspired fluent interface
- [**Auto-Generated Help**](https://muhammad-fiaz.github.io/args.zig/guide/getting-started) - Formatted help text for better understanding out of the box
- [**Shell Completions**](https://muhammad-fiaz.github.io/args.zig/guide/shell-completions) - Generate completions for Bash, Zsh, Fish, PowerShell, Nushell
- [**Environment Variables**](https://muhammad-fiaz.github.io/args.zig/guide/environment-variables) - Fallback to env vars for configuration
- [**Subcommands**](https://muhammad-fiaz.github.io/args.zig/guide/subcommands) - Full support for Git-style subcommands
- [**Declarative Structs**](https://muhammad-fiaz.github.io/args.zig/guide/declarative-structs) - Parse directly into Zig structs with `parseInto`
- [**Colored Output**](https://muhammad-fiaz.github.io/args.zig/guide/configuration#display-options) - ANSI color support for beautiful terminal output
- [**Update Checker**](https://muhammad-fiaz.github.io/args.zig/guide/updates) - Automatic non-blocking update notifications (enabled by default)
- [**Comprehensive Validation**](https://muhammad-fiaz.github.io/args.zig/guide/validation) - Type checking, choices, and custom validators for complex parsing
- [**Negated Long Flags**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#negated-long-flags) - Familiar `--no-flag` support for boolean toggles
- [**Configurable Matching**](https://muhammad-fiaz.github.io/args.zig/guide/configuration#case-insensitive-matching) - Optional case-insensitive matching for long options and choices
- [**Inverse Flags API**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#inverse-boolean-flags) - `addFalseFlag` helper for explicit disable-style options
- [**Positional Validation**](https://muhammad-fiaz.github.io/args.zig/guide/validation#positional-validation) - `choices`, `expect`, validators, and hidden positional support
- [**CMD Selection Helpers**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#cmd-style-select-and-all) - Built-in `--select` and `--all` helper APIs
- [**Question Flow Selection**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#question-based-selection-flow) - Prompt users to choose select/all when flags are omitted
- [**Include/Exclude Filters**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#includeexclude-filters) - Reusable `--include` and `--exclude` helpers for CMD workflows
- [**Strict Filter Resolution**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#strict-includeexclude-resolution) - Canonicalize choices, dedupe values, and detect include/exclude conflicts
- [**File & Extension Support**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#file-and-extension-support) - Reusable helpers for file paths, directories, and allowed extensions
- [**Typed Numeric Options**](https://muhammad-fiaz.github.io/args.zig/api/parser#numeric-typed-option-helpers) - `addIntOption`, `addFloatOption`, `addUintOption` with optional range validation
- [**Hex Decode Option**](https://muhammad-fiaz.github.io/args.zig/api/parser#decode--encoding-option-helpers) - `addHexOption` for passing binary data as hex strings
- [**Log Level Helpers**](https://muhammad-fiaz.github.io/args.zig/api/parser#addloglevel) - Integrated `--verbose` / `--quiet` pair via `addLogLevel`
- [**Advanced parseInto**](https://muhammad-fiaz.github.io/args.zig/examples/#advanced-parseinto-example) - Struct parsing with enums, u32, u64, f32, f64, and optional fields
- [**ENV Var Configuration**](https://muhammad-fiaz.github.io/args.zig/guide/environment-variables) - `fromEnvOrDefault` helper and `env_prefix` for automatic env-var derivation
- [**Typed Input Validators**](https://muhammad-fiaz.github.io/args.zig/guide/validation#typed-input-validators) - Built-in validators for email, URL, IPv4, hostname/port endpoints, UUID, ISO dates, year/time, JSON payloads, and absolute paths
- [**Error Formatting Helpers**](https://muhammad-fiaz.github.io/args.zig/api/errors) - Shared message formatters for parse, schema, and validation errors
- [**CSV Select/All Resolution**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#csv-selectall-strict-resolution) - Resolve `--select users,groups` and `--all` into normalized target sets
- [**List Options**](https://muhammad-fiaz.github.io/args.zig/api/parser#addlistoption) - Comma-separated list values stored as arrays via `addListOption`
- [**Secret Options**](https://muhammad-fiaz.github.io/args.zig/api/parser#addsecretoption) - Password/secret options hidden from help text
- [**Extra Validators**](https://muhammad-fiaz.github.io/args.zig/guide/validation) - `hexColor`, `semver`, `base64`, `macAddress`, `asciiOnly`, `lowercase`, `uppercase`
- [**ParseResult Extras**](https://muhammad-fiaz.github.io/args.zig/api/parser#parsersult) - `getUint`, `getArray`, `getEnum`, `getOrString`, `getOrInt`, `getOrBool`, `getOrFloat`, `getOrUint`, `getOrCounter`, `getOrKeyValue` methods on `ParseResult`
- [**Env Options**](https://muhammad-fiaz.github.io/args.zig/api/parser#addenvoption) - Automatic env var derivation via `addEnvOption`
- [**Bracket-Delimited Lists**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#bracket-delimited-lists) - Parse `{a,b,c}`, `[a,b,c]`, `<a,b,c>` as arrays via `addBracketedListOption`
- [**Multi-Value n-args**](https://muhammad-fiaz.github.io/args.zig/api/parser#multi-value-options) - Variadic argument collection via `addMultiple` with configurable min/max
- [**Append Fix**](https://muhammad-fiaz.github.io/args.zig/api/parser#addappend) - Repeated options `-o a -o b` now store as proper arrays retrievable via `getArray()`
- [**File Format Helpers**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#file-format-and-extension-helpers) - `addFormatOption`, `addExtensionOption` with explicit extension arrays
- [**Custom Curly Braces & Custom Brackets**](https://muhammad-fiaz.github.io/args.zig/guide/options-flags#custom-brackets) - Auto-strip `{}`, `[]`, `<>`, `()` from inline values; configurable via `allow_brackets`
- [**Fallback Parse API**](https://muhammad-fiaz.github.io/args.zig/api/parser#parseor) - `parseOr()` / `parseProcessOr()` with optional error callback for graceful error recovery
- [**Well Tested**](CONTRIBUTING.md#running-tests) - Extensive test coverage (217+ tests)


### Release Installation (Recommended)

Install the latest stable release for zig v0.16 (v0.0.7):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.7.tar.gz
```

Install the supported release for zig v0.15 (v0.0.4):

```bash
zig fetch --save https://github.com/muhammad-fiaz/args.zig/archive/refs/tags/0.0.4.tar.gz
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

### Basic Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

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

    // Parse command-line arguments from the process init context
    var result = try parser.parseProcess(init);
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

> [!NOTE]
>
> In Zig 0.16, the main function signature changed to `pub fn main(init: std.process.Init) !void`.
> The `init` parameter gives you the full process context used by `args.zig`:
>
> - **`init.arena.allocator()`** — Arena allocator for the process lifetime, freed automatically on exit
> - **`init.minimal.args`** — Command-line arguments as Zig sees them at startup
> - **`init.io`** — I/O context for stdin, stdout, and stderr
> - **`init.environ_map`** — Environment variables for process-aware parsing
>
> This is the recommended path for Zig 0.16+ because `parser.parseProcess(init)` can use the process args, I/O, and environment map directly.

### Alternative: Using c_allocator (Simpler but requires libc)

If you prefer not to use `std.process.Init`, you can use `c_allocator`:

```zig
pub fn main() !void {
    const allocator = std.heap.c_allocator;
    
    var parser = try args.ArgumentParser.init(allocator, .{ .name = "myapp" });
    defer parser.deinit();
    
    // Add arguments...
    
    // Parse with explicit args
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    
    var result = try parser.parse(argv[1..]);
    defer result.deinit();
}
```

### Feature Highlights for Zig 0.16+

- **Process-aware parsing** - `parseProcess(init)` reads from `init.minimal.args`, `init.io`, and `init.environ_map`
- **Arena-backed allocation** - `init.arena.allocator()` is ideal for CLI apps that exit once and free everything automatically
- **Explicit parsing fallback** - `parser.parse(...)` still works when you want to supply custom arguments in tests or tooling
- **I/O-aware runtime behavior** - parse and help output can use the process I/O context cleanly
- **Environment-driven configuration** - combine `env_prefix` and `env_var` with `init.environ_map` for automatic env lookups

## Examples

Brief usage pattern:

```zig
var parser = try args.ArgumentParser.init(allocator, .{ .name = "app" });
defer parser.deinit();
try parser.addFlag("verbose", .{ .short = 'v' });
try parser.addOption("output", .{ .short = 'o' });
var result = try parser.parseProcess(init);
defer result.deinit();
```

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

### Typed Input Validation Helpers

Use dedicated helpers for common API and configuration inputs:

```zig
try parser.addEmailOption("email", .{ .short = 'e', .required = true, .env_var = "APP_EMAIL" });
try parser.addUrlOption("endpoint", .{});
try parser.addIpv4Option("host", .{});
try parser.addIpOption("host-any", .{}); // IPv4 or IPv6
try parser.addIpv6Option("host-v6", .{});
try parser.addHostNameOption("hostname", .{});
try parser.addPortOption("port", .{});
try parser.addEndpointOption("service", .{}); // host:port
try parser.addKeyValueOption("label", .{});   // key=value
try parser.addUuidOption("request-id", .{});
try parser.addIsoDateOption("run-date", .{});
try parser.addIsoDateTimeOption("timestamp", .{});
try parser.addYearOption("year", .{});
try parser.addTimeOption("time", .{});
try parser.addAbsolutePathOption("workspace", .{});
try parser.addJsonOption("payload", .{});

try parser.addOption("retries", .{
    .value_type = .int,
    .validator = args.Validators.intRange(1, 10),
    .default = "3",
});

try parser.addOption("peer", .{
    .validator = args.Validators.anyIp,
});

var result = try parser.parseProcess(init);
defer result.deinit();

const email = result.getString("email") orelse "";
const service = result.getString("service") orelse "localhost:8080";
const retries = result.getInt("retries") orelse 3;
const label = result.getKeyValue("label");
```

### Negated Long Flags

Long boolean flags support `--no-<name>` by default:

```zig
try parser.addFlag("cache", .{ .help = "Enable cache" });

var result = try parser.parse(&[_][]const u8{"--no-cache"});
defer result.deinit();

const cache_enabled = result.getBool("cache") orelse true; // false
```

### Inverse Boolean Flags

Use `addFalseFlag` when your primary option semantics are "disable this behavior":

```zig
try parser.addFalseFlag("color", .{ .help = "Disable color output" });

var result = try parser.parse(&[_][]const u8{"--color"});
defer result.deinit();

const color_enabled = result.getBool("color") orelse true; // false
```

### CMD-Style Select And All

Use helpers to quickly model common command patterns:

```zig
try parser.addSelectOrAllCsv(.{
    .select_short = 's',
    .all_short = 'a',
});
```

This creates an exclusive pair (`--select <csv-list>` vs `--all`).

Normalize selections into canonical values:

```zig
var resolved = try args.resolveSelectOrAllStrict(allocator, &result, .{
    .choices = &[_][]const u8{ "users", "groups", "logs" },
    .allow_prefix_match = true,
    .dedupe = true,
});
defer resolved.deinit();
```

### Question-Based Selection Flow

Resolve selection from parsed args or ask the user when missing:

```zig
const decision = try args.resolveSelectOrAllWithPrompt(&parsed, .{
    .question = "Select target",
    .choices = &[_][]const u8{ "users", "groups", "logs" },
    .default_choice = "users",
    .allow_all = true,
}, init.io);
```

### Include/Exclude Filters

Use reusable helpers for filter-style commands:

```zig
try parser.addIncludeExclude(.{ .include_short = 'i', .exclude_short = 'x' });

var parsed = try parser.parseProcess(init);
defer parsed.deinit();

var filters = try args.resolveIncludeExclude(allocator, &parsed, "include", "exclude");
defer filters.deinit();
```

For stricter behavior (choice normalization, deduplication, and conflict checks):

```zig
var strict_filters = try args.resolveIncludeExcludeStrict(allocator, &parsed, .{
    .choices = &[_][]const u8{ "users", "groups", "logs" },
    .all_keyword = "all",
});
defer strict_filters.deinit();
```

### File And Extension Support

Use dedicated helpers for path/file/directory workflows:

```zig
try parser.addFileOptionWithExtensions("input", &[_][]const u8{ "json", "yaml", "toml" }, .{
    .short = 'i',
    .must_exist = false,
});

try parser.addDirectoryOption("workspace", .{
    .short = 'w',
    .must_exist = false,
});

const output_name_validator = args.Validators.filePolicy(&[_][]const u8{"json"}, false, 3, 64);

try parser.addFileNameOption("output-name", .{
    .short = 'o',
    .validator = output_name_validator,
});
```

You can still compose validators manually when needed:

```zig
const custom_validator = args.Validators.all(&[_]args.ValidatorFn{
    args.Validators.fileName,
    args.Validators.fileNameLength(3, 64),
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

### Aliases

You can define multiple names (aliases) for a single argument:

```zig
try parser.addArg(.{
    .name = "verbose",
    .long = "verbose",
    .aliases = &[_][]const u8{ "v", "loud", "debug" },
    .action = .store_true,
    .help = "Enable verbose output",
});
```

### Callbacks

Trigger a function immediately when an argument is parsed:

```zig
fn onOutput(name: []const u8, value: ?[]const u8) void {
    std.debug.print("Option {s} received value: {s}\n", .{name, value orelse "null"});
}

// ...

try parser.addArg(.{
    .name = "output",
    .long = "output",
    .action = .callback,
    .callback = onOutput,
});
```

### Declarative Structs

Define your CLI interface using a native Zig struct:

```zig
const Config = struct {
    verbose: bool,
    output: ?[]const u8,
    count: i32,
};

// Parse directly into the struct
var parsed = try args.parseInto(allocator, Config, .{
    .name = "myapp",
}, null);
defer parsed.deinit();

std.debug.print("Count: {d}\n", .{parsed.options.count});
```

### Typed Numeric Options

Use `addIntOption`, `addFloatOption`, and `addUintOption` for type-safe numeric parsing with optional range validation:

```zig
try parser.addIntOption("retries", .{
    .short = 'r',
    .help = "Retry count",
    .default = "3",
});

try parser.addFloatOption("threshold", .{
    .short = 't',
    .help = "Confidence threshold",
    .default = "0.75",
});

try parser.addUintOption("threads", .{
    .short = 'p',
    .help = "Worker thread count (1-64)",
    .default = "4",
    .min = 1,    // Minimum value
    .max = 64,   // Maximum value
});
```

### Hex Decode Option

Pass binary data as hex strings — useful for keys, hashes, and small payloads:

```zig
try parser.addHexOption("key", .{
    .short = 'k',
    .help = "Hex-encoded key material",
    .required = true,
});

var result = try parser.parseProcess(init);
defer result.deinit();

const key_bytes = result.get("key").?.asString().?; // Decoded bytes
```

### Log Level Helpers

The `addLogLevel` helper wires `--verbose` (increments) and `--quiet` (decrements) to a shared counter:

```zig
try parser.addLogLevel(
    .{ .short = 'v', .dest = "verbosity" },
    .{ .short = 'q', .dest = "verbosity" },
);

var result = try parser.parseProcess(init);
defer result.deinit();

const level = result.get("verbosity").?.asInt().? orelse 0; // -v -v => 2; -q => -1
```

### Advanced parseInto with Enums

Enum struct fields are automatically converted to `--flag` choices:

```zig
const LogLevel = enum { debug, info, warn, err };

const Config = struct {
    verbose: bool = false,
    log_level: LogLevel = .info,
    port: u32 = 8080,
    timeout: f64 = 30.0,
    host: []const u8 = "localhost",
};

var parsed = try args.parseInto(allocator, Config, .{
    .name = "myapp",
}, null, init);
defer parsed.deinit();

std.debug.print("Log level: {s}\n", .{@tagName(parsed.options.log_level)});
```

### Environment Variable Configuration

Use `env_var`, `env_prefix` config, and `fromEnvOrDefault` for flexible configuration:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "app",
    // Auto-derives env vars: MYAPP_DB_HOST, MYAPP_DB_PORT, etc.
    .config = args.Config{ .env_prefix = "MYAPP" },
});

try parser.addOption("db-host", .{
    .short = 'h',
    .env_var = "MYAPP_DB_HOST",  // Explicit env var
    .default = "localhost",
});

// Explicit env var with fallback default
try parser.fromEnvOrDefault("api-key", "MYAPP_API_KEY", "no-key-set", .{
    .help = "API key (from MYAPP_API_KEY env var)",
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

# Run all examples in one go
zig build run-all-examples

# Run examples
zig build run-basic
zig build run-advanced
zig build run-config_modes
zig build run-negated_flags
zig build run-positional_validation
zig build run-select_all
zig build run-question_flow
zig build run-include_exclude
zig build run-include_exclude_strict
zig build run-file_support
zig build run-data_input_validation
zig build run-network_endpoints
zig build run-error_handling
zig build run-subcommand_suggestions
zig build run-decryption_options
zig build run-update_check

# Run benchmarks
zig build bench

# Format code
zig build fmt
```

### Cross-Platform Validation

Use the following commands to validate target coverage:

```bash
# Native target tests (runs tests)
zig build test

# Cross-target compile validation (builds all artifacts for each target)
zig build -Dtarget=x86_64-windows-gnu
zig build -Dtarget=x86_64-linux-gnu
zig build -Dtarget=aarch64-macos

# Targeted test invocations (must run on matching host/runner)
zig build test -Dtarget=x86_64-windows-gnu
zig build test -Dtarget=x86_64-linux-gnu
zig build test -Dtarget=aarch64-macos
```

On Windows hosts, Linux/macOS test binaries can be compiled but not executed directly. Run those test commands on Linux/macOS CI runners (or native machines) for full runtime verification.

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
| Multiple Options (3 options)    | ~34 μs    | ~29,200 ops/sec  |
| Positional Arguments            | ~24 μs    | ~40,700 ops/sec  |
| Counters (-vvv -dd)             | ~24 μs    | ~41,800 ops/sec  |
| Subcommands (2 subcommands)     | ~23 μs    | ~43,500 ops/sec  |
| Mixed Arguments (complex CLI)   | ~40 μs    | ~24,600 ops/sec  |
| Argument Groups                 | ~23 μs    | ~42,900 ops/sec  |
| Callbacks                       | ~23 μs    | ~42,400 ops/sec  |
| Negated Flags                   | ~22 μs    | ~45,000 ops/sec  |
| Select/All Helpers              | ~25 μs    | ~39,500 ops/sec  |
| Select/All CSV Strict Resolve   | ~53 μs    | ~18,800 ops/sec  |
| Include/Exclude Strict Resolve  | ~31 μs    | ~31,800 ops/sec  |
| Prompt Resolution (Parsed)      | ~24 μs    | ~41,600 ops/sec  |
| Suggestion Lookup               | ~2 μs     | ~500,000 ops/sec |
| Subcommand Suggestion Lookup    | ~2 μs     | ~500,000 ops/sec |
| Help Text Generation            | ~46 μs    | ~21,500 ops/sec  |
| Shell Completion Generation (Bash) | ~23 μs | ~43,300 ops/sec  |
| Shell Completion Generation (Zsh)  | ~24 μs | ~41,900 ops/sec  |
| Declarative Structs             | ~29 μs    | ~34,600 ops/sec  |
| Expect Validation               | ~18 μs    | ~56,400 ops/sec  |
| File Extension Validation       | ~21 μs    | ~47,100 ops/sec  |
| File Name Policy Validation     | ~22 μs    | ~46,200 ops/sec  |
| Typed Input Validation          | ~138 μs   | ~7,300 ops/sec   |
| Decryption Option (Base64)      | ~30 μs    | ~33,000 ops/sec  |


> [!NOTE]
> Results vary based on hardware and system load. Tested on Windows x86_64 with Zig 0.16.0.
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
