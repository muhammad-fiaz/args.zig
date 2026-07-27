//! Example demonstrating secret/hidden options for passwords and tokens.
//! The secret option is hidden from help text.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "secret-example",
        .description = "Demonstrates secret/hidden options",
    });
    defer parser.deinit();

    try parser.addOption("user", .{
        .short = 'u',
        .help = "Username for authentication",
        .required = true,
    });

    // Secret option: hidden from help, stores password
    try parser.addSecretOption("password", .{
        .short = 'p',
        .help = "Password for authentication (hidden from help)",
        .required = true,
    });

    // Secret option with env var fallback
    try parser.addSecretOption("api-key", .{
        .help = "API key (from env or argument)",
        .env_var = "MY_API_KEY",
    });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const user = result.getString("user") orelse "unknown";
    const password = result.getString("password") orelse "";
    const api_key = result.getString("api-key") orelse "not set";

    // In real code, never print passwords!
    std.debug.print("Authentication:\n", .{});
    std.debug.print("  User:     {s}\n", .{user});
    std.debug.print("  Password: {s}...\n", .{password[0..@min(3, password.len)]});
    std.debug.print("  API Key:  {s}\n", .{api_key});
    std.debug.print("\nNote: The --password and --api-key flags are hidden from --help output.\n", .{});
}
