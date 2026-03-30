//! Argument parsing library for Zig.
//! Provides a fluent API for defining and parsing command-line arguments.

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

/// Main argument parser structure providing a fluent API.
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

    /// Initializes a new argument parser instance.
    ///
    /// The parser will use the provided allocator for all dynamic allocations.
    /// If config is not provided, the default global configuration is used.
    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !ArgumentParser {
        const cfg = options.config orelse config.getConfig();

        var update_thread: ?std.Thread = null;
        if (cfg.check_for_updates and !builtin.is_test) {
            update_thread = update_checker.checkForUpdates(allocator, cfg.show_update_notification, cfg.use_colors);
        }

        return .{
            .allocator = allocator,
            .name = if (options.name.len > 0) options.name else (cfg.app_name orelse "app"),
            .version = options.version orelse cfg.app_version,
            .description = options.description orelse cfg.app_description,
            .epilog = options.epilog orelse cfg.app_epilog,
            .args = .empty,
            .groups = .empty,
            .subcommands = .empty,
            .add_help = options.add_help,
            .add_version = options.add_version,
            .cfg = cfg,
            .update_thread = update_thread,
        };
    }

    /// Releases all resources allocated by the parser.
    pub fn deinit(self: *ArgumentParser) void {
        self.args.deinit(self.allocator);
        for (self.groups.items) |*g| g.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.subcommands.deinit(self.allocator);
    }

    /// Adds a fully specified argument to the parser.
    pub fn addArg(self: *ArgumentParser, spec: ArgSpec) !void {
        var s = spec;
        if (self.current_group) |group| {
            s.group = group.name;
        }

        if (self.hasArg(s.name)) return error.DuplicateArgument;
        if (s.long) |l| {
            if (self.hasArg(l)) return error.DuplicateArgument;
        }
        if (s.short) |sh| {
            if (self.hasShort(sh)) return error.DuplicateArgument;
        }
        try self.args.append(self.allocator, s);
    }

    /// Adds a boolean flag argument (e.g., --verbose, -v).
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

    /// Adds an inverse boolean flag argument (e.g., --no-color, --disable-cache).
    /// When present, this stores `false` in the destination.
    pub fn addFalseFlag(self: *ArgumentParser, name: []const u8, options: struct {
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
            .action = .store_false,
            .dest = options.dest,
            .hidden = options.hidden,
            .deprecated = options.deprecated,
        });
    }

    /// Adds an option that expects a value (e.g., --output file.txt).
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
        expect: []const []const u8 = &.{},
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
            .expect = options.expect,
        });
    }

    /// Adds a positional argument.
    pub fn addPositional(self: *ArgumentParser, name: []const u8, options: struct {
        help: ?[]const u8 = null,
        value_type: ValueType = .string,
        required: bool = true,
        default: ?[]const u8 = null,
        nargs: Nargs = .{ .exact = 1 },
        metavar: ?[]const u8 = null,
        choices: []const []const u8 = &.{},
        expect: []const []const u8 = &.{},
        validator: ?validation.ValidatorFn = null,
        hidden: bool = false,
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
            .choices = options.choices,
            .expect = options.expect,
            .validator = options.validator,
            .hidden = options.hidden,
        });
    }

    /// Adds a counter argument (e.g., -v -v -v).
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

    /// Adds a conventional `--all` flag used by many command-line tools.
    pub fn addAllFlag(self: *ArgumentParser, options: struct {
        name: []const u8 = "all",
        short: ?u8 = null,
        help: ?[]const u8 = "Select all items",
        dest: ?[]const u8 = null,
        hidden: bool = false,
        aliases: []const []const u8 = &.{},
        deprecated: ?[]const u8 = null,
    }) !void {
        try self.addFlag(options.name, .{
            .short = options.short,
            .help = options.help,
            .dest = options.dest,
            .hidden = options.hidden,
            .aliases = options.aliases,
            .deprecated = options.deprecated,
        });
    }

    /// Adds a conventional `--select` option used to target a subset of items.
    pub fn addSelectOption(self: *ArgumentParser, options: struct {
        name: []const u8 = "select",
        short: ?u8 = null,
        help: ?[]const u8 = "Select specific items",
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
        expect: []const []const u8 = &.{},
    }) !void {
        try self.addOption(options.name, .{
            .short = options.short,
            .help = options.help,
            .value_type = options.value_type,
            .default = options.default,
            .required = options.required,
            .choices = options.choices,
            .metavar = options.metavar,
            .dest = options.dest,
            .env_var = options.env_var,
            .hidden = options.hidden,
            .aliases = options.aliases,
            .deprecated = options.deprecated,
            .validator = options.validator,
            .expect = options.expect,
        });
    }

    /// Adds an exclusive selection pair (`--select` vs `--all`) commonly used in CMD/CLI tools.
    pub fn addSelectOrAll(self: *ArgumentParser, options: struct {
        group_name: []const u8 = "Selection",
        group_description: ?[]const u8 = "Target selection options",
        required: bool = false,
        select_name: []const u8 = "select",
        select_short: ?u8 = null,
        select_help: ?[]const u8 = "Select specific items",
        select_value_type: ValueType = .string,
        select_default: ?[]const u8 = null,
        select_choices: []const []const u8 = &.{},
        select_metavar: ?[]const u8 = null,
        select_dest: ?[]const u8 = null,
        select_env_var: ?[]const u8 = null,
        select_aliases: []const []const u8 = &.{},
        select_deprecated: ?[]const u8 = null,
        select_validator: ?validation.ValidatorFn = null,
        select_expect: []const []const u8 = &.{},
        all_name: []const u8 = "all",
        all_short: ?u8 = null,
        all_help: ?[]const u8 = "Select all items",
        all_dest: ?[]const u8 = null,
        all_aliases: []const []const u8 = &.{},
        all_deprecated: ?[]const u8 = null,
    }) !void {
        try self.addArgumentGroup(options.group_name, .{
            .description = options.group_description,
            .exclusive = true,
            .required = options.required,
        });

        try self.addSelectOption(.{
            .name = options.select_name,
            .short = options.select_short,
            .help = options.select_help,
            .value_type = options.select_value_type,
            .default = options.select_default,
            .choices = options.select_choices,
            .metavar = options.select_metavar,
            .dest = options.select_dest,
            .env_var = options.select_env_var,
            .aliases = options.select_aliases,
            .deprecated = options.select_deprecated,
            .validator = options.select_validator,
            .expect = options.select_expect,
        });

        try self.addAllFlag(.{
            .name = options.all_name,
            .short = options.all_short,
            .help = options.all_help,
            .dest = options.all_dest,
            .aliases = options.all_aliases,
            .deprecated = options.all_deprecated,
        });

        self.setGroup(null);
    }

    /// Adds a conventional `--include` option for comma-separated target filters.
    pub fn addIncludeOption(self: *ArgumentParser, options: struct {
        name: []const u8 = "include",
        short: ?u8 = null,
        help: ?[]const u8 = "Comma-separated include filters",
        dest: ?[]const u8 = null,
        env_var: ?[]const u8 = null,
        hidden: bool = false,
        aliases: []const []const u8 = &.{},
        deprecated: ?[]const u8 = null,
    }) !void {
        try self.addOption(options.name, .{
            .short = options.short,
            .help = options.help,
            .dest = options.dest,
            .env_var = options.env_var,
            .hidden = options.hidden,
            .aliases = options.aliases,
            .deprecated = options.deprecated,
            .metavar = "LIST",
        });
    }

    /// Adds a conventional `--exclude` option for comma-separated target filters.
    pub fn addExcludeOption(self: *ArgumentParser, options: struct {
        name: []const u8 = "exclude",
        short: ?u8 = null,
        help: ?[]const u8 = "Comma-separated exclude filters",
        dest: ?[]const u8 = null,
        env_var: ?[]const u8 = null,
        hidden: bool = false,
        aliases: []const []const u8 = &.{},
        deprecated: ?[]const u8 = null,
    }) !void {
        try self.addOption(options.name, .{
            .short = options.short,
            .help = options.help,
            .dest = options.dest,
            .env_var = options.env_var,
            .hidden = options.hidden,
            .aliases = options.aliases,
            .deprecated = options.deprecated,
            .metavar = "LIST",
        });
    }

    /// Adds both include/exclude filters under a shared group for better help organization.
    pub fn addIncludeExclude(self: *ArgumentParser, options: struct {
        group_name: []const u8 = "Filters",
        group_description: ?[]const u8 = "Target filtering options",
        include_name: []const u8 = "include",
        include_short: ?u8 = null,
        include_help: ?[]const u8 = "Comma-separated include filters",
        include_dest: ?[]const u8 = null,
        include_env_var: ?[]const u8 = null,
        include_aliases: []const []const u8 = &.{},
        include_deprecated: ?[]const u8 = null,
        exclude_name: []const u8 = "exclude",
        exclude_short: ?u8 = null,
        exclude_help: ?[]const u8 = "Comma-separated exclude filters",
        exclude_dest: ?[]const u8 = null,
        exclude_env_var: ?[]const u8 = null,
        exclude_aliases: []const []const u8 = &.{},
        exclude_deprecated: ?[]const u8 = null,
    }) !void {
        try self.addArgumentGroup(options.group_name, .{
            .description = options.group_description,
            .exclusive = false,
            .required = false,
        });

        try self.addIncludeOption(.{
            .name = options.include_name,
            .short = options.include_short,
            .help = options.include_help,
            .dest = options.include_dest,
            .env_var = options.include_env_var,
            .aliases = options.include_aliases,
            .deprecated = options.include_deprecated,
        });

        try self.addExcludeOption(.{
            .name = options.exclude_name,
            .short = options.exclude_short,
            .help = options.exclude_help,
            .dest = options.exclude_dest,
            .env_var = options.exclude_env_var,
            .aliases = options.exclude_aliases,
            .deprecated = options.exclude_deprecated,
        });

        self.setGroup(null);
    }

    /// Registers a subcommand.
    pub fn addSubcommand(self: *ArgumentParser, spec: SubcommandSpec) !void {
        try self.subcommands.append(self.allocator, spec);
    }

    /// Builds the internal command specification.
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

    /// Parses the provided argument slice.
    pub fn parse(self: *ArgumentParser, args_slice: []const []const u8) !ParseResult {
        const spec = self.buildSpec();
        var p = try parser.Parser.init(self.allocator, spec);
        defer p.deinit();
        return p.parse(args_slice);
    }

    /// Parses arguments from the process's command line.
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

    /// Generates the help text for the configured arguments.
    pub fn getHelp(self: *ArgumentParser) ![]const u8 {
        const spec = self.buildSpec();
        return help.generateHelp(self.allocator, spec, self.cfg.use_colors);
    }

    /// Prints the help text to stdout.
    pub fn printHelp(self: *ArgumentParser) !void {
        const help_text = try self.getHelp();
        defer self.allocator.free(help_text);
        std.debug.print("{s}", .{help_text});
    }

    /// Generates a shell completion script.
    pub fn generateCompletion(self: *ArgumentParser, shell: Shell) ![]const u8 {
        const spec = self.buildSpec();
        return completion.generateCompletion(self.allocator, spec, shell);
    }

    /// Generates the usage string.
    pub fn getUsage(self: *ArgumentParser) ![]const u8 {
        const spec = self.buildSpec();
        return help.generateUsage(self.allocator, spec);
    }

    /// Returns the parser version.
    pub fn getVersion(self: *ArgumentParser) []const u8 {
        return self.version orelse VERSION;
    }

    /// Adds an option that appends values to a list.
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

    /// Adds a multi-value option (accepts multiple values).
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

    /// Sets the current argument group for subsequent arguments.
    /// If group_name is null, resets to the default (no group).
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

    /// Creates a new argument group and sets it as active.
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

    /// Adds an option with an environment variable fallback and default value.
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

    /// Prints the version to stdout.
    pub fn printVersion(self: *ArgumentParser) void {
        std.debug.print("{s} {s}\n", .{ self.name, self.getVersion() });
    }

    /// Checks if a short flag exists.
    pub fn hasShort(self: *ArgumentParser, short: u8) bool {
        for (self.args.items) |arg| {
            if (arg.short) |s| {
                if (s == short) return true;
            }
        }
        return false;
    }

    /// Checks if an argument with the specified name exists.
    pub fn hasArg(self: *ArgumentParser, name: []const u8) bool {
        for (self.args.items) |arg| {
            if (utils.eql(arg.name, name)) return true;
            if (arg.long) |long| {
                if (utils.eql(long, name)) return true;
            }
            for (arg.aliases) |alias| {
                if (utils.eql(alias, name)) return true;
            }
        }
        return false;
    }

    /// Returns the number of defined arguments.
    pub fn argCount(self: *ArgumentParser) usize {
        return self.args.items.len;
    }

    /// Returns the number of defined subcommands.
    pub fn subcommandCount(self: *ArgumentParser) usize {
        return self.subcommands.items.len;
    }

    /// Adds a required option.
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

    /// Adds a hidden flag (excluded from help text).
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

    /// Adds a deprecated option with a warning message.
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

/// Convenience function for quick parsing.
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

/// Parses command-line arguments directly into a struct type.
///
/// This function derives argument specifications from the struct fields at compile-time
/// and maps parsed values back to the struct. Uses global config for app metadata
/// if not provided in options.
///
/// Example:
/// ```zig
/// const Config = struct { verbose: bool, output: ?[]const u8 };
/// var result = try args.parseInto(allocator, Config, .{ .name = "myapp" }, null);
/// defer result.deinit();
/// std.debug.print("Verbose: {}\n", .{result.options.verbose});
/// ```
pub fn parseInto(
    allocator: std.mem.Allocator,
    comptime T: type,
    options: ArgumentParser.InitOptions,
    args_slice: ?[]const []const u8,
) !ParseIntoResult(T) {
    var arg_parser = try ArgumentParser.init(allocator, options);
    defer arg_parser.deinit();

    const specs = comptime schema.deriveOptions(T);
    for (specs) |spec| {
        try arg_parser.addArg(spec);
    }

    var result = if (args_slice) |a| try arg_parser.parse(a) else try arg_parser.parseProcess();

    var opts: T = undefined;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        const kebab_name = comptime blk: {
            var buf: [field.name.len]u8 = undefined;
            for (field.name, 0..) |c, i| {
                buf[i] = if (c == '_') '-' else c;
            }
            const final_buf = buf;
            break :blk final_buf;
        };

        const val_opt = result.get(&kebab_name);
        const FT = field.type;

        if (FT == bool) {
            @field(opts, field.name) = if (val_opt) |v| (v.asBool() orelse false) else false;
        } else if (FT == ?bool) {
            @field(opts, field.name) = if (val_opt) |v| v.asBool() else null;
        } else if (FT == []const u8) {
            @field(opts, field.name) = if (val_opt) |v| (v.asString() orelse "") else "";
        } else if (FT == ?[]const u8) {
            @field(opts, field.name) = if (val_opt) |v| v.asString() else null;
        } else if (FT == i32) {
            @field(opts, field.name) = if (val_opt) |v| @as(i32, @intCast(v.asInt() orelse 0)) else 0;
        } else if (FT == i64) {
            @field(opts, field.name) = if (val_opt) |v| (v.asInt() orelse 0) else 0;
        } else if (FT == ?f64) {
            @field(opts, field.name) = if (val_opt) |v| v.asFloat() else null;
        }
    }

    return .{ .options = opts, .result = result };
}

/// Result type for `parseInto` function.
pub fn ParseIntoResult(comptime T: type) type {
    return struct {
        options: T,
        result: ParseResult,

        /// Deinitializes the parse result, freeing associated memory.
        pub fn deinit(self: *@This()) void {
            self.result.deinit();
        }
    };
}

/// Initializes the global configuration.
pub fn initConfig(cfg: Config) void {
    config.initConfig(cfg);
}

/// Resets the global configuration to defaults.
pub fn resetConfig() void {
    config.resetConfig();
}

/// Disables global update checking.
pub fn disableUpdateCheck() void {
    config.setConfigValue("check_for_updates", false);
}

/// Enables global update checking.
pub fn enableUpdateCheck() void {
    config.setConfigValue("check_for_updates", true);
}

/// Returns the current library version.
pub fn getLibraryVersion() []const u8 {
    return VERSION;
}

/// Alias for `parseInto`. Parses arguments directly into a struct type.
pub const derive = parseInto;

/// Alias for `initConfig`. Sets global configuration.
pub const configure = initConfig;

/// Alias for `getLibraryVersion`. Returns library version string.
pub const version = getLibraryVersion;

/// Derives argument specifications from a struct type (compile-time).
/// This is a re-export of `schema.deriveOptions` for convenience.
pub const deriveOptions = schema.deriveOptions;

pub const PromptSelectOrAllOptions = struct {
    select_key: []const u8 = "select",
    all_key: []const u8 = "all",
    question: []const u8 = "Choose target",
    choices: []const []const u8,
    default_choice: ?[]const u8 = null,
    allow_all: bool = true,
    case_sensitive: bool = false,
    allow_prefix_match: bool = true,
    suggest_closest: bool = true,
    max_suggestion_distance: usize = 3,
    max_attempts: usize = 3,
};

pub const PromptSelectOrAllDecision = union(enum) {
    all: void,
    selected: []const u8,
};

fn trimAsciiWhitespace(input: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = input.len;

    while (start < input.len and std.ascii.isWhitespace(input[start])) : (start += 1) {}
    while (end > start and std.ascii.isWhitespace(input[end - 1])) : (end -= 1) {}

    return input[start..end];
}

fn equalsWithCase(a: []const u8, b: []const u8, case_sensitive: bool) bool {
    if (case_sensitive) return std.mem.eql(u8, a, b);
    return std.ascii.eqlIgnoreCase(a, b);
}

fn pickChoiceByName(input: []const u8, choices: []const []const u8, case_sensitive: bool) ?[]const u8 {
    for (choices) |choice| {
        if (equalsWithCase(choice, input, case_sensitive)) return choice;
    }
    return null;
}

fn startsWithCase(text: []const u8, prefix: []const u8, case_sensitive: bool) bool {
    if (prefix.len > text.len) return false;
    if (case_sensitive) return std.mem.startsWith(u8, text, prefix);
    return std.ascii.eqlIgnoreCase(text[0..prefix.len], prefix);
}

fn pickChoiceByUniquePrefix(input: []const u8, choices: []const []const u8, case_sensitive: bool) ?[]const u8 {
    var found: ?[]const u8 = null;
    for (choices) |choice| {
        if (startsWithCase(choice, input, case_sensitive)) {
            if (found != null) return null;
            found = choice;
        }
    }
    return found;
}

/// Parses comma-separated values into trimmed non-empty items.
/// The returned slice and each item are owned by the caller allocator.
pub fn parseCsvList(allocator: std.mem.Allocator, raw: []const u8) ![][]const u8 {
    var items = std.ArrayListUnmanaged([]const u8).empty;
    errdefer {
        for (items.items) |item| allocator.free(item);
        items.deinit(allocator);
    }

    var it = std.mem.splitScalar(u8, raw, ',');
    while (it.next()) |part| {
        const trimmed = trimAsciiWhitespace(part);
        if (trimmed.len == 0) continue;
        const owned = try allocator.dupe(u8, trimmed);
        try items.append(allocator, owned);
    }

    return items.toOwnedSlice(allocator);
}

/// Frees list returned by parseCsvList.
pub fn deinitCsvList(allocator: std.mem.Allocator, items: [][]const u8) void {
    for (items) |item| allocator.free(item);
    allocator.free(items);
}

pub const IncludeExcludeResolved = struct {
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IncludeExcludeResolved) void {
        deinitCsvList(self.allocator, self.include);
        deinitCsvList(self.allocator, self.exclude);
    }
};

pub const IncludeExcludeStrictOptions = struct {
    include_key: []const u8 = "include",
    exclude_key: []const u8 = "exclude",
    choices: []const []const u8 = &.{},
    all_keyword: ?[]const u8 = "all",
    case_sensitive: bool = false,
    allow_prefix_match: bool = true,
    dedupe: bool = true,
    fail_on_conflicts: bool = true,
};

pub const IncludeExcludeStrictResolved = struct {
    all: bool,
    include: [][]const u8,
    exclude: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *IncludeExcludeStrictResolved) void {
        deinitCsvList(self.allocator, self.include);
        deinitCsvList(self.allocator, self.exclude);
    }
};

fn indexOfFilterValue(items: [][]const u8, value: []const u8, case_sensitive: bool) ?usize {
    for (items, 0..) |item, idx| {
        if (equalsWithCase(item, value, case_sensitive)) return idx;
    }
    return null;
}

fn appendFilterValue(
    allocator: std.mem.Allocator,
    items: *std.ArrayListUnmanaged([]const u8),
    value: []const u8,
    case_sensitive: bool,
    dedupe: bool,
) !void {
    if (dedupe and indexOfFilterValue(items.items, value, case_sensitive) != null) return;

    const owned = try allocator.dupe(u8, value);
    errdefer allocator.free(owned);
    try items.append(allocator, owned);
}

fn normalizeFilterValue(raw_value: []const u8, options: IncludeExcludeStrictOptions) ![]const u8 {
    if (options.choices.len == 0) return raw_value;

    if (pickChoiceByName(raw_value, options.choices, options.case_sensitive)) |matched| {
        return matched;
    }

    if (options.allow_prefix_match) {
        if (pickChoiceByUniquePrefix(raw_value, options.choices, options.case_sensitive)) |matched| {
            return matched;
        }
    }

    return error.InvalidChoice;
}

pub fn resolveIncludeExclude(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    include_key: []const u8,
    exclude_key: []const u8,
) !IncludeExcludeResolved {
    const include_raw = parsed.getString(include_key) orelse "";
    const exclude_raw = parsed.getString(exclude_key) orelse "";

    return .{
        .include = try parseCsvList(allocator, include_raw),
        .exclude = try parseCsvList(allocator, exclude_raw),
        .allocator = allocator,
    };
}

pub fn resolveIncludeExcludeStrict(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: IncludeExcludeStrictOptions,
) !IncludeExcludeStrictResolved {
    var include_out = std.ArrayListUnmanaged([]const u8).empty;
    errdefer {
        for (include_out.items) |item| allocator.free(item);
        include_out.deinit(allocator);
    }

    var exclude_out = std.ArrayListUnmanaged([]const u8).empty;
    errdefer {
        for (exclude_out.items) |item| allocator.free(item);
        exclude_out.deinit(allocator);
    }

    const include_raw = parsed.getString(options.include_key) orelse "";
    const exclude_raw = parsed.getString(options.exclude_key) orelse "";

    const include_items = try parseCsvList(allocator, include_raw);
    defer deinitCsvList(allocator, include_items);
    const exclude_items = try parseCsvList(allocator, exclude_raw);
    defer deinitCsvList(allocator, exclude_items);

    var all = false;

    for (include_items) |raw_item| {
        if (options.all_keyword) |all_keyword| {
            if (equalsWithCase(raw_item, all_keyword, options.case_sensitive)) {
                all = true;
                continue;
            }
        }

        const normalized = try normalizeFilterValue(raw_item, options);
        try appendFilterValue(allocator, &include_out, normalized, options.case_sensitive, options.dedupe);
    }

    for (exclude_items) |raw_item| {
        const normalized = try normalizeFilterValue(raw_item, options);
        try appendFilterValue(allocator, &exclude_out, normalized, options.case_sensitive, options.dedupe);
    }

    if (all) {
        for (include_out.items) |item| allocator.free(item);
        include_out.clearAndFree(allocator);
    }

    if (options.fail_on_conflicts and !all) {
        for (include_out.items) |item| {
            if (indexOfFilterValue(exclude_out.items, item, options.case_sensitive) != null) {
                return error.IncludeExcludeConflict;
            }
        }
    }

    return .{
        .all = all,
        .include = try include_out.toOwnedSlice(allocator),
        .exclude = try exclude_out.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

fn writePromptMenu(writer: anytype, options: PromptSelectOrAllOptions) !void {
    try writer.print("{s}:\n", .{options.question});
    if (options.allow_all) {
        try writer.writeAll("  0) all\n");
    }
    for (options.choices, 0..) |choice, idx| {
        try writer.print("  {d}) {s}\n", .{ idx + 1, choice });
    }
    try writer.writeAll("Enter number or name: ");
}

pub fn resolveSelectOrAllWithPromptIO(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
    reader: anytype,
    writer: anytype,
) !PromptSelectOrAllDecision {
    if (options.choices.len == 0 and !options.allow_all) return error.InvalidConfig;

    if (parsed.getBool(options.all_key)) |enabled| {
        if (enabled) return .{ .all = {} };
    }

    if (parsed.getString(options.select_key)) |selected| {
        if (options.choices.len > 0) {
            if (pickChoiceByName(selected, options.choices, options.case_sensitive)) |matched| {
                return .{ .selected = matched };
            }
            if (options.allow_prefix_match) {
                if (pickChoiceByUniquePrefix(selected, options.choices, options.case_sensitive)) |matched| {
                    return .{ .selected = matched };
                }
            }
            return error.InvalidChoice;
        }
        return .{ .selected = selected };
    }

    var attempts_left = options.max_attempts;
    while (attempts_left > 0) : (attempts_left -= 1) {
        try writePromptMenu(writer, options);

        const line_opt = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024);
        if (line_opt == null) return error.EndOfStream;
        defer allocator.free(line_opt.?);

        const answer = trimAsciiWhitespace(line_opt.?);

        if (answer.len == 0) {
            if (options.default_choice) |def| {
                if (options.allow_all and equalsWithCase(def, "all", options.case_sensitive)) {
                    return .{ .all = {} };
                }
                if (pickChoiceByName(def, options.choices, options.case_sensitive)) |matched| {
                    return .{ .selected = matched };
                }
            }
            try writer.writeAll("Invalid selection. Try again.\n");
            continue;
        }

        if (options.allow_all and (equalsWithCase(answer, "all", options.case_sensitive) or std.mem.eql(u8, answer, "0"))) {
            return .{ .all = {} };
        }

        const parsed_index = std.fmt.parseInt(usize, answer, 10) catch null;
        if (parsed_index) |idx| {
            if (idx >= 1 and idx <= options.choices.len) {
                return .{ .selected = options.choices[idx - 1] };
            }
        }

        if (pickChoiceByName(answer, options.choices, options.case_sensitive)) |matched| {
            return .{ .selected = matched };
        }

        if (options.allow_prefix_match) {
            if (pickChoiceByUniquePrefix(answer, options.choices, options.case_sensitive)) |matched| {
                return .{ .selected = matched };
            }
        }

        if (options.suggest_closest and options.choices.len > 0) {
            if (utils.findClosest(answer, options.choices, options.max_suggestion_distance)) |suggestion| {
                try writer.print("Did you mean '{s}'?\n", .{suggestion});
            }
        }

        try writer.writeAll("Invalid selection. Try again.\n");
    }

    return error.InvalidValue;
}

pub fn resolveSelectOrAllWithPrompt(
    allocator: std.mem.Allocator,
    parsed: *const ParseResult,
    options: PromptSelectOrAllOptions,
) !PromptSelectOrAllDecision {
    const reader = std.fs.File.stdin().deprecatedReader();
    const writer = std.fs.File.stdout().deprecatedWriter();
    return resolveSelectOrAllWithPromptIO(allocator, parsed, options, reader, writer);
}

/// Quick parse from process args with minimal setup.
/// Convenience function that creates a parser, adds specs, and parses in one call.
pub fn quickParse(
    allocator: std.mem.Allocator,
    comptime specs: []const ArgSpec,
    name: []const u8,
) !ParseResult {
    var p = try ArgumentParser.init(allocator, .{ .name = name, .config = Config.minimal() });
    defer p.deinit();
    for (specs) |spec| {
        try p.addArg(spec);
    }
    return p.parseProcess();
}

/// Creates a parser with common defaults for CLI applications.
pub fn createParser(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
    return ArgumentParser.init(allocator, .{ .name = name });
}

/// Creates a minimal parser with no extra features (no colors, no update check).
pub fn createMinimalParser(allocator: std.mem.Allocator, name: []const u8) !ArgumentParser {
    return ArgumentParser.init(allocator, .{ .name = name, .config = Config.minimal() });
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
    try std.testing.expectEqualStrings("0.0.4", ver);
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

test "ArgumentParser addFalseFlag" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addFalseFlag("color", .{ .short = 'C' });

    const args = [_][]const u8{"--color"};
    var result = try ap.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(?bool, false), result.getBool("color"));
}

test "ArgumentParser addPositional choices and hidden" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addPositional("mode", .{ .choices = &[_][]const u8{ "dev", "prod" } });
    try ap.addPositional("internal", .{ .required = false, .hidden = true });

    {
        const args = [_][]const u8{"prod"};
        var result = try ap.parse(&args);
        defer result.deinit();
        try std.testing.expectEqualStrings("prod", result.getString("mode").?);
    }

    {
        const args = [_][]const u8{"staging"};
        try std.testing.expectError(error.InvalidChoice, ap.parse(&args));
    }

    const help_text = try ap.getHelp();
    defer allocator.free(help_text);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "<internal>") == null);

    const usage = try ap.getUsage();
    defer allocator.free(usage);
    try std.testing.expect(std.mem.indexOf(u8, usage, "<internal>") == null);
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

test "ArgumentParser addAllFlag and addSelectOption" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "cmd",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addAllFlag(.{ .short = 'a' });
    try ap.addSelectOption(.{ .short = 's', .choices = &[_][]const u8{ "users", "groups" } });

    {
        const argv = [_][]const u8{"--all"};
        var result = try ap.parse(&argv);
        defer result.deinit();
        try std.testing.expectEqual(@as(?bool, true), result.getBool("all"));
    }

    {
        const argv = [_][]const u8{ "--select", "users" };
        var result = try ap.parse(&argv);
        defer result.deinit();
        try std.testing.expectEqualStrings("users", result.getString("select").?);
    }
}

test "ArgumentParser addSelectOrAll exclusivity" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "cmd",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addSelectOrAll(.{ .select_short = 's', .all_short = 'a' });

    {
        const argv = [_][]const u8{ "--select", "users" };
        var result = try ap.parse(&argv);
        defer result.deinit();
        try std.testing.expectEqualStrings("users", result.getString("select").?);
    }

    {
        const argv = [_][]const u8{"--all"};
        var result = try ap.parse(&argv);
        defer result.deinit();
        try std.testing.expectEqual(@as(?bool, true), result.getBool("all"));
    }

    {
        const argv = [_][]const u8{ "--select", "users", "--all" };
        try std.testing.expectError(error.MutuallyExclusive, ap.parse(&argv));
    }
}

test "resolveSelectOrAllWithPromptIO uses parsed values first" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{ .name = "cmd", .config = Config.minimal() });
    defer ap.deinit();

    try ap.addSelectOrAll(.{ .select_choices = &[_][]const u8{ "users", "groups" } });

    const argv = [_][]const u8{ "--select", "users" };
    var parsed = try ap.parse(&argv);
    defer parsed.deinit();

    var input_stream = std.io.fixedBufferStream("\n");
    var out_buf: [256]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&out_buf);

    const decision = try resolveSelectOrAllWithPromptIO(
        allocator,
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups" } },
        input_stream.reader(),
        output_stream.writer(),
    );

    try std.testing.expect(decision == .selected);
    try std.testing.expectEqualStrings("users", decision.selected);
}

test "resolveSelectOrAllWithPromptIO can choose all" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    var input_stream = std.io.fixedBufferStream("all\n");
    var out_buf: [512]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&out_buf);

    const decision = try resolveSelectOrAllWithPromptIO(
        allocator,
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups" }, .question = "Select target" },
        input_stream.reader(),
        output_stream.writer(),
    );

    try std.testing.expect(decision == .all);
}

test "resolveSelectOrAllWithPromptIO retries invalid answers" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    var input_stream = std.io.fixedBufferStream("bad\n2\n");
    var out_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&out_buf);

    const decision = try resolveSelectOrAllWithPromptIO(
        allocator,
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups", "logs" }, .max_attempts = 3 },
        input_stream.reader(),
        output_stream.writer(),
    );

    try std.testing.expect(decision == .selected);
    try std.testing.expectEqualStrings("groups", decision.selected);
}

test "resolveSelectOrAllWithPromptIO supports unique prefix" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    var input_stream = std.io.fixedBufferStream("gr\n");
    var out_buf: [512]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&out_buf);

    const decision = try resolveSelectOrAllWithPromptIO(
        allocator,
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups", "logs" }, .allow_prefix_match = true },
        input_stream.reader(),
        output_stream.writer(),
    );

    try std.testing.expect(decision == .selected);
    try std.testing.expectEqualStrings("groups", decision.selected);
}

test "parseCsvList trims and drops empty values" {
    const allocator = std.testing.allocator;

    const items = try parseCsvList(allocator, " users,groups, ,logs ,, ");
    defer deinitCsvList(allocator, items);

    try std.testing.expectEqual(@as(usize, 3), items.len);
    try std.testing.expectEqualStrings("users", items[0]);
    try std.testing.expectEqualStrings("groups", items[1]);
    try std.testing.expectEqualStrings("logs", items[2]);
}

test "ArgumentParser addIncludeExclude helpers" {
    const allocator = std.testing.allocator;

    var ap = try ArgumentParser.init(allocator, .{
        .name = "cmd",
        .config = Config.minimal(),
    });
    defer ap.deinit();

    try ap.addIncludeExclude(.{ .include_short = 'i', .exclude_short = 'x' });

    const argv = [_][]const u8{ "--include", "users,logs", "--exclude", "logs" };
    var parsed = try ap.parse(&argv);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("users,logs", parsed.getString("include").?);
    try std.testing.expectEqualStrings("logs", parsed.getString("exclude").?);

    var resolved = try resolveIncludeExclude(allocator, &parsed, "include", "exclude");
    defer resolved.deinit();

    try std.testing.expectEqual(@as(usize, 2), resolved.include.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.exclude.len);
    try std.testing.expectEqualStrings("users", resolved.include[0]);
    try std.testing.expectEqualStrings("logs", resolved.include[1]);
    try std.testing.expectEqualStrings("logs", resolved.exclude[0]);
}

test "resolveIncludeExcludeStrict normalizes and dedupes values" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    try parsed.put("include", .{ .string = "users,gr,users" });
    try parsed.put("exclude", .{ .string = "logs,logs" });

    var resolved = try resolveIncludeExcludeStrict(allocator, &parsed, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
    });
    defer resolved.deinit();

    try std.testing.expect(!resolved.all);
    try std.testing.expectEqual(@as(usize, 2), resolved.include.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.exclude.len);
    try std.testing.expectEqualStrings("users", resolved.include[0]);
    try std.testing.expectEqualStrings("groups", resolved.include[1]);
    try std.testing.expectEqualStrings("logs", resolved.exclude[0]);
}

test "resolveIncludeExcludeStrict supports all keyword" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    try parsed.put("include", .{ .string = "all,users" });
    try parsed.put("exclude", .{ .string = "logs" });

    var resolved = try resolveIncludeExcludeStrict(allocator, &parsed, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .all_keyword = "all",
    });
    defer resolved.deinit();

    try std.testing.expect(resolved.all);
    try std.testing.expectEqual(@as(usize, 0), resolved.include.len);
    try std.testing.expectEqual(@as(usize, 1), resolved.exclude.len);
    try std.testing.expectEqualStrings("logs", resolved.exclude[0]);
}

test "resolveIncludeExcludeStrict reports conflicts" {
    const allocator = std.testing.allocator;

    var parsed = ParseResult.init(allocator);
    defer parsed.deinit();

    try parsed.put("include", .{ .string = "users" });
    try parsed.put("exclude", .{ .string = "users" });

    try std.testing.expectError(
        error.IncludeExcludeConflict,
        resolveIncludeExcludeStrict(allocator, &parsed, .{}),
    );
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

test "ArgumentParser expect strict" {
    const allocator = std.testing.allocator;
    config.initConfig(.{ .exit_on_error = false, .parsing_mode = .strict, .silent_errors = true });
    defer config.resetConfig();

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
    });
    defer ap.deinit();

    try ap.addOption("env", .{
        .short = 'e',
        .expect = &[_][]const u8{ "dev", "prod" },
    });

    // Valid
    {
        const args = [_][]const u8{ "-e", "dev" };
        var result = try ap.parse(&args);
        defer result.deinit();
        try std.testing.expectEqualStrings("dev", result.getString("env").?);
    }

    // Invalid (Strict -> Error)
    {
        const args = [_][]const u8{ "-e", "stage" };
        try std.testing.expectError(errors.ParseError.InvalidValue, ap.parse(&args));
    }
}

test "ArgumentParser expect warning" {
    const allocator = std.testing.allocator;
    config.initConfig(.{ .exit_on_error = false, .parsing_mode = .permissive, .silent_errors = true });
    defer config.resetConfig();

    var ap = try ArgumentParser.init(allocator, .{
        .name = "test",
    });
    defer ap.deinit();

    try ap.addOption("env", .{
        .short = 'e',
        .expect = &[_][]const u8{ "dev", "prod" },
    });

    // Valid
    {
        const args = [_][]const u8{ "-e", "dev" };
        var result = try ap.parse(&args);
        defer result.deinit();
        try std.testing.expectEqualStrings("dev", result.getString("env").?);
    }

    // Invalid (Permissive (default) -> Warning, but should still parse)
    {
        const args = [_][]const u8{ "-e", "stage" };
        var result = try ap.parse(&args);
        defer result.deinit();
        try std.testing.expectEqualStrings("stage", result.getString("env").?);
    }
}

test "derive alias for parseInto" {
    const allocator = std.testing.allocator;
    config.initConfig(Config.minimal());
    defer config.resetConfig();

    const TestConfig = struct {
        verbose: bool,
        count: i32,
    };

    const test_args = [_][]const u8{ "--verbose", "--count", "42" };
    var result = try derive(allocator, TestConfig, .{ .name = "test" }, &test_args);
    defer result.deinit();

    try std.testing.expect(result.options.verbose);
    try std.testing.expectEqual(@as(i32, 42), result.options.count);
}

test "createParser convenience" {
    const allocator = std.testing.allocator;
    config.initConfig(Config.minimal());
    defer config.resetConfig();

    var ap = try createParser(allocator, "myapp");
    defer ap.deinit();

    try std.testing.expectEqualStrings("myapp", ap.name);
}

test "createMinimalParser convenience" {
    const allocator = std.testing.allocator;

    var ap = try createMinimalParser(allocator, "minimal");
    defer ap.deinit();

    try std.testing.expectEqualStrings("minimal", ap.name);
    try std.testing.expect(!ap.cfg.use_colors);
    try std.testing.expect(!ap.cfg.check_for_updates);
}

test "version alias" {
    const ver = version();
    try std.testing.expectEqualStrings(VERSION, ver);
}

test "configure alias" {
    configure(.{ .use_colors = false, .check_for_updates = false });
    defer resetConfig();

    const cfg = config.getConfig();
    try std.testing.expect(!cfg.use_colors);
}
