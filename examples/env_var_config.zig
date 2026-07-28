//! Demonstrates environment variable configuration patterns.
//! Shows env_var field on options, fromEnvOrDefault helper, and env_prefix config.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Use env_prefix for automatic env-var derivation.
    // With prefix "MYAPP", option --db-host will look for MYAPP_DB_HOST.
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "env-demo",
        .version = "1.0.0",
        .description = "Demonstrates environment variable configuration",
        .config = args.Config{
            .env_prefix = "MYAPP",
        },
    });
    defer parser.deinit();

    try parser.addOption("db-host", .{
        .short = 'h',
        .help = "Database host (default: env MYAPP_DB_HOST)",
        .default = "localhost",
        .env_var = "MYAPP_DB_HOST",
    });

    try parser.addIntOption("db-port", .{
        .short = 'p',
        .help = "Database port (default: env MYAPP_DB_PORT)",
        .default = "5432",
        .env_var = "MYAPP_DB_PORT",
    });

    try parser.addOption("db-name", .{
        .short = 'd',
        .help = "Database name (default: env MYAPP_DB_NAME)",
        .default = "mydb",
        .env_var = "MYAPP_DB_NAME",
    });

    // fromEnvOrDefault: explicit env var with a fallback default
    try parser.fromEnvOrDefault("api-key", "MYAPP_API_KEY", "no-key-set", .{
        .help = "API key (from MYAPP_API_KEY env var)",
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    std.debug.print("Database configuration:\n", .{});
    std.debug.print("  Host:     {s}\n", .{result.get("db-host").?.asString().?});
    std.debug.print("  Port:     {d}\n", .{result.get("db-port").?.asInt().?});
    std.debug.print("  Database: {s}\n", .{result.get("db-name").?.asString().?});
    std.debug.print("  API Key:  {s}\n", .{result.get("api-key").?.asString().?});
    std.debug.print("\nTip: Set MYAPP_DB_HOST, MYAPP_DB_PORT, MYAPP_DB_NAME, or MYAPP_API_KEY\n", .{});
    std.debug.print("     in your environment to override defaults.\n", .{});
}
