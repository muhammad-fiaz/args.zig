//! Demonstrates advanced parseInto usage with enums, u32, f64, optional types.
//! Enums are automatically derived as --flag choices from Zig enum variants.

const std = @import("std");
const args = @import("args");

const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

const OutputFormat = enum {
    json,
    yaml,
    csv,
    table,
};

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
