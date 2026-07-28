//! Example demonstrating addEnvOption with automatic environment variable name derivation.
//! Option names are auto-converted: hyphens -> underscores, uppercased.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "env-option-example",
        .description = "Demonstrates automatic env var derivation",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    // addEnvOption auto-derives env var name:
    // "db-host" -> DB_HOST, "db-port" -> DB_PORT, etc.
    try parser.addEnvOption("db-host", .{
        .short = 'h',
        .help = "Database host (env: DB_HOST)",
        .default = "localhost",
    });

    try parser.addEnvOption("db-port", .{
        .short = 'p',
        .help = "Database port (env: DB_PORT)",
        .value_type = .int,
        .default = "5432",
    });

    // Override the derived name with explicit env_var
    try parser.addEnvOption("api-key", .{
        .help = "API key (env: MYAPP_API_KEY)",
        .env_var = "MYAPP_API_KEY",
        .default = "not-set",
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    std.debug.print("Environment-derived configuration:\n", .{});
    std.debug.print("  DB Host:  {s}\n", .{result.get("db-host").?.asString().?});
    std.debug.print("  DB Port:  {d}\n", .{result.get("db-port").?.asInt().?});
    std.debug.print("  API Key:  {s}\n", .{result.get("api-key").?.asString().?});
    std.debug.print("\nTip: Set DB_HOST, DB_PORT, or MYAPP_API_KEY env vars.\n", .{});
    std.debug.print("     Option names auto-convert: hyphens->underscores, uppercased.\n", .{});
}
