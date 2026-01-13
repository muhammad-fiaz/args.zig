---
title: Environment Variables
description: Use environment variables as fallback values for command-line arguments in args.zig.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, environment variables, env vars, configuration, fallback
---

# Environment Variables

args.zig supports using environment variables as fallback values for options.

## Basic Usage

Set the `env_var` field when adding an option:

```zig
try parser.addOption("token", .{
    .help = "API authentication token",
    .env_var = "API_TOKEN",
    .required = true,
});
```

With this configuration:
1. If `--token` is provided on command line, use that value
2. Otherwise, check if `$API_TOKEN` environment variable is set
3. If neither is set and option is required, return an error

## Priority Order

Values are resolved in this order (highest priority first):

1. **Command-line argument** - Always takes precedence
2. **Environment variable** - Used if CLI argument not provided
3. **Default value** - Used if neither CLI nor env var provided

## Example

```zig
try parser.addOption("database-url", .{
    .short = 'd',
    .help = "Database connection URL",
    .env_var = "DATABASE_URL",
    .default = "postgres://localhost:5432/mydb",
});
```

```bash
# Uses command-line value
myapp --database-url postgres://prod:5432/db

# Uses environment variable
export DATABASE_URL="postgres://staging:5432/db"
myapp

# Uses default value (if no env var set)
myapp
```

## Environment Variable Prefix

Set a global prefix for all environment variables. When a prefix is set, args.zig will also automatically look for environment variables named `PREFIX_NAME` (where NAME is the argument name in uppercase) even if `.env_var` is not explicitly set on the argument.

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .env_prefix = "MYAPP" }, // e.g. "MYAPP"
});

// Explicit environment variable (falls back to MYAPP_CONFIG_FILE if CONFIG_FILE not found? No, explicit takes precedence)
// Current logic: If .env_var is set, use it. If not, use PREFIX_ARGNAME.
try parser.addOption("config", .{
    .help = "Config file",
    // No .env_var set, but with prefix "MYAPP", it will look for "MYAPP_CONFIG"
});

try parser.addOption("port", .{
    .help = "Port",
    .env_var = "SERVICE_PORT", // Will look for "SERVICE_PORT" (ignores prefix if explicit env_var set)
});
```

## Multiple Options with Env Vars

```zig
try parser.addOption("host", .{
    .help = "Server hostname",
    .env_var = "SERVER_HOST",
    .default = "localhost",
});

try parser.addOption("port", .{
    .help = "Server port",
    .value_type = .int,
    .env_var = "SERVER_PORT",
    .default = "8080",
});

try parser.addOption("api-key", .{
    .help = "API key for authentication",
    .env_var = "API_KEY",
    .required = true,
});
```

## Displaying Env Vars in Help

By default, environment variable names are shown in help text:

```
OPTIONS:
    --host <STRING>       Server hostname [env: SERVER_HOST] [default: localhost]
    --port <INT>          Server port [env: SERVER_PORT] [default: 8080]
    --api-key <STRING>    API key [env: API_KEY] [required]
```

Disable this with configuration:

```zig
.config = .{ .show_env_vars = false }
```

## Boolean Env Vars

Environment variables for boolean options accept:

| True Values | False Values |
|-------------|--------------|
| `true`, `yes`, `1`, `on`, `y`, `t` | `false`, `no`, `0`, `off`, `n`, `f` |

```zig
try parser.addFlag("verbose", .{
    .env_var = "VERBOSE",
});
```

```bash
export VERBOSE=true
myapp  # verbose mode enabled
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "server",
        .version = "1.0.0",
        .description = "A server with environment variable configuration",
    });
    defer parser.deinit();

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

    try parser.addFlag("debug", .{
        .short = 'd',
        .help = "Enable debug mode",
    });

    var result = try parser.parseProcess();
    defer result.deinit();

    const host = result.getString("host").?;
    const port = result.getInt("port").?;
    const secret = result.getString("secret").?;
    const debug = result.getBool("debug") orelse false;

    std.debug.print("Starting server:\n", .{});
    std.debug.print("  Host: {s}\n", .{host});
    std.debug.print("  Port: {d}\n", .{port});
    std.debug.print("  Secret: {s}...\n", .{secret[0..@min(4, secret.len)]});
    std.debug.print("  Debug: {}\n", .{debug});
}
```

Run with environment variables:

```bash
export SERVER_SECRET="my-super-secret-key"
export SERVER_PORT="3000"
./server --host 127.0.0.1
```
