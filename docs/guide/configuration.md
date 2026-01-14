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
    check_for_updates: bool = false,
    show_update_notification: bool = true,
    
    // Display options
    use_colors: bool = true,
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
    case_sensitive: bool = true,
    env_prefix: ?[]const u8 = null,
    silent_errors: bool = false, // Suppress error output (for tests)
    
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
| `check_for_updates` | `false` | Check for new versions on GitHub |
| `show_update_notification` | `true` | Display notification if update available |

### Display Options

| Option | Default | Description |
|--------|---------|-------------|
| `use_colors` | `true` | Use ANSI colors in help output |
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
| `case_sensitive` | `true` | Case-sensitive option matching |
| `env_prefix` | `null` | Prefix for environment variables |
| `silent_errors` | `false` | Suppress error/warning prints (for tests) |

### Application Metadata (Global Defaults)

| Option | Default | Description |
|--------|---------|-------------|
| `app_name` | `null` | Default application name for all parsers |
| `app_version` | `null` | Default application version |
| `app_description` | `null` | Default application description |
| `app_epilog` | `null` | Default epilog text (shown after help) |
| `app_author` | `null` | Application author information |

## Configuration Presets

### Default Configuration

All features enabled:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.default(),
});
```

### Minimal Configuration

No colors, no updates, no exit on error:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.minimal(),
});
```

### Verbose Configuration

Extra debugging information:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = args.Config.verbose(),
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
