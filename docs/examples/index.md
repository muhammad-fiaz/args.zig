---
title: Examples
description: Comprehensive examples demonstrating all args.zig features including basic usage, advanced patterns, and real-world scenarios.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, examples, tutorials, cli examples, usage patterns
---

# Examples

This page provides comprehensive examples demonstrating args.zig features.

## Basic Example

A simple CLI with flags, options, and positional arguments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "greet",
        .version = "1.0.0",
        .description = "A friendly greeting application",
    });
    defer parser.deinit();

    // Boolean flag
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    // String option with default
    try parser.addOption("name", .{
        .short = 'n',
        .help = "Name to greet",
        .default = "World",
    });

    // Required positional argument
    try parser.addPositional("message", .{
        .help = "Greeting message",
        .required = true,
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const name = result.getString("name") orelse "World";
    const message = result.getString("message").?;

    if (verbose) {
        std.debug.print("[VERBOSE] Preparing greeting...\n", .{});
    }

    std.debug.print("{s}, {s}!\n", .{ message, name });
}
```

**Usage:**
```bash
greet "Hello"              # Output: Hello, World!
greet -n Alice "Hi"        # Output: Hi, Alice!
greet -v --name Bob "Hey"  # [VERBOSE] Preparing... / Hey, Bob!
```

## Subcommands Example

Git-style subcommands with their own arguments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "mycli",
        .version = "2.0.0",
        .description = "A CLI with subcommands",
    });
    defer parser.deinit();

    // Global flag
    try parser.addFlag("verbose", .{ .short = 'v' });

    // Add 'init' subcommand
    try parser.addSubcommand(.{
        .name = "init",
        .help = "Initialize a new project",
        .aliases = &[_][]const u8{"i"},
        .args = &[_]args.ArgSpec{
            .{ .name = "name", .positional = true, .required = true, .help = "Project name" },
            .{ .name = "template", .short = 't', .long = "template", .default = "basic" },
        },
    });

    // Add 'build' subcommand
    try parser.addSubcommand(.{
        .name = "build",
        .help = "Build the project",
        .aliases = &[_][]const u8{"b"},
        .args = &[_]args.ArgSpec{
            .{ .name = "release", .short = 'r', .long = "release", .action = .store_true },
            .{ .name = "target", .long = "target", .default = "native" },
        },
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;

    if (result.subcommand) |cmd| {
        const sub = result.subcommand_args.?;

        if (std.mem.eql(u8, cmd, "init")) {
            const name = sub.getString("name").?;
            const template = sub.getString("template") orelse "basic";
            std.debug.print("Initializing '{s}' with template '{s}'\n", .{ name, template });
        } else if (std.mem.eql(u8, cmd, "build")) {
            const release = sub.getBool("release") orelse false;
            const target = sub.getString("target") orelse "native";
            const mode = if (release) "release" else "debug";
            std.debug.print("Building in {s} mode for {s}\n", .{ mode, target });
        }

        if (verbose) std.debug.print("(verbose mode)\n", .{});
    } else {
        try parser.printHelp();
    }
}
```

**Usage:**
```bash
mycli init myproject              # Initialize 'myproject' with template 'basic'
mycli i myapp -t advanced         # Initialize 'myapp' with template 'advanced'
mycli build --release             # Building in release mode for native
mycli -v build --target aarch64   # Building in debug mode for aarch64 (verbose mode)
```

## Environment Variables Example

Using environment variables as fallback values:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "server",
        .description = "A server with environment variable configuration",
    });
    defer parser.deinit();

    // Options with environment variable fallback
    try parser.addOption("host", .{
        .short = 'H',
        .help = "Server hostname",
        .env_var = "SERVER_HOST",
        .default = "0.0.0.0",
    });

    try parser.addOption("port", .{
        .short = 'p',
        .help = "Server port",
        .value_type = .int,
        .env_var = "SERVER_PORT",
        .default = "8080",
    });

    try parser.addOption("secret", .{
        .help = "Secret key (required)",
        .env_var = "SERVER_SECRET",
        .required = true,
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const host = result.getString("host").?;
    const port = result.getInt("port").?;
    const secret = result.getString("secret").?;

    std.debug.print("Starting server on {s}:{d}\n", .{ host, port });
    std.debug.print("Secret: {s}...\n", .{secret[0..@min(4, secret.len)]});
}
```

**Usage:**
```bash
# Using environment variables
export SERVER_SECRET="my-secret-key"
export SERVER_PORT="3000"
server --host 127.0.0.1

# Using command line (overrides env vars)
server --secret "cli-secret" --port 9000
```

## Configuration Modes Example

`examples/config_modes.zig` demonstrates non-breaking parser behavior flags:

- `case_sensitive = false` for case-insensitive long options
- `allow_short_clusters = false` to treat `-abc` as a positional value
- `allow_interspersed = false` to stop option parsing after first positional
- `parsing_mode = .permissive` to collect unknown options in `remaining`

Run it with:

```bash
zig build run-config_modes
```

## Negated Flags Example

`examples/negated_flags.zig` demonstrates long-flag negation via `--no-<name>`:

- `--no-cache` toggles `cache` to `false` for a `store_true` flag
- `--no-color` toggles `color` to `true` for a `store_false` flag

Run it with:

```bash
zig build run-negated_flags
```

## Positional Validation Example

`examples/positional_validation.zig` demonstrates:

- Positional `choices` validation
- Explicit inverse flag helper `addFalseFlag`
- Non-breaking strict parse behavior with clear constraints

Run it with:

```bash
zig build run-positional_validation
```

## Select/All Example

`examples/select_all.zig` demonstrates CMD-style targeting helpers:

- `addSelectOption` for `--select <value>`
- `addAllFlag` for `--all`
- `addSelectOrAll` for one-call mutually exclusive setup
- `parseCsvList` for parsing comma-separated selection values

Run it with:

```bash
zig build run-select_all
```

## Question Flow Example

`examples/question_flow.zig` demonstrates a production-ready interactive flow:

- Use parsed `--select` / `--all` if present
- Prompt for a choice when arguments are missing
- Validate answers with retries, prefix matching, and suggestions

Run it with:

```bash
zig build run-question_flow
```

## Include/Exclude Example

`examples/include_exclude.zig` demonstrates reusable filter helpers:

- `addIncludeExclude` for CLI schema setup
- `resolveIncludeExclude` for parsed CSV list resolution

Run it with:

```bash
zig build run-include_exclude
```

## Include/Exclude Strict Example

`examples/include_exclude_strict.zig` demonstrates strict filter workflows:

- Choice normalization (`gr` => `groups` when unique)
- Duplicate suppression for repeated values
- Optional `all` keyword handling with exclusions
- Conflict detection between include and exclude values

Run it with:

```bash
zig build run-include_exclude_strict
```

## File Support Example

`examples/file_support.zig` demonstrates path/file/directory helpers:

- `addPathOption` for generic paths
- `addFileOptionWithExtensions` for reusable extension validation
- `addDirectoryOption` for directory-oriented options

Run it with:

```bash
zig build run-file_support
```

## Data Input Validation Example

`examples/data_input_validation.zig` demonstrates typed input validator helpers:

- `addEmailOption`
- `addUrlOption`
- `addIpv4Option`
- `addIpOption`
- `addIpv6Option`
- `addHostNameOption`
- `addPortOption`
- `addEndpointOption`
- `addKeyValueOption`
- `addUuidOption`
- `addIsoDateOption` and `addIsoDateTimeOption`
- `addYearOption` and `addTimeOption`
- `addAbsolutePathOption`
- `addJsonOption`
- Numeric range validation via `Validators.intRange(...)`

This example also shows how to read validated values after parse:

- Use `getString("...")` for helper-backed string values
- Use `getInt("retries")` when the option is configured with `.value_type = .int`
- Use `getKeyValue("label")` for options configured as `KEY=VALUE`

Run it with:

```bash
zig build run-data_input_validation
```

Try a direct invocation shape:

```bash
zig build run-data_input_validation -- \
    --email ops@example.com \
    --endpoint https://api.example.com/v1/tasks \
    --host-v6 2001:db8::1 \
    --service api.example.com:443 \
    --retries 4
```

## Network Endpoints Example

`examples/network_endpoints.zig` demonstrates network-centric typed helpers:

- `addIpv4Option` for IPv4 addresses
- `addIpOption` for a single IPv4-or-IPv6 input
- `addIpv6Option` for IPv6 literals
- `addEndpointOption` for `host:port` and `[ipv6]:port`
- `addPortOption` for explicit port validation
- Numeric retries via `.value_type = .int` + `Validators.intRange(...)`

Run it with:

```bash
zig build run-network_endpoints
```

## Error Handling Example

`examples/error_handling.zig` demonstrates practical parse error handling:

- Duplicate singleton options (`DuplicateArgument`)
- Validator failures (`CustomValidationFailed`)
- Unknown option guidance and suggestion behavior
- Option-level custom hints (`suggestion_hint`) and custom messages (`custom_error_message`)

Run it with:

```bash
zig build run-error_handling
```

## Subcommand Suggestions Example

`examples/subcommand_suggestions.zig` demonstrates built-in closest-match behavior for unknown subcommands and custom unknown-subcommand hints.

Run it with:

```bash
zig build run-subcommand_suggestions
```

## Decryption Options Example

`examples/decryption_options.zig` demonstrates automatic Base64 decoding/decryption behavior for options:

- `addDecryptionOption("secret", .{})` for standard Base64 input
- `addDecryptionOption("session", .{ .url_safe = true })` for URL-safe Base64 input

Run it with:

```bash
zig build run-decryption_options
```

## Counters and Choices Example

Using counters for verbosity and choices for validation:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "logger",
        .description = "A logging utility with verbosity levels",
    });
    defer parser.deinit();

    // Counter: -v, -vv, -vvv for increasing verbosity
    try parser.addCounter("verbose", .{
        .short = 'v',
        .help = "Increase verbosity (can be repeated)",
    });

    // Choices: restricted set of valid values
    try parser.addOption("level", .{
        .short = 'l',
        .help = "Log level",
        .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
        .default = "info",
    });

    try parser.addOption("format", .{
        .short = 'f',
        .help = "Output format",
        .choices = &[_][]const u8{ "json", "text", "csv" },
        .default = "text",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose_val = result.get("verbose");
    const verbosity: u32 = if (verbose_val) |v| v.counter else 0;
    const level = result.getString("level") orelse "info";
    const format = result.getString("format") orelse "text";

    std.debug.print("Verbosity level: {d}\n", .{verbosity});
    std.debug.print("Log level: {s}\n", .{level});
    std.debug.print("Output format: {s}\n", .{format});

    if (verbosity >= 1) std.debug.print("  [v] Basic verbose info\n", .{});
    if (verbosity >= 2) std.debug.print("  [vv] Detailed verbose info\n", .{});
    if (verbosity >= 3) std.debug.print("  [vvv] Maximum verbosity\n", .{});
}
```

**Usage:**
```bash
logger                      # Verbosity: 0, level: info, format: text
logger -v                   # Verbosity: 1
logger -vv                  # Verbosity: 2
logger -vvv -l debug        # Verbosity: 3, level: debug
logger --level error        # level: error
logger --level warn         # level: warn
logger -f json              # format: json
```

## Soft Validation (Expect) Example

Using `.expect` to warn on unexpected values instead of erroring:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "expect-demo",
        .description = "Demonstrates 'expect' validation",
    });
    defer parser.deinit();

    // 'expect' suggests values. Warns on mismatch by default.
    try parser.addOption("env", .{
        .short = 'e',
        .expect = &[_][]const u8{ "dev", "prod", "staging" },
        .help = "Target environment (expected: dev, prod, staging)",
    });

    try parser.addOption("output", .{
        .short = 'o',
        .choices = &[_][]const u8{ "json", "text" }, // Strict validation
        .help = "Output format (strict: json, text)",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const env = result.getString("env") orelse "default";
    const output = result.getString("output") orelse "text";

    std.debug.print("Environment: {s}\n", .{env});
    std.debug.print("Output:      {s}\n", .{output});
}
```

**Usage:**
```bash
# Valid input
expect-demo -e dev -o json

# Invalid 'expect' value (Warnings)
expect-demo -e unknown
# Output:
# Warning: Value 'unknown' is not in expected list for argument 'env'...
# Environment: unknown
```

## Declarative Structs Example

Parsing arguments directly into a Zig struct:

```zig
const std = @import("std");
const args = @import("args");

const Config = struct {
    verbose: bool,
    dry_run: bool,
    output: ?[]const u8,
    count: i32,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parsed = try args.parseInto(allocator, Config, .{
        .name = "struct-demo",
    }, null);
    defer parsed.deinit();

    const cfg = parsed.options;

    std.debug.print("Verbose: {}\n", .{cfg.verbose});
    std.debug.print("Count:   {d}\n", .{cfg.count});
}
```

**Usage:**
```bash
struct-demo --count 10 --verbose
```


## Shell Completions Example

Generating shell completion scripts:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o' });

    try parser.addSubcommand(.{
        .name = "completion",
        .help = "Generate shell completions",
        .args = &[_]args.ArgSpec{
            .{ .name = "shell", .positional = true, .required = true },
        },
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.subcommand) |cmd| {
        if (std.mem.eql(u8, cmd, "completion")) {
            const shell_str = result.subcommand_args.?.getString("shell").?;

            if (args.Shell.fromString(shell_str)) |shell| {
                const script = try parser.generateCompletion(shell);
                defer allocator.free(script);

                const stdout = std.io.getStdOut().writer();
                try stdout.writeAll(script);
            } else {
                std.debug.print("Unknown shell: {s}\n", .{shell_str});
                std.debug.print("Supported: bash, zsh, fish, powershell\n", .{});
            }
        }
    }
}
```

**Usage:**
```bash
# Generate and install Bash completions
myapp completion bash > ~/.local/share/bash-completion/completions/myapp

# Generate and install Zsh completions
myapp completion zsh > ~/.zfunc/_myapp

# Generate and install Fish completions
myapp completion fish > ~/.config/fish/completions/myapp.fish
```

## Disabling Update Checker

For production or CI/CD environments:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Method 1: Global disable
    args.disableUpdateCheck();

    // Method 2: Use minimal config
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "production-app",
        .config = args.Config.minimal(),
    });
    defer parser.deinit();

    // Your argument definitions...
}
```

## Typed Numeric Options Example

Using `addIntOption`, `addFloatOption`, and `addUintOption` helpers:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "numeric-demo",
        .version = "1.0.0",
        .description = "Demonstrates typed integer and float options",
    });
    defer parser.deinit();

    try parser.addIntOption("count", .{
        .short = 'n', .help = "Number of items", .default = "10",
    });

    try parser.addIntOption("retries", .{
        .short = 'r', .help = "Retry count (0–10)", .default = "3",
        .min = 0, .max = 10,
    });

    try parser.addUintOption("threads", .{
        .short = 't', .help = "Worker thread count", .default = "4",
    });

    try parser.addFloatOption("threshold", .{
        .short = 'h', .help = "Confidence threshold (0.0–1.0)", .default = "0.75",
        .min = 0.0, .max = 1.0,
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    std.debug.print("count     = {d}\n", .{result.get("count").?.asInt().?});
    std.debug.print("retries   = {d} (range 0–10)\n", .{result.get("retries").?.asInt().?});
    std.debug.print("threads   = {d}\n", .{result.get("threads").?.asUint().?});
    std.debug.print("threshold = {d:.2} (range 0.0–1.0)\n", .{result.get("threshold").?.asFloat().?});
}
```

**Usage:**
```bash
numeric-demo --count 25 --retries 5 --threads 8 --threshold 0.95
```

## Bool Options Example

Case-insensitive boolean option parsing — `TRUE`/`True`/`true`, `FALSE`/`False`/`false`, `YES`/`yes`, `NO`/`no`, `ON`/`on`, `OFF`/`off` and single-letter variants are all accepted:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bool-demo",
        .version = "1.0.0",
        .description = "Demonstrates case-insensitive boolean option parsing",
    });
    defer parser.deinit();

    try parser.addOption("enabled", .{
        .short = 'e',
        .help = "Enable feature (accepts: true/TRUE/True/yes/YES/on/ON/1)",
        .value_type = .bool,
        .default = "true",
    });

    try parser.addOption("debug", .{
        .short = 'd',
        .help = "Debug mode (accepts: false/FALSE/False/no/NO/off/OFF/0)",
        .value_type = .bool,
        .default = "false",
    });

    try parser.addFlag("flag", .{
        .short = 'f',
        .help = "Simple flag (no value needed)",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const enabled = result.getBool("enabled") orelse true;
    const debug = result.getBool("debug") orelse false;
    const flag = result.getBool("flag") orelse false;

    std.debug.print("enabled = {}  (type: bool)\n", .{enabled});
    std.debug.print("debug   = {}  (type: bool)\n", .{debug});
    std.debug.print("flag    = {}  (type: bool, store_true)\n", .{flag});
}
```

**Usage:**
```bash
# All of these work the same way:
zig build run-bool_options -- --enabled TRUE --debug false
zig build run-bool_options -- -e True -d No
zig build run-bool_options -- --enabled yes --debug OFF
zig build run-bool_options -- --enabled 1 --debug 0
zig build run-bool_options -- -f        # flag is store_true — no value needed
```

## Hex Decode Option Example

Passing binary data as hex strings with `addHexOption`:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "hex-demo",
        .version = "1.0.0",
        .description = "Demonstrates hex-decode option",
    });
    defer parser.deinit();

    try parser.addHexOption("data", .{
        .short = 'd', .help = "Hex-encoded binary data", .metavar = "HEX",
    });

    try parser.addHexOption("key", .{
        .short = 'k', .help = "Hex-encoded key material", .required = true,
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.get("data")) |d| {
        std.debug.print("--data decoded: {any} ({d} bytes)\n", .{ d.asString().?, (d.asString() orelse "").len });
    }
    if (result.get("key")) |k| {
        std.debug.print("--key  decoded: {any} ({d} bytes)\n", .{ k.asString().?, (k.asString() orelse "").len });
    }
}
```

**Usage:**
```bash
hex-demo --data deadbeef --key 0123456789abcdef
```

## Log Level Example

Using `addLogLevel` for `--verbose` / `--quiet` pairs:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "log-demo",
        .version = "1.0.0",
        .description = "Demonstrates log-level helpers",
    });
    defer parser.deinit();

    try parser.addLogLevel(
        .{ .name = "verbose", .short = 'v', .dest = "verbosity" },
        .{ .name = "quiet",   .short = 'q', .dest = "verbosity" },
    );

    try parser.addFlag("dry-run", .{ .help = "Simulate execution" });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbosity = result.get("verbosity").?.asInt().? orelse 0;
    std.debug.print("Verbosity level: {d}\n", .{verbosity});
    if (verbosity >= 1) std.debug.print("  verbose mode\n", .{});
    if (verbosity >= 2) std.debug.print("  debug output\n", .{});
}
```

**Usage:**
```bash
log-demo -vvv              # Verbosity level: 3
log-demo -v -q             # Verbosity level: 0
log-demo -v -v -qq         # Verbosity level: 0
```

## Advanced parseInto Example

Parsing into a struct with enums, u32, f64, and optional fields. Enum variants become `--flag` choices automatically:

```zig
const std = @import("std");
const args = @import("args");

const LogLevel = enum { debug, info, warn, err };
const OutputFormat = enum { json, yaml, csv, table };

const CliConfig = struct {
    verbose: bool = false,
    log_level: LogLevel = .info,
    format: OutputFormat = .table,
    port: u32 = 8080,
    timeout: f64 = 30.0,
    host: []const u8 = "localhost",
    config_file: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var result = try args.parseInto(allocator, CliConfig, .{
        .name = "struct-demo",
        .version = "1.0.0",
        .description = "parseInto with enums, u32, f64, and more",
    }, null, init);
    defer result.deinit();

    const cfg = result.options;

    std.debug.print("Configuration:\n", .{});
    std.debug.print("  verbose     = {}\n", .{cfg.verbose});
    std.debug.print("  log-level   = {s}\n", .{@tagName(cfg.log_level)});
    std.debug.print("  format      = {s}\n", .{@tagName(cfg.format)});
    std.debug.print("  port        = {d}\n", .{cfg.port});
    std.debug.print("  timeout     = {d:.1}s\n", .{cfg.timeout});
    std.debug.print("  host        = {s}\n", .{cfg.host});
    if (cfg.config_file) |f| {
        std.debug.print("  config-file = {s}\n", .{f});
    }
}
```

**Usage:**
```bash
struct-demo --verbose --log-level debug --format json --port 3000 --timeout 60.0 --host 0.0.0.0
```

## Environment Variable Configuration Example

Using `env_var`, `env_prefix`, and `fromEnvOrDefault`:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "env-demo",
        .version = "1.0.0",
        .description = "Demonstrates environment variable configuration",
        .config = args.Config{ .env_prefix = "MYAPP" },
    });
    defer parser.deinit();

    try parser.addOption("db-host", .{
        .short = 'h', .help = "Database host", .default = "localhost",
        .env_var = "MYAPP_DB_HOST",
    });

    try parser.addIntOption("db-port", .{
        .short = 'p', .help = "Database port", .default = "5432",
        .env_var = "MYAPP_DB_PORT",
    });

    try parser.addOption("db-name", .{
        .short = 'd', .help = "Database name", .default = "mydb",
        .env_var = "MYAPP_DB_NAME",
    });

    try parser.fromEnvOrDefault("api-key", "MYAPP_API_KEY", "no-key-set", .{
        .help = "API key (from MYAPP_API_KEY env var)",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    std.debug.print("DB Host: {s}\n", .{result.get("db-host").?.asString().?});
    std.debug.print("DB Port: {d}\n", .{result.get("db-port").?.asInt().?});
    std.debug.print("DB Name: {s}\n", .{result.get("db-name").?.asString().?});
    std.debug.print("API Key: {s}\n", .{result.get("api-key").?.asString().?});
}
```

**Usage:**
```bash
# Values from command-line:
env-demo -h prod.example.com -p 5432 -d analytics

# Values from environment variables:
export MYAPP_DB_HOST=prod.example.com
export MYAPP_DB_PORT=5432
env-demo
```

## Advanced Argument Relations Example

Demonstrates mutual exclusion, conditional requirements, and dependencies between options and flags:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ap = try args.createParser(allocator, "conflict-demo");
    defer ap.deinit();

    ap.description = "Advanced argument validation and relations (conflicts/requires/exclusions)";

    try ap.addFlag("mysql", .{ .help = "Use MySQL backend" });
    try ap.addFlag("postgres", .{ .help = "Use PostgreSQL backend" });
    try ap.addOption("host", .{ .help = "Server host address" });
    try ap.addOption("port", .{ .help = "Server port" });
    try ap.addOption("user", .{ .help = "Username" });
    try ap.addOption("password", .{ .help = "Password" });

    // Exclude MySQL and Postgres backends from being used together
    try ap.addMutualExclusion(&[_][]const u8{ "mysql", "postgres" });

    // Host and user are conditionally required when backends are active
    try ap.addRequiredIf("host", "mysql", null);
    try ap.addRequiredIf("host", "postgres", null);
    try ap.addRequiredIf("user", "mysql", null);
    try ap.addRequiredIf("user", "postgres", null);

    // Password requires username
    try ap.addRequires("password", "user");

    var init = std.process.Init.init;
    var result = ap.parseProcess(init) catch |err| {
        std.debug.print("Failed to parse arguments: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    std.debug.print("Validated database configuration!\n", .{});
}
```

## Configuration Warnings & Auto-Resolution Example

Demonstrates checking configuration consistency at runtime and automatically resolving any conflicts:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const cfg = args.Config{
        .parsing_mode = .permissive,
        .exit_on_error = true,
        .use_colors = true,
        .silent_errors = true,
        .suggest_closest = true,
        .suggestion_max_distance = 0,
    };

    var ap = try args.createParserWithConfig(allocator, "config-warnings-demo", cfg);
    defer ap.deinit();

    var warn_buf: [16]args.config.ConfigWarning = undefined;
    const count = ap.getConfigWarnings(&warn_buf);

    std.debug.print("Detected {d} configuration conflicts:\n", .{count});
    for (warn_buf[0..count], 1..) |warn, idx| {
        std.debug.print("{d}. [{s}] {s}\n", .{ idx, warn.field, warn.message });
    }

    ap.configureAutoResolve();
    std.debug.print("Resolved Config color mode: {}\n", .{ap.cfg.use_colors});
}
```

## Duration, Byte-Size, & Range Validation Example

Demonstrates options parsing duration formats (e.g. `1h30m`), byte sizes (e.g. `512MB`), or range-bounded numbers:

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ap = try args.createParser(allocator, "duration-size-demo");
    defer ap.deinit();

    try ap.addDurationOption("timeout", .{ .default = "30s" });
    try ap.addSizeOption("buffer-size", .{ .default = "64MB" });
    try ap.addRangeOption("concurrency", i64, comptime .{ .min = 1, .max = 8, .default = "2" });

    var init = std.process.Init.init;
    var result = ap.parseProcess(init) catch |err| {
        std.debug.print("Argument validation failed: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    std.debug.print("Timeout seconds: {d}\n", .{result.getDuration("timeout").?});
    std.debug.print("Buffer bytes: {d}\n", .{result.getSize("buffer-size").?});
    std.debug.print("Concurrency: {d}\n", .{result.get("concurrency").?.asInt().?});
}
```

## Bracketed List Example

Parse bracket-delimited inline lists as arrays:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bracketed-list",
        .version = "1.0.0",
        .description = "Demonstrates bracket-delimited value parsing",
    });
    defer parser.deinit();

    try parser.addBracketedListOption("tags", .{ .short = 't' });
    try parser.addBracketedListOption("files", .{ .short = 'f', .bracket_type = .curly });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getArray("tags")) |tags| {
        for (tags, 0..) |tag, i| std.debug.print("  [{d}] {s}\n", .{ i, tag });
    }
    if (result.getArray("files")) |files| {
        for (files, 0..) |f, i| std.debug.print("  [{d}] {s}\n", .{ i, f });
    }
}
```

**Usage:**
```bash
zig build run-bracketed_list -- --tags {a,b,c} --files {x,y}
```

## Format Option Example

File format detection and extension helpers:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "format-demo",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFormatOption("input-format", .{ .short = 'f', .default = "json", .formats = &[_][]const u8{ "json", "yaml", "csv" } });
    try parser.addExtensionOption("output-ext", .{ .short = 'o', .default = ".json", .extensions = &[_][]const u8{ ".json", ".yaml", ".csv" } });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const fmt = result.getString("input-format") orelse "json";
    const ext = result.getString("output-ext") orelse ".json";
    std.debug.print("Format: {s} / Ext: {s}\n", .{ fmt, ext });
}
```

**Usage:**
```bash
zig build run-format_option -- --input-format yaml --output-ext .yaml
```

## Fallback Parse Example

Use `parseOr` / `parseProcessOr` with `getOr*` methods for graceful error recovery:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "fallback-demo",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addCounter("verbosity", .{ .short = 'd' });

    // parseOr never fails — returns empty result on error
    var result = parser.parseOr(&[_][]const u8{}, null);
    defer result.deinit();

    const verbose = result.getOrBool("verbose", false);
    const counter = result.getOrCounter("verbosity", 0);

    // parseProcessOr wraps parseProcess with fallback
    var result2 = parser.parseProcessOr(init, null);
    defer result2.deinit();

    const name = result2.getOrString("name", "default");
    std.debug.print("verbose={} counter={} name={s}\n", .{ verbose, counter, name });
}
```

**Usage:**
```bash
zig build run-fallback_parse -- -v -ddd
```

## Append Option Example

Repeated options stored as arrays:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "append-demo",
        .version = "1.0.0",
    });
    defer parser.deinit();

    try parser.addAppend("include", .{ .short = 'I', .metavar = "DIR" });
    try parser.addOption("output", .{ .short = 'o', .default = "out" });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getArray("include")) |paths| {
        for (paths, 0..) |p, i| std.debug.print("  [{d}] {s}\n", .{ i, p });
    }
    std.debug.print("Output: {s}\n", .{result.getOrString("output", "out")});
}
```

**Usage:**
```bash
zig build run-append_option -- -I src -I include -I lib -o result
```

## Multi-Value (n-args) Example

Variadic argument collection using n-args:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "multi-value",
        .version = "1.0.0",
    });
    defer parser.deinit();

    // one_or_more: requires at least one value
    try parser.addOption("source", .{ .short = 's', .nargs = .one_or_more });
    try parser.addPositional("target", .{ .required = true });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    if (result.getArray("source")) |sources| {
        for (sources, 0..) |src, i| std.debug.print("  [{d}] {s}\n", .{ i, src });
    }
    std.debug.print("Target: {s}\n", .{result.getOrString("target", "?")});
}
```

**Usage:**
```bash
zig build run-multi_value -- --source a.txt b.txt c.txt ./output
```

## Running the Examples

Build and run examples with:

```bash
# Build all examples
zig build

# Run basic example
zig build run-basic

# Run bool options example
zig build run-bool_options

# Run advanced example
zig build run-advanced

# Run conflict demo example
zig build run-conflict_demo

# Run config warnings example
zig build run-config_warnings

# Run duration and size example
zig build run-duration_size

# Run typed numeric options
zig build run-int_float_options

# Run hex decode example
zig build run-hex_option

# Run log level example
zig build run-log_level

# Run advanced struct/parseInto example
zig build run-advanced_struct

# Run env var config example
zig build run-env_var_config

# Run list option example
zig build run-list_option

# Run validation demo example
zig build run-validation_demo

# Run update check example
zig build run-update_check
```
