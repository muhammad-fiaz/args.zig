//! Configuration management for args.zig.

const std = @import("std");
const types = @import("types.zig");

/// Global configuration for the argument parser.
pub const Config = struct {
    check_for_updates: bool = true,
    show_update_notification: bool = true,
    use_colors: bool = true,
    help_line_width: usize = 80,
    help_indent: usize = 24,
    show_defaults: bool = true,
    show_env_vars: bool = true,
    program_name: ?[]const u8 = null,
    exit_on_error: bool = true,
    parsing_mode: types.ParsingMode = .strict,
    allow_short_clusters: bool = true,
    allow_inline_values: bool = true,
    allow_interspersed: bool = true,
    case_sensitive: bool = true,
    env_prefix: ?[]const u8 = null,

    pub fn default() Config {
        return .{};
    }

    pub fn minimal() Config {
        return .{
            .check_for_updates = false,
            .show_update_notification = false,
            .use_colors = false,
            .show_defaults = false,
            .show_env_vars = false,
            .exit_on_error = false,
        };
    }

    pub fn verbose() Config {
        return .{
            .show_defaults = true,
            .show_env_vars = true,
            .use_colors = true,
        };
    }
};

var global_config: Config = .{};
var config_mutex = std.Thread.Mutex{};
var config_initialized = false;

pub fn initConfig(cfg: Config) void {
    config_mutex.lock();
    defer config_mutex.unlock();
    global_config = cfg;
    config_initialized = true;
}

pub fn getConfig() Config {
    config_mutex.lock();
    defer config_mutex.unlock();
    return global_config;
}

pub fn resetConfig() void {
    config_mutex.lock();
    defer config_mutex.unlock();
    global_config = .{};
    config_initialized = false;
}

pub fn setConfigValue(comptime field: []const u8, value: anytype) void {
    config_mutex.lock();
    defer config_mutex.unlock();
    @field(global_config, field) = value;
}

pub fn isInitialized() bool {
    config_mutex.lock();
    defer config_mutex.unlock();
    return config_initialized;
}

test "Config.default" {
    const cfg = Config.default();
    try std.testing.expect(cfg.check_for_updates);
    try std.testing.expect(cfg.use_colors);
    try std.testing.expect(cfg.exit_on_error);
}

test "Config.minimal" {
    const cfg = Config.minimal();
    try std.testing.expect(!cfg.check_for_updates);
    try std.testing.expect(!cfg.use_colors);
    try std.testing.expect(!cfg.exit_on_error);
}

test "initConfig and getConfig" {
    initConfig(.{ .use_colors = false, .check_for_updates = false });
    defer resetConfig();

    const cfg = getConfig();
    try std.testing.expect(!cfg.use_colors);
    try std.testing.expect(!cfg.check_for_updates);
}

test "setConfigValue" {
    resetConfig();
    defer resetConfig();

    setConfigValue("use_colors", false);
    const cfg = getConfig();
    try std.testing.expect(!cfg.use_colors);
}
