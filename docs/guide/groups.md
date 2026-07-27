# Argument Groups

Argument groups let you organize related arguments into labeled sections in help output, and enforce constraints like mutual exclusion or conditional requirements across arguments.

Without groups, all arguments appear in a flat list. Groups make help text more readable for complex CLIs and let you enforce relationships between arguments at parse time.

## Basic Groups

Use `addArgumentGroup` to create a named group. All arguments added afterward belong to that group until `setGroup(null)` is called or another group is created.

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .description = "Application with grouped arguments",
    });
    defer parser.deinit();

    // Create a group — all subsequent arguments go into it
    try parser.addArgumentGroup("Network Options", .{
        .description = "Configuration for network connectivity",
    });

    try parser.addOption("host", .{
        .help = "Hostname or IP address",
        .default = "localhost",
    });
    try parser.addOption("port", .{
        .short = 'p',
        .value_type = .int,
        .help = "Port number",
    });

    // Leave the group
    parser.setGroup(null);

    // These arguments are ungrouped
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();
}
```

The help output groups those arguments under a labeled section:

```text
Usage: myapp [OPTIONS]

  Network Options:
    Configuration for network connectivity

      --host <string>    Hostname or IP address [default: localhost]
    -p, --port <int>     Port number

  Options:
    -v, --verbose        Enable verbose output
    -h, --help           Show this help message
```

> [!TIP]
> Call `setGroup(null)` after adding a group's arguments to return to the default (ungrouped) section. Arguments added before any group or after `setGroup(null)` appear in the main options list.

## Group Styling

Groups appear as labeled sections in help text. Each group gets:

- A **bold heading** with the group name
- An optional **description** below the heading (if provided)
- Indented arguments belonging to that group

```zig
try parser.addArgumentGroup("Output Settings", .{
    .description = "Control how results are displayed",
});
try parser.addOption("format", .{
    .help = "Output format",
    .choices = &[_][]const u8{ "json", "text", "csv" },
    .default = "text",
});
try parser.addFlag("color", .{
    .help = "Enable colored output",
    .default = "true",
});
parser.setGroup(null);
```

Help output:

```text
Output Settings:
  Control how results are displayed

    --format <string>   Output format [default: text]
    --color             Enable colored output [default: true]
```

## Mutually Exclusive Groups

Set `exclusive: true` on a group to enforce that **at most one** argument from that group can be provided. If the user passes two or more arguments from an exclusive group, parsing fails with an error.

```zig
try parser.addArgumentGroup("Operation Mode", .{
    .exclusive = true,
});

try parser.addFlag("server", .{ .help = "Run in server mode" });
try parser.addFlag("client", .{ .help = "Run in client mode" });
try parser.addFlag("daemon", .{ .help = "Run as background daemon" });
```

```text
Operation Mode:

    --server    Run in server mode
    --client    Run in client mode
    --daemon    Run as background daemon
```

If the user runs `myapp --server --client`, parsing fails:

```text
error: Arguments in group 'Operation Mode' are mutually exclusive
```

> [!NOTE]
> An exclusive group allows **zero or one** of its arguments. To require exactly one, also set `required: true` (see next section).

## Required Groups

Set `required: true` to enforce that **at least one** argument from the group must be provided. This is commonly combined with `exclusive` to require exactly one mode.

```zig
try parser.addArgumentGroup("Mode", .{
    .exclusive = true,
    .required = true, // User MUST provide one of these
});

try parser.addFlag("compress", .{ .help = "Compress input" });
try parser.addFlag("extract", .{ .help = "Extract archive" });
```

```text
Mode:

    --compress    Compress input
    --extract     Extract archive
```

If the user runs `myapp` with neither `--compress` nor `--extract`, parsing fails:

```text
error: missing required argument
```

> [!WARNING]
> A required group must have at least one argument provided. If no argument from the group is present on the command line, the parser returns `error.MissingRequired`.

## Multiple Groups

You can create multiple groups and switch between them with `setGroup`. Arguments are added to whichever group is currently active.

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "deploy",
        .description = "Deployment tool",
    });
    defer parser.deinit();

    // Group 1: connection
    try parser.addArgumentGroup("Connection", .{
        .description = "Remote server settings",
    });
    try parser.addOption("host", .{ .help = "Server hostname" });
    try parser.addOption("port", .{ .short = 'p', .value_type = .int, .help = "SSH port" });

    // Group 2: deployment options
    try parser.addArgumentGroup("Deployment", .{
        .description = "What to deploy and how",
    });
    try parser.addOption("env", .{
        .help = "Target environment",
        .choices = &[_][]const u8{ "staging", "production" },
    });
    try parser.addFlag("dry-run", .{ .help = "Simulate without deploying" });

    // Group 3: mutually exclusive output
    try parser.addArgumentGroup("Output", .{
        .exclusive = true,
    });
    try parser.addFlag("quiet", .{ .short = 'q', .help = "Suppress output" });
    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });

    parser.setGroup(null);

    // Ungrouped arguments
    try parser.addFlag("force", .{ .help = "Skip confirmation" });

    var result = try parser.parseProcess(init);
    defer result.deinit();
}
```

> [!TIP]
> You can switch back to a previously created group by calling `setGroup` with the group's name:
> ```zig
> parser.setGroup("Connection");
> try parser.addOption("timeout", .{ .help = "Connection timeout" });
> ```

## Group with Arguments

Here is a complete example showing groups with various argument types — flags, options, counters, and positionals:

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "dbtool",
        .description = "Database management utility",
    });
    defer parser.deinit();

    // Global flags (ungrouped)
    try parser.addFlag("help", .{ .short = 'h', .help = "Show help" });

    // Database group
    try parser.addArgumentGroup("Database Connection", .{
        .description = "Configure the database connection",
    });
    try parser.addOption("host", .{
        .help = "Database host",
        .default = "localhost",
    });
    try parser.addOption("port", .{
        .short = 'p',
        .value_type = .int,
        .help = "Database port",
        .default = "5432",
    });
    try parser.addOption("user", .{
        .short = 'u',
        .help = "Database user",
    });
    try parser.addOption("password", .{
        .short = 'P',
        .help = "Database password",
    });
    try parser.addOption("dbname", .{
        .help = "Database name",
        .required = true,
    });

    // Query options group
    try parser.addArgumentGroup("Query Options", .{
        .description = "Control query execution",
    });
    try parser.addOption("timeout", .{
        .value_type = .int,
        .help = "Query timeout in seconds",
        .default = "30",
    });
    try parser.addFlag("explain", .{
        .help = "Show query execution plan",
    });
    try parser.addCounter("verbose", .{
        .short = 'v',
        .help = "Increase verbosity (repeat for more)",
    });

    parser.setGroup(null);

    // Positional
    try parser.addPositional("sql", .{
        .help = "SQL statement or file path",
        .required = true,
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const host = result.getString("host") orelse "localhost";
    const port = result.getInt("port") orelse 5432;
    const user = result.getString("user") orelse "root";
    const dbname = result.getString("dbname") orelse unreachable;
    const timeout = result.getInt("timeout") orelse 30;
    const explain = result.getBool("explain") orelse false;
    const verbosity: u32 = if (result.get("verbose")) |v| v.counter else 0;
    const sql = result.getString("sql") orelse unreachable;

    std.debug.print("Connecting to {s}:{d} as {s} (db: {s})\n", .{ host, port, user, dbname });
    std.debug.print("Timeout: {d}s | Explain: {} | Verbosity: {d}\n", .{ timeout, explain, verbosity });
    std.debug.print("SQL: {s}\n", .{sql});
}
```

## Mutual Exclusion via API

For ad-hoc mutual exclusion outside of groups, use `addMutualExclusion`. This takes an array of argument names where **at most one** may be provided.

```zig
try parser.addFlag("mysql", .{ .help = "Use MySQL backend" });
try parser.addFlag("postgres", .{ .help = "Use PostgreSQL backend" });
try parser.addFlag("sqlite", .{ .help = "Use SQLite backend" });

// At most one database backend may be specified
try parser.addMutualExclusion(&[_][]const u8{ "mysql", "postgres", "sqlite" });
```

> [!NOTE]
> `addMutualExclusion` works independently of groups. Arguments can be in different groups (or ungrouped) and still be mutually exclusive. This is useful when the arguments don't logically belong in the same visual group.

If the user runs `myapp --mysql --postgres`, parsing fails:

```text
error: mutually exclusive arguments used together
```

## Conditional Requirements

Use `addRequiredIf` to make an argument required when another argument (or argument with a specific value) is present.

### Basic conditional requirement

```zig
try parser.addOption("host", .{ .help = "Database host" });
try parser.addOption("user", .{ .help = "Database user" });

// host and user are required if --mysql or --postgres is used
try parser.addFlag("mysql", .{ .help = "Use MySQL backend" });
try parser.addFlag("postgres", .{ .help = "Use PostgreSQL backend" });

try parser.addRequiredIf("host", "mysql", null);
try parser.addRequiredIf("host", "postgres", null);
try parser.addRequiredIf("user", "mysql", null);
try parser.addRequiredIf("user", "postgres", null);
```

Running `myapp --mysql` without `--host` fails:

```text
error: argument is required when another is present
```

### Conditional on a specific value

You can require an argument only when the trigger argument has a specific value:

```zig
try parser.addOption("port", .{
    .help = "Database port",
    .value_type = .int,
});

// --port 3306 is required if --mysql is used
try parser.addRequiredIf("port", "mysql", "3306");
```

> [!TIP]
> Pass `null` as the third argument to `addRequiredIf` to trigger on the mere **presence** of the other argument, regardless of its value. Pass a specific string to trigger only when that value is provided.

## Dependencies

### `addRequires` — Argument A requires argument B

Use `addRequires` to declare that one argument depends on another. If argument A is provided, argument B must also be provided.

```zig
try parser.addOption("user", .{ .help = "Database username" });
try parser.addOption("password", .{ .help = "Database password" });

// If --password is provided, --user must also be provided
try parser.addRequires("password", "user");
```

Running `myapp --password secret` without `--user` fails:

```text
error: missing required dependency
```

### `addConflict` — Argument A conflicts with argument B

Use `addConflict` to declare that two arguments cannot be used together. This is a pairwise constraint (unlike `addMutualExclusion` which works across N arguments).

```zig
try parser.addFlag("verbose", .{ .help = "Verbose output" });
try parser.addFlag("quiet", .{ .help = "Suppress all output" });

// These two cannot be used together
try parser.addConflict("verbose", "quiet");
```

> [!NOTE]
> `addConflict` is bidirectional — if A conflicts with B, then B also conflicts with A. You only need to call it once.

> [!TIP]
> For three or more mutually exclusive arguments, use `addMutualExclusion` instead of calling `addConflict` on every pair.

## Complete Example

This example combines all group features: multiple groups, exclusive groups, required groups, mutual exclusion, conditional requirements, and dependencies.

```zig
const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "dbmigrate",
        .description = "Database migration and backup tool",
    });
    defer parser.deinit();

    // --- Group 1: Database Connection ---
    try parser.addArgumentGroup("Database Connection", .{
        .description = "Configure the target database",
    });
    try parser.addOption("host", .{ .help = "Database host address" });
    try parser.addOption("port", .{
        .short = 'p',
        .value_type = .int,
        .help = "Database port",
    });
    try parser.addOption("user", .{
        .short = 'u',
        .help = "Database username",
    });
    try parser.addOption("password", .{
        .short = 'P',
        .help = "Database password",
    });
    try parser.addOption("dbname", .{
        .help = "Database name",
        .required = true,
    });

    // --- Group 2: Mutually Exclusive Operation ---
    try parser.addArgumentGroup("Operation", .{
        .description = "Choose one operation to perform",
        .exclusive = true,
        .required = true,
    });
    try parser.addFlag("migrate", .{ .help = "Run pending migrations" });
    try parser.addFlag("rollback", .{ .help = "Rollback last migration" });
    try parser.addFlag("backup", .{ .help = "Create a database backup" });
    try parser.addFlag("restore", .{ .help = "Restore from backup" });

    // --- Group 3: Output Preferences ---
    try parser.addArgumentGroup("Output", .{
        .exclusive = true,
    });
    try parser.addFlag("quiet", .{ .short = 'q', .help = "Suppress all output" });
    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });

    parser.setGroup(null);

    // --- Standalone flags ---
    try parser.addFlag("dry-run", .{ .help = "Simulate without making changes" });
    try parser.addFlag("force", .{ .help = "Skip confirmation prompts" });

    // --- Positional ---
    try parser.addPositional("path", .{
        .help = "Path to migration files or backup archive",
    });

    // --- API-level constraints ---

    // --password requires --user to also be provided
    try parser.addRequires("password", "user");

    // host and user are required when using --migrate or --rollback
    try parser.addRequiredIf("host", "migrate", null);
    try parser.addRequiredIf("host", "rollback", null);
    try parser.addRequiredIf("user", "migrate", null);
    try parser.addRequiredIf("user", "rollback", null);

    // --restore conflicts with --dry-run (can't simulate a restore)
    try parser.addConflict("restore", "dry-run");

    // Parse
    var result = try parser.parseProcess(init);
    defer result.deinit();

    const quiet = result.getBool("quiet") orelse false;
    const verbose = result.getBool("verbose") orelse false;
    const dry_run = result.getBool("dry-run") orelse false;
    const force = result.getBool("force") orelse false;
    const path = result.getString("path") orelse unreachable;

    if (quiet) return;

    std.debug.print("=== dbmigrate ===\n", .{});
    std.debug.print("Path:     {s}\n", .{path});
    std.debug.print("Dry-run:  {} | Force: {}\n", .{ dry_run, force });

    if (result.contains("migrate")) {
        std.debug.print("Operation: MIGRATE\n", .{});
        const host = result.getString("host") orelse unreachable;
        const port = result.getInt("port") orelse 5432;
        const user = result.getString("user") orelse unreachable;
        const dbname = result.getString("dbname") orelse unreachable;
        std.debug.print("Target:    {s}:{d} (db: {s}, user: {s})\n", .{ host, port, dbname, user });
    } else if (result.contains("rollback")) {
        std.debug.print("Operation: ROLLBACK\n", .{});
    } else if (result.contains("backup")) {
        std.debug.print("Operation: BACKUP\n", .{});
    } else if (result.contains("restore")) {
        std.debug.print("Operation: RESTORE\n", .{});
    }

    if (verbose) {
        std.debug.print("[VERBOSE] Detailed logging enabled\n", .{});
    }
}
```

### Running the example

```bash
# Show help with grouped output
zig build run -- --help

# Run a migration
zig build run -- migrate --host db.example.com --port 5432 --user admin --password secret --dbname myapp ./migrations

# Create a backup (no connection args needed)
zig build run -- backup --dbname myapp ./backups

# This fails — --restore conflicts with --dry-run
zig build run -- restore --dry-run ./backup.sql

# This fails — --host is required for migrate
zig build run -- migrate --dbname myapp ./migrations
```

## Quick Reference

| Method | Purpose |
|---|---|
| `addArgumentGroup(name, opts)` | Create a named group and set it active |
| `setGroup(name_or_null)` | Switch active group or exit grouping |
| `addMutualExclusion(&names)` | At most one of the listed arguments may be used |
| `addRequires(arg, required)` | If `arg` is used, `required` must also be used |
| `addConflict(arg, conflict)` | `arg` and `conflict` cannot be used together |
| `addRequiredIf(arg, trigger, value)` | `arg` is required when `trigger` is present (optionally with `value`) |

| Group Option | Effect |
|---|---|
| `exclusive: true` | At most one argument in the group can be used |
| `required: true` | At least one argument in the group must be used |
| `exclusive + required` | Exactly one argument in the group must be used |
