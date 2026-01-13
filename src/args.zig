//! args.zig - Command-line argument parsing library for Zig.
//! Fast, powerful, and developer-friendly with Python argparse-inspired API.

const std = @import("std");
const builtin = @import("builtin");

pub const types = @import("types.zig");
pub const schema = @import("schema.zig");
pub const tokenizer = @import("tokenizer.zig");
pub const parser = @import("parser.zig");
pub const validation = @import("validation.zig");
pub const errors = @import("errors.zig");
pub const help = @import("help.zig");
pub const completion = @import("completion.zig");
pub const config = @import("config.zig");
pub const version_info = @import("version.zig");
pub const update_checker = @import("update_checker.zig");
pub const network = @import("network.zig");
pub const utils = @import("utils.zig");

// Re-export commonly used types
pub const ParseResult = types.ParseResult;
pub const ParsedValue = types.ParsedValue;
pub const ValueType = types.ValueType;
pub const ArgAction = types.ArgAction;
pub const Nargs = types.Nargs;
pub const ParsingMode = types.ParsingMode;
pub const ArgSpec = schema.ArgSpec;
pub const CommandSpec = schema.CommandSpec;
pub const SubcommandSpec = schema.SubcommandSpec;
pub const ArgumentGroup = schema.ArgumentGroup;
pub const SchemaBuilder = schema.SchemaBuilder;
pub const Config = config.Config;
pub const Shell = completion.Shell;
pub const ParseError = errors.ParseError;
pub const ValidationError = errors.ValidationError;
pub const SchemaError = errors.SchemaError;

// Version information
pub const VERSION = version_info.version;
pub const VERSION_MAJOR = version_info.version_major;
pub const VERSION_MINOR = version_info.version_minor;
pub const VERSION_PATCH = version_info.version_patch;
pub const MINIMUM_ZIG_VERSION = version_info.minimum_zig_version;

/// High-level argument parser with fluent API.
pub const ArgumentParser = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    version: ?[]const u8 = null,
    description: ?[]const u8 = null,
    epilog: ?[]const u8 = null,
    args: std.ArrayListUnmanaged(ArgSpec),
    groups: std.ArrayListUnmanaged(ArgumentGroup),
    subcommands: std.ArrayListUnmanaged(SubcommandSpec),
    current_group: ?*ArgumentGroup = null,
    add_help: bool = true,
    add_version: bool = true,
    cfg: Config,
    update_thread: ?std.Thread = null,

    pub const InitOptions = struct {
        name: []const u8,
        version: ?[]const u8 = null,
        description: ?[]const u8 = null,
        epilog: ?[]const u8 = null,
        add_help: bool = true,
        add_version: bool = true,
        config: ?Config = null,
    };

    /// Initialize a new argument parser.
    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !ArgumentParser {
        const cfg = options.config orelse config.getConfig();

        var update_thread: ?std.Thread = null;
        if (cfg.check_for_updates and !builtin.is_test) {
            update_thread = update_checker.checkForUpdates(allocator, cfg.show_update_notification);
        }

        return .{
            .allocator = allocator,
            .name = options.name,
            .version = options.version,
            .description = options.description,
            .epilog = options.epilog,
            .args = .empty,
            .groups = .empty,
            .subcommands = .empty,
            .add_help = options.add_help,
            .add_version = options.add_version,
            .cfg = cfg,
            .update_thread = update_thread,
        };
    }

    /// Clean up resources.
    pub fn deinit(self: *ArgumentParser) void {
        self.args.deinit(self.allocator);
        for (self.groups.items) |*g| g.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.subcommands.deinit(self.allocator);
    }

    /// Add an argument with full specification.
    pub fn addArg(self: *ArgumentParser, spec: ArgSpec) !void {
        var s = spec;
        if (self.current_group) |group| {
            s.group = group.name;
        }
        try self.args.append(self.allocator, s);
    }

    /// Add a boolean flag (--verbose, -v).
    pub fn addFlag(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        dest: ?[]const u8 = null,
        hidden: bool = false,
        aliases: []const []const u8 = &.{},
        deprecated: ?[]const u8 = null,
    }) !void {
        try self.addArg(.{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .action = .store_true,
            .dest = options.dest,
            .hidden = options.hidden,
            .deprecated = options.deprecated,
        });
    }

    /// Add an option that takes a value (--output file.txt).
    pub fn addOption(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
        default: ?[]const u8 = null,
        required: bool = false,
        choices: []const []const u8 = &.{},
        metavar: ?[]const u8 = null,
        dest: ?[]const u8 = null,
        env_var: ?[]const u8 = null,
        hidden: bool = false,
        aliases: []const []const u8 = &.{},
        deprecated: ?[]const u8 = null,
        validator: ?validation.ValidatorFn = null,
    }) !void {
        try self.addArg(.{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .value_type = options.value_type,
            .default = options.default,
            .required = options.required,
            .choices = options.choices,
            .metavar = options.metavar,
            .dest = options.dest,
            .env_var = options.env_var,
            .hidden = options.hidden,
            .deprecated = options.deprecated,
            .validator = options.validator,
        });
    }

    /// Add a positional argument.
    pub fn addPositional(self: *ArgumentParser, name: []const u8, options: struct {
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
        required: bool = true,
        default: ?[]const u8 = null,
        nargs: Nargs = .{ .exact = 1 },
        metavar: ?[]const u8 = null,
    }) !void {
        try self.addArg(.{
            .name = name,
            .help = options.help,
            .value_type = options.value_type,
            .positional = true,
            .required = options.required,
            .default = options.default,
            .nargs = options.nargs,
            .metavar = options.metavar,
        });
    }

    /// Add a counter argument (-v -v -v for verbosity).
    pub fn addCounter(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        dest: ?[]const u8 = null,
    }) !void {
        try self.addArg(.{
            .name = name,
            .short = options.short,
            .long = name,
            .help = options.help,
            .action = .count,
            .value_type = .counter,
            .dest = options.dest,
        });
    }

    /// Add a subcommand.
    pub fn addSubcommand(self: *ArgumentParser, spec: SubcommandSpec) !void {
        try self.subcommands.append(self.allocator, spec);
    }

    /// Build the command specification.
    pub fn buildSpec(self: *ArgumentParser) CommandSpec {
        return .{
            .name = self.name,
            .version = self.version,
            .description = self.description,
            .args = self.args.items,
            .groups = self.groups.items,
            .subcommands = self.subcommands.items,
            .epilog = self.epilog,
            .add_help = self.add_help,
            .add_version = self.add_version,
        };
    }

    /// Parse provided arguments.
    pub fn parse(self: *ArgumentParser, args_slice: []const []const u8) !ParseResult {
        const spec = self.buildSpec();
        var p = try parser.Parser.init(self.allocator, spec);
        defer p.deinit();
        return p.parse(args_slice);
    }

    /// Parse arguments from process (std.process.args).
    pub fn parseProcess(self: *ArgumentParser) !ParseResult {
        var args_iter = try std.process.argsWithAllocator(self.allocator);
        defer args_iter.deinit();

        var args_list: std.ArrayListUnmanaged([]const u8) = .empty;
        defer args_list.deinit(self.allocator);

        _ = args_iter.next(); // Skip program name

        while (args_iter.next()) |arg| {
            try args_list.append(self.allocator, arg);
        }

        return self.parse(args_list.items);
    }

    /// Generate help text.
    pub fn getHelp(self: *ArgumentParser) ![]const u8 {
        const spec = self.buildSpec();
        return help.generateHelp(self.allocator, spec, self.cfg.use_colors);
    }

    /// Print help to stdout.
    pub fn printHelp(self: *ArgumentParser) !void {
        const help_text = try self.getHelp();
        defer self.allocator.free(help_text);
        std.debug.print("{s}", .{help_text});
    }

    /// Generate shell completion script.
    pub fn generateCompletion(self: *ArgumentParser, shell: Shell) ![]const u8 {
        const spec = self.buildSpec();
        return completion.generateCompletion(self.allocator, spec, shell);
    }

    /// Get usage string.
    pub fn getUsage(self: *ArgumentParser) ![]const u8 {
        const spec = self.buildSpec();
        return help.generateUsage(self.allocator, spec);
    }

    /// Get parser version.
    pub fn getVersion(self: *ArgumentParser) []const u8 {
        return self.version orelse VERSION;
    }

    /// Add an option that appends values to an array.
    pub fn addAppend(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        metavar: ?[]const u8 = null,
        dest: ?[]const u8 = null,
        aliases: []const []const u8 = &.{},
    }) !void {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .action = .append,
            .metavar = options.metavar,
            .dest = options.dest,
            .nargs = .zero_or_more,
        });
    }

    /// Add a multi-value option (accepts multiple values).
    pub fn addMultiple(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        min: usize = 1,
        max: ?usize = null,
        metavar: ?[]const u8 = null,
        aliases: []const []const u8 = &.{},
    }) !void {
        const nargs: Nargs = if (options.min == 0)
            .zero_or_more
        else if (options.max == null)
            .one_or_more
        else
            .{ .exact = options.max.? };

        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .nargs = nargs,
            .metavar = options.metavar,
        });
    }

    /// Set the argument group for subsequent arguments.
    /// Set the argument group for subsequent arguments.
    /// If group_name is null, resets to default (no group).
    pub fn setGroup(self: *ArgumentParser, group_name: ?[]const u8) void {
        if (group_name) |name| {
            for (self.groups.items) |*g| {
                if (utils.eql(g.name, name)) {
                    self.current_group = g;
                    return;
                }
            }
            // Group must be created first via addArgumentGroup.
            self.current_group = null;
        } else {
            self.current_group = null;
        }
    }

    /// Add a new argument group and set it as current.
    pub fn addArgumentGroup(self: *ArgumentParser, name: []const u8, options: struct {
        description: ?[]const u8 = null,
        exclusive: bool = false,
        required: bool = false,
    }) !void {
        try self.groups.append(self.allocator, .{
            .name = name,
            .description = options.description,
            .exclusive = options.exclusive,
            .required = options.required,
        });
        self.current_group = &self.groups.items[self.groups.items.len - 1];
    }

    /// Add an option with environment variable fallback and programmatic default.
    pub fn fromEnvOrDefault(
        self: *ArgumentParser,
        name: []const u8,
        env_var: []const u8,
        default_value: []const u8,
        options: struct {
            short: ?u8 = null,
            help: ?[]const u8 = null,
            value_type: ValueType = .string,
            aliases: []const []const u8 = &.{},
        },
    ) !void {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .value_type = options.value_type,
            .env_var = env_var,
            .default = default_value,
        });
    }

    /// Print version to stdout.
    pub fn printVersion(self: *ArgumentParser) void {
        std.debug.print("{s} {s}\n", .{ self.name, self.getVersion() });
    }

    /// Check if an argument with the given name exists.
    pub fn hasArg(self: *ArgumentParser, name: []const u8) bool {
        for (self.args.items) |arg| {
            if (utils.eql(arg.name, name)) return true;
            if (arg.long) |long| {
                if (utils.eql(long, name)) return true;
            }
        }
        return false;
    }

    /// Get the number of defined arguments.
    pub fn argCount(self: *ArgumentParser) usize {
        return self.args.items.len;
    }

    /// Get the number of defined subcommands.
    pub fn subcommandCount(self: *ArgumentParser) usize {
        return self.subcommands.items.len;
    }

    /// Add a required option (shorthand for addOption with required=true).
    pub fn addRequired(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
        metavar: ?[]const u8 = null,
    }) !void {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .help = options.help,
            .value_type = options.value_type,
            .required = true,
            .metavar = options.metavar,
        });
    }

    /// Add a hidden flag (won't appear in help).
    pub fn addHiddenFlag(self: *ArgumentParser, name: []const u8, options: struct {
        short: ?u8 = null,
        dest: ?[]const u8 = null,
    }) !void {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .action = .store_true,
            .dest = options.dest,
            .hidden = true,
        });
    }

    /// Add a deprecated option with warning message.
    pub fn addDeprecated(self: *ArgumentParser, name: []const u8, warning: []const u8, options: struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
        aliases: []const []const u8 = &.{},
    }) !void {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = options.short,
            .long = name,
            .aliases = options.aliases,
            .help = options.help,
            .value_type = options.value_type,
            .deprecated = warning,
        });
    }
};

/// Convenience function for quick parsing with minimal setup.
pub fn parse(
    allocator: std.mem.Allocator,
    comptime args_spec: []const ArgSpec,
    args_slice: []const []const u8,
) !ParseResult {
    const spec = CommandSpec{
        .name = "program",
        .args = args_spec,
    };
    return parser.parseArgs(allocator, spec, args_slice);
}

/// Initialize global configuration.
pub fn initConfig(cfg: Config) void {
    config.initConfig(cfg);
}

/// Reset global configuration to defaults.
pub fn resetConfig() void {
    config.resetConfig();
}

/// Disable update checking globally.
pub fn disableUpdateCheck() void {
    config.setConfigValue("check_for_updates", false);
}

/// Enable update checking globally.
pub fn enableUpdateCheck() void {
    config.setConfigValue("check_for_updates", true);
}

/// Get current library version.
pub fn getLibraryVersion() []const u8 {
    return VERSION;
}

test "ArgumentParser basic usage" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A test application",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose mode" });
    try ap.addOption("output", .{ .short = 'o', .help = "Output file" });
    try ap.addPositional("input", .{ .help = "Input file" });

    const args = [_][]const u8{ "-v", "--output", "out.txt", "in.txt" };
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expect(result.getBool("verbose").?);
    try std.testing.expectEqualStrings("out.txt", result.getString("output").?);
    try std.testing.expectEqualStrings("in.txt", result.getString("input").?);
}

test "ArgumentParser counter" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addCounter("verbose", .{ .short = 'v', .help = "Increase verbosity" });

    const args = [_][]const u8{ "-v", "-v", "-v" };
    var result = try ap.parse(&args);
    defer result.deinit();

    const val = result.get("verbose").?;
    try std.testing.expectEqual(@as(u32, 3), val.counter);
}

test "ArgumentParser with choices" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addOption("level", .{
        .short = 'l',
        .choices = &[_][]const u8{ "debug", "info", "warn", "error" },
    });

    const args = [_][]const u8{ "-l", "info" };
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("info", result.getString("level").?);
}

test "ArgumentParser with default values" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addOption("count", .{
        .short = 'n',
        .value_type = .int,
        .default = "10",
    });

    const args = [_][]const u8{};
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(?i64, 10), result.getInt("count"));
}

test "ArgumentParser help generation" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "2.0.0",
        .description = "My application",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });

    const help_text = try ap.getHelp();
    defer allocator.free(help_text);

    try std.testing.expect(std.mem.indexOf(u8, help_text, "myapp") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "verbose") != null);
}

test "ArgumentParser usage generation" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "myapp",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addPositional("file", .{ .help = "Input file" });

    const usage = try ap.getUsage();
    defer allocator.free(usage);

    try std.testing.expect(std.mem.indexOf(u8, usage, "myapp") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "<file>") != null);
}

test "ArgumentParser completion generation" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "myapp",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addFlag("help", .{ .short = 'h' });

    const bash_comp = try ap.generateCompletion(.bash);
    defer allocator.free(bash_comp);

    try std.testing.expect(std.mem.indexOf(u8, bash_comp, "myapp") != null);
}

test "ArgumentParser version" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "3.0.0",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try std.testing.expectEqualStrings("3.0.0", ap.getVersion());
}

test "ArgumentParser integer options" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addOption("port", .{ .short = 'p', .value_type = .int });
    try ap.addOption("count", .{ .short = 'n', .value_type = .uint });

    const args = [_][]const u8{ "-p", "8080", "-n", "100" };
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(?i64, 8080), result.getInt("port"));
}

test "ArgumentParser float options" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addOption("rate", .{ .short = 'r', .value_type = .float });

    const args = [_][]const u8{ "-r", "0.5" };
    var result = try ap.parse(&args);
    defer result.deinit();

    const val = result.get("rate").?;
    try std.testing.expect(@abs(val.float - 0.5) < 0.001);
}

test "quick parse function" {
    const allocator = std.testing.allocator;

    config.initConfig(Config.minimal());
    defer config.resetConfig();

    const spec = [_]ArgSpec{
        .{ .name = "verbose", .short = 'v', .long = "verbose", .action = .store_true },
    };

    const args = [_][]const u8{"-v"};
    var result = try parse(allocator, &spec, &args);
    defer result.deinit();

    try std.testing.expect(result.getBool("verbose").?);
}

test "disableUpdateCheck and enableUpdateCheck" {
    disableUpdateCheck();
    const cfg = config.getConfig();
    try std.testing.expect(!cfg.check_for_updates);

    enableUpdateCheck();
    const cfg2 = config.getConfig();
    try std.testing.expect(cfg2.check_for_updates);

    config.resetConfig();
}

test "getLibraryVersion" {
    const ver = getLibraryVersion();
    try std.testing.expectEqualStrings("0.0.2", ver);
}

test "ArgumentParser subcommand" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "git",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addSubcommand(.{
        .name = "clone",
        .help = "Clone a repository",
        .args = &[_]ArgSpec{
            .{ .name = "url", .positional = true, .required = true },
        },
    });

    const args = [_][]const u8{ "clone", "https://example.com/repo.git" };
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("clone", result.subcommand.?);
    try std.testing.expectEqualStrings("https://example.com/repo.git", result.subcommand_args.?.getString("url").?);
}

test "ArgumentParser inline value" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addOption("output", .{ .short = 'o' });

    const args = [_][]const u8{"--output=file.txt"};
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("file.txt", result.getString("output").?);
}

test "ArgumentParser separator handling" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    const args = [_][]const u8{ "--", "--not-an-option", "regular" };
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.remaining.items.len);
    try std.testing.expectEqualStrings("--not-an-option", result.remaining.items[0]);
}

test "ArgumentParser hasArg and argCount" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addFlag("verbose", .{ .short = 'v' });
    try ap.addOption("output", .{ .short = 'o' });

    try std.testing.expect(ap.hasArg("verbose"));
    try std.testing.expect(ap.hasArg("output"));
    try std.testing.expect(!ap.hasArg("nonexistent"));
    try std.testing.expectEqual(@as(usize, 2), ap.argCount());
}

test "ArgumentParser addRequired" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addRequired("config", .{ .short = 'c', .help = "Config file" });

    try std.testing.expect(ap.hasArg("config"));
}

test "ArgumentParser addHiddenFlag" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addHiddenFlag("debug-internal", .{});

    try std.testing.expect(ap.hasArg("debug-internal"));
}

test "ArgumentParser addDeprecated" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addDeprecated("old-flag", "Use --new-flag instead", .{});

    try std.testing.expect(ap.hasArg("old-flag"));
}

test "ArgumentParser fromEnvOrDefault" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.fromEnvOrDefault("token", "API_TOKEN", "default-token", .{
        .short = 't',
        .help = "API token",
    });

    try std.testing.expect(ap.hasArg("token"));
}

test "ArgumentParser subcommandCount" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addSubcommand(.{ .name = "init", .help = "Initialize" });
    try ap.addSubcommand(.{ .name = "build", .help = "Build" });

    try std.testing.expectEqual(@as(usize, 2), ap.subcommandCount());
}

// Run all sub-module tests
test {
    _ = @import("types.zig");
    _ = @import("schema.zig");
    _ = @import("tokenizer.zig");
    _ = @import("parser.zig");
    _ = @import("validation.zig");
    _ = @import("errors.zig");
    _ = @import("help.zig");
    _ = @import("completion.zig");
    _ = @import("config.zig");
}
