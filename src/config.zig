//! Configuration management for args.zig.
//! All warning/conflict messages reuse strings from constants.zig.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

/// Severity of a configuration warning.
pub const ConfigWarningSeverity = enum {
    note,
    warning,
    @"error",
};

/// A single detected configuration issue.
pub const ConfigWarning = struct {
    field: []const u8,
    message: []const u8,
    severity: ConfigWarningSeverity = .warning,
    auto_resolved: bool = false,
};

/// Global configuration for the argument parser.
pub const Config = struct {
    check_for_updates: bool = true,
    show_update_notification: bool = true,
    use_colors: bool = true,
    colors: ?utils.ColorTheme = null,
    help_line_width: usize = 80,
    help_indent: usize = 24,
    show_defaults: bool = true,
    show_env_vars: bool = true,
    program_name: ?[]const u8 = null,
    exit_on_error: bool = true,
    parsing_mode: types.ParsingMode = .strict,
    allow_short_clusters: bool = true,
    allow_inline_values: bool = true,
    allow_brackets: bool = true,
    allow_interspersed: bool = true,
    allow_negated_flags: bool = true,
    case_sensitive: bool = true,
    env_prefix: ?[]const u8 = null,
    silent_errors: bool = false,
    suggest_closest: bool = true,
    suggestion_max_distance: usize = 3,
    suggest_builtin_commands: bool = true,
    suggest_subcommands: bool = true,
    error_prefix: []const u8 = constants.Defaults.error_prefix,
    warning_prefix: []const u8 = constants.Defaults.warning_prefix,
    unknown_option_hint: ?[]const u8 = null,
    unknown_subcommand_hint: ?[]const u8 = null,
    unknown_option_message: ?[]const u8 = null,
    unknown_subcommand_message: ?[]const u8 = null,

    // Global Application Metadata (used if not explicitly provided in init)
    app_name: ?[]const u8 = null,
    app_version: ?[]const u8 = null,
    app_description: ?[]const u8 = null,
    app_epilog: ?[]const u8 = null,
    app_author: ?[]const u8 = null,

    // ──────────────────────────────────────────────────────────────
    // Preset constructors
    // ──────────────────────────────────────────────────────────────

    /// Default config — all features enabled, strict mode.
    pub fn default() Config {
        return .{};
    }

    /// Minimal config — no colors, no updates, no exit on error, silent.
    pub fn minimal() Config {
        return .{
            .check_for_updates = false,
            .show_update_notification = false,
            .use_colors = false,
            .show_defaults = false,
            .show_env_vars = false,
            .exit_on_error = false,
            .silent_errors = true,
        };
    }

    /// Verbose config — colors + show defaults/env.
    pub fn verbose() Config {
        return .{
            .show_defaults = true,
            .show_env_vars = true,
            .use_colors = true,
        };
    }

    /// Colorful config — bright color theme.
    pub fn colorful() Config {
        return .{
            .use_colors = true,
            .colors = utils.ColorTheme.bright(),
        };
    }

    /// Testing config — silent, no exit, no updates. Ideal for unit tests.
    pub fn testing() Config {
        return .{
            .exit_on_error = false,
            .silent_errors = true,
            .check_for_updates = false,
            .show_update_notification = false,
            .use_colors = false,
            .parsing_mode = .strict,
        };
    }

    /// CI config — strict, no colors (pipe-safe), no update checks.
    pub fn ci() Config {
        return .{
            .exit_on_error = true,
            .use_colors = false,
            .check_for_updates = false,
            .show_update_notification = false,
            .parsing_mode = .strict,
            .suggest_closest = true,
            .silent_errors = false,
        };
    }

    /// Production config — exit on error, colors, updates, strict.
    pub fn production() Config {
        return .{
            .exit_on_error = true,
            .use_colors = true,
            .check_for_updates = true,
            .show_update_notification = true,
            .parsing_mode = .strict,
            .suggest_closest = true,
        };
    }

    // ──────────────────────────────────────────────────────────────
    // Validation — detect inconsistent config combinations
    // ──────────────────────────────────────────────────────────────

    /// Validates the config and returns a list of detected issues.
    /// The caller owns the returned slice; free each item's `message` if needed.
    /// All message strings are from constants.ConfigWarnings.
    pub fn validate(self: Config, buf: []ConfigWarning) usize {
        var count: usize = 0;

        // 1. permissive mode + exit_on_error
        if (self.parsing_mode == .permissive and self.exit_on_error) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "exit_on_error",
                    .message = constants.ConfigWarnings.permissive_exit_on_error,
                    .severity = .warning,
                };
                count += 1;
            }
        }

        // 2. ignore_unknown + exit_on_error
        if (self.parsing_mode == .ignore_unknown and self.exit_on_error) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "exit_on_error",
                    .message = constants.ConfigWarnings.ignore_unknown_exit_on_error,
                    .severity = .warning,
                };
                count += 1;
            }
        }

        // 3. use_colors + silent_errors
        if (self.use_colors and self.silent_errors) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "use_colors",
                    .message = constants.ConfigWarnings.colors_silent_errors,
                    .severity = .note,
                };
                count += 1;
            }
        }

        // 4. suggest_closest + suggestion_max_distance = 0
        if (self.suggest_closest and self.suggestion_max_distance == 0) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "suggestion_max_distance",
                    .message = constants.ConfigWarnings.suggest_zero_distance,
                    .severity = .warning,
                };
                count += 1;
            }
        }

        // 5. allow_negated_flags = false + strict mode
        if (!self.allow_negated_flags and self.parsing_mode == .strict) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "allow_negated_flags",
                    .message = constants.ConfigWarnings.negated_flags_strict,
                    .severity = .note,
                };
                count += 1;
            }
        }

        // 6. check_for_updates + silent_errors
        if (self.check_for_updates and self.silent_errors) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "check_for_updates",
                    .message = constants.ConfigWarnings.update_check_silent,
                    .severity = .note,
                };
                count += 1;
            }
        }

        // 7. no suggestion candidates at all
        if (self.suggest_closest and !self.suggest_builtin_commands and !self.suggest_subcommands) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "suggest_builtin_commands",
                    .message = constants.ConfigWarnings.no_suggestion_candidates,
                    .severity = .note,
                };
                count += 1;
            }
        }

        // 8. help_indent >= help_line_width
        if (self.help_indent >= self.help_line_width) {
            if (count < buf.len) {
                buf[count] = .{
                    .field = "help_indent",
                    .message = constants.ConfigWarnings.indent_exceeds_width,
                    .severity = .warning,
                };
                count += 1;
            }
        }

        return count;
    }

    /// Auto-resolves conflicts in a config and returns the clean copy.
    /// Conflicts are fixed by choosing the safer/more consistent value.
    pub fn autoResolve(self: Config) Config {
        var cfg = self;

        // Fix: permissive + exit_on_error → disable exit_on_error
        if (cfg.parsing_mode == .permissive and cfg.exit_on_error) {
            cfg.exit_on_error = false;
        }

        // Fix: ignore_unknown + exit_on_error → disable exit_on_error
        if (cfg.parsing_mode == .ignore_unknown and cfg.exit_on_error) {
            cfg.exit_on_error = false;
        }

        // Fix: suggest_closest + distance=0 → set distance to default
        if (cfg.suggest_closest and cfg.suggestion_max_distance == 0) {
            cfg.suggestion_max_distance = 3;
        }

        // Fix: use_colors + silent_errors → disable colors (useless with silent)
        if (cfg.use_colors and cfg.silent_errors) {
            cfg.use_colors = false;
        }

        // Fix: check_for_updates + silent_errors → disable updates
        if (cfg.check_for_updates and cfg.silent_errors) {
            cfg.check_for_updates = false;
            cfg.show_update_notification = false;
        }

        // Fix: help_indent >= help_line_width → clamp indent
        if (cfg.help_indent >= cfg.help_line_width) {
            cfg.help_indent = cfg.help_line_width / 3;
        }

        return cfg;
    }

    /// Merges `other` into `self`.
    /// Fields in `other` that differ from their zero-value override `self`.
    /// This is a shallow merge — optional fields in `other` win if non-null.
    pub fn merge(self: Config, other: Config) Config {
        var result = self;
        const defaults = Config{};

        // Override fields that differ from their default in `other`
        if (other.check_for_updates != defaults.check_for_updates) result.check_for_updates = other.check_for_updates;
        if (other.show_update_notification != defaults.show_update_notification) result.show_update_notification = other.show_update_notification;
        if (other.use_colors != defaults.use_colors) result.use_colors = other.use_colors;
        if (other.colors != null) result.colors = other.colors;
        if (other.help_line_width != defaults.help_line_width) result.help_line_width = other.help_line_width;
        if (other.help_indent != defaults.help_indent) result.help_indent = other.help_indent;
        if (other.show_defaults != defaults.show_defaults) result.show_defaults = other.show_defaults;
        if (other.show_env_vars != defaults.show_env_vars) result.show_env_vars = other.show_env_vars;
        if (other.program_name != null) result.program_name = other.program_name;
        if (other.exit_on_error != defaults.exit_on_error) result.exit_on_error = other.exit_on_error;
        if (other.parsing_mode != defaults.parsing_mode) result.parsing_mode = other.parsing_mode;
        if (other.allow_short_clusters != defaults.allow_short_clusters) result.allow_short_clusters = other.allow_short_clusters;
        if (other.allow_inline_values != defaults.allow_inline_values) result.allow_inline_values = other.allow_inline_values;
        if (other.allow_interspersed != defaults.allow_interspersed) result.allow_interspersed = other.allow_interspersed;
        if (other.allow_negated_flags != defaults.allow_negated_flags) result.allow_negated_flags = other.allow_negated_flags;
        if (other.case_sensitive != defaults.case_sensitive) result.case_sensitive = other.case_sensitive;
        if (other.env_prefix != null) result.env_prefix = other.env_prefix;
        if (other.silent_errors != defaults.silent_errors) result.silent_errors = other.silent_errors;
        if (other.suggest_closest != defaults.suggest_closest) result.suggest_closest = other.suggest_closest;
        if (other.suggestion_max_distance != defaults.suggestion_max_distance) result.suggestion_max_distance = other.suggestion_max_distance;
        if (other.suggest_builtin_commands != defaults.suggest_builtin_commands) result.suggest_builtin_commands = other.suggest_builtin_commands;
        if (other.suggest_subcommands != defaults.suggest_subcommands) result.suggest_subcommands = other.suggest_subcommands;
        if (other.unknown_option_hint != null) result.unknown_option_hint = other.unknown_option_hint;
        if (other.unknown_subcommand_hint != null) result.unknown_subcommand_hint = other.unknown_subcommand_hint;
        if (other.unknown_option_message != null) result.unknown_option_message = other.unknown_option_message;
        if (other.unknown_subcommand_message != null) result.unknown_subcommand_message = other.unknown_subcommand_message;
        if (other.app_name != null) result.app_name = other.app_name;
        if (other.app_version != null) result.app_version = other.app_version;
        if (other.app_description != null) result.app_description = other.app_description;
        if (other.app_epilog != null) result.app_epilog = other.app_epilog;
        if (other.app_author != null) result.app_author = other.app_author;

        return result;
    }

    /// Returns an identical copy of this config (snapshot).
    pub fn snapshot(self: Config) Config {
        return self;
    }
};

const config_io: std.Io = if (builtin.is_test) std.testing.io else std.Io.failing;

var global_config: Config = .{};
var config_mutex = std.Io.Mutex.init;
var config_initialized = false;

/// Set the global config directly.
pub fn initConfig(cfg: Config) void {
    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    global_config = cfg;
    config_initialized = true;
}

/// Set the global config, automatically resolving any detected conflicts.
/// Prints warnings to stderr before applying (unless silent_errors is set).
pub fn initConfigAutoResolve(cfg: Config) void {
    var warn_buf: [16]ConfigWarning = undefined;
    const n = cfg.validate(&warn_buf);

    const resolved = cfg.autoResolve();

    // Print warnings before applying (respects silent_errors on the *original* cfg)
    if (!cfg.silent_errors) {
        const theme = utils.resolveTheme(cfg.use_colors, cfg.colors);
        for (warn_buf[0..n]) |w| {
            const prefix = switch (w.severity) {
                .note => constants.Defaults.note_prefix,
                .warning => constants.Defaults.warning_prefix,
                .@"error" => constants.Defaults.error_prefix,
            };
            const color = switch (w.severity) {
                .note => theme.info,
                .warning => theme.warning,
                .@"error" => theme.error_color,
            };
            if (cfg.use_colors) {
                std.debug.print("{s}{s}{s}: {s}\n", .{ color, prefix, theme.reset, w.message });
            } else {
                std.debug.print("{s}: {s}\n", .{ prefix, w.message });
            }
        }
    }

    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    global_config = resolved;
    config_initialized = true;
}

/// Get the current global config.
pub fn getConfig() Config {
    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    return global_config;
}

/// Reset the global config to defaults.
pub fn resetConfig() void {
    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    global_config = .{};
    config_initialized = false;
}

/// Set a single config field by name.
pub fn setConfigValue(comptime field: []const u8, value: anytype) void {
    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    @field(global_config, field) = value;
}

/// Check whether the global config has been explicitly initialized.
pub fn isInitialized() bool {
    config_mutex.lockUncancelable(config_io);
    defer config_mutex.unlock(config_io);
    return config_initialized;
}

/// Validate the current global config and return the number of warnings found.
/// Fills `buf` with up to `buf.len` warnings.
pub fn validateConfig(buf: []ConfigWarning) usize {
    const cfg = getConfig();
    return cfg.validate(buf);
}

// ──────────────────────────────────────────────────────────────────────────────
// Tests
// ──────────────────────────────────────────────────────────────────────────────

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
    try std.testing.expect(cfg.silent_errors);
}

test "Config.colorful" {
    const cfg = Config.colorful();
    try std.testing.expect(cfg.use_colors);
    try std.testing.expect(cfg.colors != null);
}

test "Config.testing preset" {
    const cfg = Config.testing();
    try std.testing.expect(!cfg.exit_on_error);
    try std.testing.expect(cfg.silent_errors);
    try std.testing.expect(!cfg.check_for_updates);
    try std.testing.expect(!cfg.use_colors);
}

test "Config.ci preset" {
    const cfg = Config.ci();
    try std.testing.expect(cfg.exit_on_error);
    try std.testing.expect(!cfg.use_colors);
    try std.testing.expect(!cfg.check_for_updates);
}

test "Config.production preset" {
    const cfg = Config.production();
    try std.testing.expect(cfg.exit_on_error);
    try std.testing.expect(cfg.use_colors);
    try std.testing.expect(cfg.check_for_updates);
}

test "Config.validate detects permissive+exit_on_error" {
    const cfg = Config{
        .parsing_mode = .permissive,
        .exit_on_error = true,
    };
    var buf: [16]ConfigWarning = undefined;
    const n = cfg.validate(&buf);
    try std.testing.expect(n >= 1);
    try std.testing.expectEqualStrings("exit_on_error", buf[0].field);
}

test "Config.validate detects suggestion_max_distance=0" {
    const cfg = Config{
        .suggest_closest = true,
        .suggestion_max_distance = 0,
    };
    var buf: [16]ConfigWarning = undefined;
    const n = cfg.validate(&buf);
    try std.testing.expect(n >= 1);
    var found = false;
    for (buf[0..n]) |w| {
        if (std.mem.eql(u8, w.field, "suggestion_max_distance")) found = true;
    }
    try std.testing.expect(found);
}

test "Config.validate detects colors+silent" {
    const cfg = Config{
        .use_colors = true,
        .silent_errors = true,
    };
    var buf: [16]ConfigWarning = undefined;
    const n = cfg.validate(&buf);
    try std.testing.expect(n >= 1);
}

test "Config.validate detects indent >= width" {
    const cfg = Config{
        .help_indent = 80,
        .help_line_width = 80,
    };
    var buf: [16]ConfigWarning = undefined;
    const n = cfg.validate(&buf);
    try std.testing.expect(n >= 1);
}

test "Config.autoResolve fixes permissive+exit_on_error" {
    const cfg = Config{
        .parsing_mode = .permissive,
        .exit_on_error = true,
    };
    const resolved = cfg.autoResolve();
    try std.testing.expect(!resolved.exit_on_error);
}

test "Config.autoResolve fixes distance=0" {
    const cfg = Config{
        .suggest_closest = true,
        .suggestion_max_distance = 0,
    };
    const resolved = cfg.autoResolve();
    try std.testing.expect(resolved.suggestion_max_distance > 0);
}

test "Config.merge overrides fields" {
    const base = Config{ .use_colors = true, .exit_on_error = true };
    const patch = Config{ .use_colors = false };
    const merged = base.merge(patch);
    try std.testing.expect(!merged.use_colors);
    try std.testing.expect(merged.exit_on_error); // unchanged
}

test "Config.snapshot returns copy" {
    const cfg = Config{ .help_indent = 30 };
    const snap = cfg.snapshot();
    try std.testing.expectEqual(@as(usize, 30), snap.help_indent);
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

test "validateConfig helper" {
    initConfig(.{ .parsing_mode = .permissive, .exit_on_error = true });
    defer resetConfig();

    var buf: [16]ConfigWarning = undefined;
    const n = validateConfig(&buf);
    try std.testing.expect(n >= 1);
}
