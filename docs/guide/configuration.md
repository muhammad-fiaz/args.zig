---
title: Configuration
description: Configure args.zig parser behavior including colors, help formatting, parsing modes, and update checking.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, configuration, config, parser options, customization
---

# Configuration

args.zig provides flexible configuration options to customize parser behavior.

## Config Struct

```zig
const args = @import("args");

const Config = struct {
    // Update checking
    check_for_updates: bool = true,
    show_update_notification: bool = true,
    
    // Display options
    use_colors: bool = true,
    colors: ?args.ColorTheme = null,
    help_line_width: usize = 80,
    help_indent: usize = 24,
    show_defaults: bool = true,
    show_env_vars: bool = true,
    program_name: ?[]const u8 = null,
    
    // Parsing behavior
    exit_on_error: bool = true,
    parsing_mode: ParsingMode = .strict,
    allow_short_clusters: bool = true,
    allow_inline_values: bool = true,
    allow_interspersed: bool = true,
    allow_negated_flags: bool = true,
    allow_brackets: bool = true,
    case_sensitive: bool = true,
    env_prefix: ?[]const u8 = null,
    silent_errors: bool = false, // Suppress error output (for tests)
    suggest_closest: bool = true,
    suggestion_max_distance: usize = 3,
    suggest_builtin_commands: bool = true,
    suggest_subcommands: bool = true,
    error_prefix: []const u8 = "Error",
    warning_prefix: []const u8 = "Warning",
    unknown_option_hint: ?[]const u8 = null,
    unknown_subcommand_hint: ?[]const u8 = null,
    unknown_option_message: ?[]const u8 = null,
    unknown_subcommand_message: ?[]const u8 = null,
    
    // Global Application Metadata (centralized defaults)
    app_name: ?[]const u8 = null,
    app_version: ?[]const u8 = null,
    app_description: ?[]const u8 = null,
    app_epilog: ?[]const u8 = null,
    app_author: ?[]const u8 = null,
};
```



## Configuration Options

### Update Checking

| Option | Default | Description |
|--------|---------|-------------|
| `check_for_updates` | `true` | Check for new versions on GitHub |
| `show_update_notification` | `true` | Display notification if update available |

### Display Options

| Option | Default | Description |
|--------|---------|-------------|
| `use_colors` | `true` | Use ANSI colors in help output |
| `colors` | `null` | Optional theme override for colored output |
| `help_line_width` | `80` | Maximum line width for help text |
| `help_indent` | `24` | Indentation for option descriptions |
| `show_defaults` | `true` | Show default values in help |
| `show_env_vars` | `true` | Show environment variable fallbacks |
| `program_name` | `null` | Override program name displayed in help |

### Parsing Behavior

| Option | Default | Description |
|--------|---------|-------------|
| `exit_on_error` | `true` | Exit on parse errors |
| `parsing_mode` | `.strict` | How to handle unknown arguments |
| `allow_short_clusters` | `true` | Allow `-abc` as `-a -b -c` |
| `allow_inline_values` | `true` | Allow `--opt=value` format |
| `allow_interspersed` | `true` | Allow options after positionals |
| `allow_negated_flags` | `true` | Allow `--no-flag` for boolean long options |
| `allow_brackets` | `true` | Allow bracket-delimited list values `{a,b}`, `[a,b]`, `<a,b>` |
| `case_sensitive` | `true` | Case-sensitive option matching |
| `env_prefix` | `null` | Prefix for environment variables |
| `silent_errors` | `false` | Suppress error/warning prints (for tests) |
| `suggest_closest` | `true` | Show spelling suggestions for close matches |
| `suggestion_max_distance` | `3` | Max edit distance for suggestion matching |
| `suggest_builtin_commands` | `true` | Include `--help` and `--version` in unknown-option suggestions |
| `suggest_subcommands` | `true` | Enable closest-match suggestions for unknown subcommands |
| `error_prefix` | `"Error"` | Prefix used for parse error output |
| `warning_prefix` | `"Warning"` | Prefix used for warning output |
| `unknown_option_hint` | `null` | Custom hint text printed for unknown options |
| `unknown_subcommand_hint` | `null` | Custom hint text printed for unknown subcommands |
| `unknown_option_message` | `null` | Override default unknown-option error text |
| `unknown_subcommand_message` | `null` | Override default unknown-subcommand error text |

### Application Metadata (Global Defaults)

| Option | Default | Description |
|--------|---------|-------------|
| `app_name` | `null` | Default application name for all parsers |
| `app_version` | `null` | Default application version |
| `app_description` | `null` | Default application description |
| `app_epilog` | `null` | Default epilog text (shown after help) |
| `app_author` | `null` | Application author information |

### Help Formatting Notes

- `program_name` overrides the executable name displayed in generated help usage lines.
- `help_indent` controls the alignment column used for option descriptions.
- `help_line_width` is used to wrap long option descriptions and metadata blocks.
- `app_author` is printed in help output when set.

## Color Themes

args.zig ships with a standard palette and a brighter preset. You can override colors globally:

```zig
const args = @import("args");

args.initConfig(.{
    .use_colors = true,
    .colors = args.ColorTheme.bright(),
});
```

To fully disable color codes, set `use_colors = false` (all theme fields are ignored).

## Configuration Presets

### Default Configuration

All features enabled, strict parsing, and standard theme:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.default(),
});
```

### Minimal Configuration

No colors, no updates, no exit on error, and silent:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(),
});
```

### Verbose Configuration

Extra debugging information showing all defaults and env vars:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.verbose(),
});
```

### Colorful Configuration

Forces colorful output with a bright preconfigured color theme:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.colorful(),
});
```

### Testing Configuration

Specifically configured for unit tests. Suppresses errors, disables updates and exit behavior:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.testing(),
});
```

### CI Configuration

Strict mode, exit on error, spelling suggestions, but disables all color codes (pipe-safe) and update checks:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.ci(),
});
```

### Production Configuration

Enforces color themes, automatic update notifications, spelling suggestions, and exit on error:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.production(),
});
```

## Custom Configuration

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{
        .use_colors = true,
        .check_for_updates = false,
        .show_defaults = true,
        .exit_on_error = false,
    },
});
```

## Global Configuration

Set configuration globally before creating parsers. This is ideal for centralizing application metadata:

```zig
// Initialize global config with app metadata
args.initConfig(.{
    .app_name = "myapp",
    .app_version = "1.0.0",
    .app_description = "My amazing application",
    .app_author = "Your Name",
    .use_colors = true,
    .check_for_updates = false,
});

// Parsers automatically inherit these values
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "", // Uses app_name from global config
});

// Or use parseInto which also respects global config
const Config = struct { verbose: bool };
var parsed = try args.parseInto(allocator, Config, .{
    .name = "", // Uses app_name from global config
}, null);

```

### Benefits of Global Configuration

- **Centralized metadata**: Define app name, version, description once
- **Consistent behavior**: All parsers share the same settings
- **Override when needed**: Per-parser config takes precedence


## Disabling Update Checks

### Method 1: Global Disable

```zig
args.disableUpdateCheck();
```

### Method 2: Per-Parser Config

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .check_for_updates = false },
});
```

### Method 3: Minimal Preset

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(),
});
```

## Parsing Modes

### Strict Mode (default)

Errors on unknown options:

```zig
.config = .{ .parsing_mode = .strict }
```

### Permissive Mode

Collects unknown options without error:

```zig
.config = .{ .parsing_mode = .permissive }
```

### Ignore Unknown Mode

Silently ignores unknown options:

```zig
.config = .{ .parsing_mode = .ignore_unknown }
```

## Advanced Behavior Flags

### Disable Short Clusters

When disabled, `-abc` is treated as a positional value instead of `-a -b -c`.

```zig
.config = .{ .allow_short_clusters = false }
```

### Disable Inline Values

When disabled, `--output=file.txt` and `-o=file.txt` are rejected as invalid format.

```zig
.config = .{ .allow_inline_values = false }
```

### Disable Interspersed Options

When disabled, all values after the first positional are treated as positional.

```zig
.config = .{ .allow_interspersed = false }
```

### Case-Insensitive Matching

When disabled, long option lookup and `choices` / `expect` value checks become ASCII case-insensitive.

```zig
.config = .{ .case_sensitive = false }
// --VERBOSE matches --verbose
// --level DEBUG matches choices = { "debug", ... }
```

### Disable Negated Long Flags

When disabled, `--no-<name>` is treated as unknown.

```zig
.config = .{ .allow_negated_flags = false }
```

## Configuration Validation & Auto-Resolution

args.zig includes a built-in static analysis engine for configuration to detect conflicting or redundant flags at runtime and auto-resolve them safely.

### Config Warnings & Severity

```zig
pub const ConfigWarningSeverity = enum {
    note,
    warning,
    @"error",
};

pub const ConfigWarning = struct {
    field: []const u8,
    message: []const u8,
    severity: ConfigWarningSeverity = .warning,
    auto_resolved: bool = false,
};
```

### Validate Config Combinations

Call `validate` to check a configuration struct for inconsistent options:

```zig
var warn_buf: [16]args.config.ConfigWarning = undefined;
const count = config.validate(&warn_buf);
```

### Auto-Resolve Conflicts

You can obtain a safe, auto-resolved copy of any configuration by calling `autoResolve()`:

```zig
const conflicting_config = args.Config{
    .parsing_mode = .permissive,
    .exit_on_error = true, // Conflict: exit_on_error has no effect in permissive
};

const clean_config = conflicting_config.autoResolve();
// clean_config.exit_on_error is now false
```

## Configuration Utility Methods

### Config Merging

You can shallow-merge two configurations using `.merge()`. Fields from the patch override default fields of the base:

```zig
const base = args.Config.default();
const patch = args.Config{ .use_colors = false };

const merged = base.merge(patch);
// merged.use_colors is now false, while other fields remain default
```

### Config Snapshots

Generate a perfect duplicate snapshot of the current configuration:

```zig
const copy = cfg.snapshot();
```

## Global Auto-Resolution & Utilities

Use these global functions to manage shared behavior across multiple parsers:

### Auto-Resolving Initialization

Initialize the global configuration, print colored warning messages to `stderr` for any conflicts, and apply resolved changes:

```zig
args.initConfigAutoResolve(.{
    .parsing_mode = .permissive,
    .exit_on_error = true,
});
```

### Set Config Field Globally

Directly mutate a single global configuration value:

```zig
args.setConfigValue("use_colors", false);
```

### Validate Global Config

Validate the currently active global configuration at runtime:

```zig
var buf: [16]args.config.ConfigWarning = undefined;
const count = args.validateConfig(&buf);
```
