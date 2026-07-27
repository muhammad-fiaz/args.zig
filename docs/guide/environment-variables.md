---
title: Environment Variables
description: Complete guide to environment variable support in args.zig — fallback values, auto-derived names, prefix derivation, validation, and security.
head:
  - - meta
    - name: keywords
      content: zig, args.zig, environment variables, env vars, configuration, fallback, env_prefix, addEnvOption
---

# Environment Variables

args.zig provides first-class environment variable support with automatic name derivation, prefix-based namespacing, and validation of env-sourced values.

## Priority Order

Values are resolved in this order (highest priority first):

1. **Command-line argument** — Always takes precedence
2. **Environment variable** — Used if CLI argument not provided
3. **Default value** — Used if neither CLI nor env var provided

```zig
try parser.addOption("host", .{
    .env_var = "SERVER_HOST",
    .default = "localhost",
});
```

```bash
# CLI wins over everything
myapp --host prod.example.com

# Env var wins over default
export SERVER_HOST=staging.example.com
myapp

# Default used when nothing else is set
myapp
```

## Explicit Environment Variables

Set the `env_var` field on any option:

```zig
try parser.addOption("database-url", .{
    .short = 'd',
    .help = "Database connection URL",
    .env_var = "DATABASE_URL",
    .default = "postgres://localhost:5432/mydb",
});

try parser.addIntOption("port", .{
    .short = 'p',
    .help = "Server port",
    .env_var = "SERVER_PORT",
    .default = "8080",
});

try parser.addFlag("verbose", .{
    .short = 'v',
    .help = "Verbose output",
    .env_var = "VERBOSE",
});
```

## Automatic Environment Variable Derivation (`addEnvOption`)

`addEnvOption` auto-derives the env var name from the option name:

- Hyphens → underscores
- Uppercased

```zig
try parser.addEnvOption("db-host", .{
    .help = "Database host",
    .default = "localhost",
});
// Looks for: DB_HOST

try parser.addEnvOption("api-key", .{
    .help = "API key",
    .default = "not-set",
});
// Looks for: API_KEY

try parser.addEnvOption("log-level", .{
    .help = "Log level",
    .default = "info",
});
// Looks for: LOG_LEVEL
```

Override with explicit `env_var`:

```zig
try parser.addEnvOption("token", .{
    .help = "Auth token",
    .env_var = "MYAPP_AUTH_TOKEN",  // Uses this instead of TOKEN
});
```

## Environment Variable Prefix (`env_prefix`)

Set a global prefix for all options. Options without an explicit `env_var` get `PREFIX_NAME` derived automatically:

```zig
var parser = try args.ArgumentParser.init(allocator, .{
    .name = "myapp",
    .config = .{ .env_prefix = "MYAPP" },
});

// Looks for: MYAPP_DB_HOST
try parser.addOption("db-host", .{
    .help = "Database host",
    .default = "localhost",
});

// Looks for: MYAPP_DB_PORT
try parser.addIntOption("db-port", .{
    .help = "Database port",
    .default = "5432",
});

// Explicit env_var overrides prefix: looks for SERVICE_PORT
try parser.addOption("service-port", .{
    .help = "Service port",
    .env_var = "SERVICE_PORT",
});
```

### Derivation Rules

| Option Name | Prefix | Derived Env Var |
|-------------|--------|-----------------|
| `db-host` | `MYAPP` | `MYAPP_DB_HOST` |
| `api-key` | `MYAPP` | `MYAPP_API_KEY` |
| `log-level` | `APP` | `APP_LOG_LEVEL` |
| `port` | `SRV` | `SRV_PORT` |

The derivation:
1. Starts with `PREFIX_`
2. Appends the option name (or long name)
3. Replaces hyphens with underscores
4. Uppercases everything

## `fromEnvOrDefault` Helper

One-liner for env var with explicit default:

```zig
try parser.fromEnvOrDefault("api-key", "MYAPP_API_KEY", "no-key-set", .{
    .help = "API key from environment",
});
```

Equivalent to:
```zig
try parser.addOption("api-key", .{
    .help = "API key from environment",
    .env_var = "MYAPP_API_KEY",
    .default = "no-key-set",
});
```

## Validation of Environment Variable Values

> [!NOTE]
> Environment variable values are validated against the same validators as CLI arguments. If a validator rejects an env var value, parsing fails with a clear error message.

```zig
try parser.addIntOption("port", .{
    .env_var = "SERVER_PORT",
    .default = "8080",
    .validator = validation.Validators.intRange(1, 65535),
});

try parser.addOption("email", .{
    .env_var = "ADMIN_EMAIL",
    .validator = validation.Validators.emailAddress,
});
```

```bash
# This fails with: environment variable SERVER_PORT for 'port' is invalid: integer is out of range
export SERVER_PORT=99999
myapp
```

### Security Benefits

Validation of env-sourced values provides:

- **Type safety** — Env vars are strings; validators ensure they match expected formats
- **Range checking** — Numeric env vars are checked against min/max bounds
- **Format validation** — Email, URL, IP, UUID, etc. env vars are format-checked
- **Injection prevention** — Malformed env var values are rejected before processing

## Boolean Environment Variables

Boolean options accept these env var values:

| True Values | False Values |
|-------------|--------------|
| `true`, `yes`, `1`, `on`, `y`, `t` | `false`, `no`, `0`, `off`, `n`, `f` |

```zig
try parser.addFlag("verbose", .{
    .env_var = "VERBOSE",
});
```

```bash
export VERBOSE=true   # or "1", "yes", "on"
myapp                 # verbose mode enabled
```

## Displaying Env Vars in Help

By default, env var names appear in help text:

```
OPTIONS:
    --host <STRING>       Server hostname [env: SERVER_HOST] [default: localhost]
    --port <INT>          Server port [env: SERVER_PORT] [default: 8080]
    --api-key <STRING>    API key [env: API_KEY] [required]
```

Disable with:

```zig
.config = .{ .show_env_vars = false }
```

## Complete Example

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "server",
        .version = "1.0.0",
        .description = "Server with environment variable configuration",
        .config = .{ .env_prefix = "SERVER" },
    });
    defer parser.deinit();

    // Explicit env var
    try parser.addOption("host", .{
        .short = 'H',
        .help = "Server hostname",
        .env_var = "SERVER_HOST",
        .default = "0.0.0.0",
    });

    // Auto-derived: SERVER_PORT
    try parser.addIntOption("port", .{
        .short = 'p',
        .help = "Server port",
        .default = "8080",
    });

    // Required with env var fallback
    try parser.addOption("secret", .{
        .help = "Secret key (required)",
        .env_var = "SERVER_SECRET",
        .required = true,
    });

    // Boolean with env var
    try parser.addFlag("debug", .{
        .short = 'd',
        .help = "Enable debug mode",
        .env_var = "SERVER_DEBUG",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const host = result.getString("host").?;
    const port = result.getInt("port").?;
    const secret = result.getString("secret").?;
    const debug = result.getBool("debug") orelse false;

    std.debug.print("Starting server:\n", .{});
    std.debug.print("  Host:   {s}\n", .{host});
    std.debug.print("  Port:   {d}\n", .{port});
    std.debug.print("  Secret: {s}...\n", .{secret[0..@min(4, secret.len)]});
    std.debug.print("  Debug:  {}\n", .{debug});
}
```

Run:

```bash
export SERVER_SECRET="my-super-secret-key"
export SERVER_PORT=3000
./server --host 127.0.0.1
```

## File-Based Configuration Pattern

Combine env vars with file-based defaults for layered configuration:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "app",
        .config = .{ .env_prefix = "APP" },
    });
    defer parser.deinit();

    // Config file path can come from env or CLI
    try parser.addOption("config", .{
        .short = 'c',
        .help = "Config file path",
        .env_var = "APP_CONFIG",
        .default = "config.json",
    });

    // All other options have env var fallbacks
    try parser.addOption("database-url", .{
        .help = "Database URL",
        .env_var = "APP_DATABASE_URL",
        .default = "postgres://localhost:5432/mydb",
    });

    try parser.addIntOption("workers", .{
        .help = "Worker threads",
        .env_var = "APP_WORKERS",
        .default = "4",
        .validator = validation.Validators.intRange(1, 64),
    });

    try parser.addFlag("tls", .{
        .help = "Enable TLS",
        .env_var = "APP_TLS",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    // Priority: CLI > env > config file > defaults
    // 1. Parse CLI args + env vars (done above)
    // 2. Optionally load config file for unset values
    // 3. Apply remaining defaults

    const config_file = result.getString("config") orelse "config.json";
    std.debug.print("Config: {s}\n", .{config_file});
    std.debug.print("DB URL: {s}\n", .{result.getString("database-url").?});
    std.debug.print("Workers: {d}\n", .{result.getInt("workers").?});
    std.debug.print("TLS: {}\n", .{result.getBool("tls") orelse false});
}
```

## Environment Variables for Typed Options

All typed option helpers support `env_var`:

```zig
// Integer with range validation
try parser.addIntOption("timeout", .{
    .env_var = "TIMEOUT",
    .default = "30",
    .validator = validation.Validators.intRange(1, 3600),
});

// Float with range
try parser.addFloatOption("threshold", .{
    .env_var = "THRESHOLD",
    .default = "0.5",
    .validator = validation.Validators.floatRange(0.0, 1.0),
});

// Unsigned integer
try parser.addUintOption("cache-size", .{
    .env_var = "CACHE_SIZE",
    .default = "1024",
});

// Duration
try parser.addDurationOption("timeout", .{
    .env_var = "TIMEOUT",
    .default = "30s",
});

// Size
try parser.addSizeOption("max-memory", .{
    .env_var = "MAX_MEMORY",
    .default = "2GB",
});

// Email
try parser.addEmailOption("admin-email", .{
    .env_var = "ADMIN_EMAIL",
    .required = true,
});

// URL
try parser.addUrlOption("api-base", .{
    .env_var = "API_BASE_URL",
    .default = "https://api.example.com",
});

// IP address
try parser.addIpOption("bind-addr", .{
    .env_var = "BIND_ADDR",
    .default = "0.0.0.0",
});

// Hostname
try parser.addHostNameOption("hostname", .{
    .env_var = "HOSTNAME",
});

// Port
try parser.addPortOption("port", .{
    .env_var = "PORT",
    .default = "8080",
});

// UUID
try parser.addUuidOption("instance-id", .{
    .env_var = "INSTANCE_ID",
});

// Key-value
try parser.addKeyValueOption("env", .{
    .env_var = "APP_ENV",
    .default = "production",
});
```

## Security Considerations

> [!WARNING]
> Environment variables are visible to all processes on the system. Never store secrets in env vars on shared systems.

### Best Practices

1. **Validate env vars** — Always attach validators to env-sourced options
2. **Use prefixes** — Prevent naming collisions with `env_prefix`
3. **Document env vars** — Use `show_env_vars = true` (default) so users see them in `--help`
4. **Prefer CLI for secrets** — Use `addSecretOption` for passwords (hidden from help)
5. **Layer configuration** — CLI > env > config file > defaults
6. **Use short env var names** — Keep derivable names short: `APP_PORT` not `APP_SERVER_LISTEN_PORT`

### What's Protected

- Env var values go through the same **type parsing** as CLI args
- Env var values go through the same **validator functions** as CLI args
- Invalid env var values produce **clear error messages** identifying the env var name
- **No shell injection** — env var values are never passed to shells
