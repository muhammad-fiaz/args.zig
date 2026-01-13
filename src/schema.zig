//! Argument schema definitions for args.zig.
//! Minimum Zig version: 0.15.1

const std = @import("std");
const types = @import("types.zig");
const validation = @import("validation.zig");

pub const ValueType = types.ValueType;
pub const ArgAction = types.ArgAction;
pub const Nargs = types.Nargs;
pub const ParsedValue = types.ParsedValue;

/// Specification for a single argument.
pub const ArgSpec = struct {
    name: []const u8,
    short: ?u8 = null,
    long: ?[]const u8 = null,
    aliases: []const []const u8 = &.{},
    help: ?[]const u8 = null,
    value_type: ValueType = .string,
    action: ArgAction = .store,
    nargs: Nargs = .{ .exact = 1 },
    required: bool = false,
    default: ?[]const u8 = null,
    choices: []const []const u8 = &.{},
    metavar: ?[]const u8 = null,
    dest: ?[]const u8 = null,
    env_var: ?[]const u8 = null,
    positional: bool = false,
    hidden: bool = false,
    group: ?[]const u8 = null,
    deprecated: ?[]const u8 = null,
    validator: ?validation.ValidatorFn = null,

    /// Get the destination name for storing the value.
    pub fn getDestination(self: *const ArgSpec) []const u8 {
        return self.dest orelse self.long orelse self.name;
    }

    /// Check if this argument is a flag (no value required).
    pub fn isFlag(self: *const ArgSpec) bool {
        return self.action == .store_true or self.action == .store_false or
            self.action == .count or self.action == .help or self.action == .version;
    }

    /// Check if this argument is optional.
    pub fn isOptional(self: *const ArgSpec) bool {
        return !self.required and self.default != null;
    }

    /// Get the metavar for help text.
    pub fn getMetavar(self: *const ArgSpec) []const u8 {
        return self.metavar orelse self.value_type.typeName();
    }

    /// Check if this argument has choices.
    pub fn hasChoices(self: *const ArgSpec) bool {
        return self.choices.len > 0;
    }
};

/// Specification for a subcommand.
pub const SubcommandSpec = struct {
    name: []const u8,
    help: ?[]const u8 = null,
    aliases: []const []const u8 = &.{},
    args: []const ArgSpec = &.{},
    subcommands: []const SubcommandSpec = &.{},
    hidden: bool = false,

    /// Check if the given name matches this subcommand.
    pub fn matches(self: *const SubcommandSpec, name: []const u8) bool {
        if (std.mem.eql(u8, self.name, name)) return true;
        for (self.aliases) |alias| {
            if (std.mem.eql(u8, alias, name)) return true;
        }
        return false;
    }
};

/// Specification for an argument group.
pub const ArgumentGroup = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    args: std.ArrayListUnmanaged(ArgSpec) = .empty,
    exclusive: bool = false,
    required: bool = false,

    pub fn deinit(self: *ArgumentGroup, allocator: std.mem.Allocator) void {
        self.args.deinit(allocator);
    }
};

/// Full command specification.
pub const CommandSpec = struct {
    name: []const u8,
    version: ?[]const u8 = null,
    description: ?[]const u8 = null,
    args: []const ArgSpec = &.{},
    groups: []const ArgumentGroup = &.{},
    subcommands: []const SubcommandSpec = &.{},
    epilog: ?[]const u8 = null,
    allow_interspersed: bool = true,
    add_help: bool = true,
    add_version: bool = true,

    /// Get required arguments count.
    pub fn requiredArgCount(self: *const CommandSpec) usize {
        var count: usize = 0;
        for (self.args) |arg| {
            if (arg.required) count += 1;
        }
        return count;
    }

    /// Get positional arguments.
    pub fn getPositionalArgs(self: *const CommandSpec) []const ArgSpec {
        return self.args; // Simplified
    }

    /// Check if command has subcommands.
    pub fn hasSubcommands(self: *const CommandSpec) bool {
        return self.subcommands.len > 0;
    }
};

/// Builder for creating argument schemas with fluent API.
pub const SchemaBuilder = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    version: ?[]const u8 = null,
    description: ?[]const u8 = null,
    args: std.ArrayListUnmanaged(ArgSpec),
    groups: std.ArrayListUnmanaged(ArgumentGroup),
    subcommands: std.ArrayListUnmanaged(SubcommandSpec),
    epilog: ?[]const u8 = null,
    add_help: bool = true,
    add_version: bool = true,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) SchemaBuilder {
        return .{
            .allocator = allocator,
            .name = name,
            .args = .empty,
            .groups = .empty,
            .subcommands = .empty,
        };
    }

    pub fn deinit(self: *SchemaBuilder) void {
        self.args.deinit(self.allocator);
        for (self.groups.items) |*g| g.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.subcommands.deinit(self.allocator);
    }

    pub fn setVersion(self: *SchemaBuilder, ver: []const u8) *SchemaBuilder {
        self.version = ver;
        return self;
    }

    pub fn setDescription(self: *SchemaBuilder, desc: []const u8) *SchemaBuilder {
        self.description = desc;
        return self;
    }

    pub fn setEpilog(self: *SchemaBuilder, ep: []const u8) *SchemaBuilder {
        self.epilog = ep;
        return self;
    }

    pub fn addArg(self: *SchemaBuilder, spec: ArgSpec) !*SchemaBuilder {
        try self.args.append(self.allocator, spec);
        return self;
    }

    pub fn addPositional(self: *SchemaBuilder, name: []const u8, help_text: ?[]const u8) !*SchemaBuilder {
        try self.args.append(self.allocator, .{
            .name = name,
            .help = help_text,
            .positional = true,
            .required = true,
        });
        return self;
    }

    pub fn addFlag(self: *SchemaBuilder, name: []const u8, short: ?u8, help_text: ?[]const u8) !*SchemaBuilder {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = short,
            .long = name,
            .help = help_text,
            .action = .store_true,
        });
        return self;
    }

    pub fn addOption(self: *SchemaBuilder, name: []const u8, short: ?u8, help_text: ?[]const u8) !*SchemaBuilder {
        try self.args.append(self.allocator, .{
            .name = name,
            .short = short,
            .long = name,
            .help = help_text,
        });
        return self;
    }

    pub fn addSubcommand(self: *SchemaBuilder, spec: SubcommandSpec) !*SchemaBuilder {
        try self.subcommands.append(self.allocator, spec);
        return self;
    }

    pub fn build(self: *SchemaBuilder) CommandSpec {
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
};

test "ArgSpec.getDestination" {
    const spec1 = ArgSpec{ .name = "verbose", .long = "verbose", .dest = "is_verbose" };
    try std.testing.expectEqualStrings("is_verbose", spec1.getDestination());

    const spec2 = ArgSpec{ .name = "output", .long = "output" };
    try std.testing.expectEqualStrings("output", spec2.getDestination());

    const spec3 = ArgSpec{ .name = "file", .positional = true };
    try std.testing.expectEqualStrings("file", spec3.getDestination());

    const spec4 = ArgSpec{ .name = "item", .aliases = &[_][]const u8{"i"} };
    try std.testing.expectEqualStrings("item", spec4.getDestination());
}

test "ArgSpec.isFlag" {
    const flag = ArgSpec{ .name = "verbose", .action = .store_true };
    try std.testing.expect(flag.isFlag());

    const option = ArgSpec{ .name = "output", .action = .store };
    try std.testing.expect(!option.isFlag());

    const counter = ArgSpec{ .name = "verbosity", .action = .count };
    try std.testing.expect(counter.isFlag());

    const help_action = ArgSpec{ .name = "help", .action = .help };
    try std.testing.expect(help_action.isFlag());
}

test "ArgSpec.isOptional" {
    const optional = ArgSpec{ .name = "config", .default = "config.yml" };
    try std.testing.expect(optional.isOptional());

    const required = ArgSpec{ .name = "input", .required = true };
    try std.testing.expect(!required.isOptional());
}

test "ArgSpec.getMetavar" {
    const with_metavar = ArgSpec{ .name = "file", .metavar = "FILE" };
    try std.testing.expectEqualStrings("FILE", with_metavar.getMetavar());

    const without_metavar = ArgSpec{ .name = "count", .value_type = .int };
    try std.testing.expectEqualStrings("INT", without_metavar.getMetavar());
}

test "ArgSpec.hasChoices" {
    const with_choices = ArgSpec{
        .name = "level",
        .choices = &[_][]const u8{ "debug", "info", "warn" },
    };
    try std.testing.expect(with_choices.hasChoices());

    const without_choices = ArgSpec{ .name = "output" };
    try std.testing.expect(!without_choices.hasChoices());
}

test "SubcommandSpec.matches" {
    const sub = SubcommandSpec{
        .name = "install",
        .aliases = &[_][]const u8{ "i", "add" },
    };

    try std.testing.expect(sub.matches("install"));
    try std.testing.expect(sub.matches("i"));
    try std.testing.expect(sub.matches("add"));
    try std.testing.expect(!sub.matches("remove"));
}

test "CommandSpec.hasSubcommands" {
    const with_subs = CommandSpec{
        .name = "git",
        .subcommands = &[_]SubcommandSpec{.{ .name = "clone" }},
    };
    try std.testing.expect(with_subs.hasSubcommands());

    const without_subs = CommandSpec{ .name = "simple" };
    try std.testing.expect(!without_subs.hasSubcommands());
}

test "SchemaBuilder basic usage" {
    const allocator = std.testing.allocator;

    var builder = SchemaBuilder.init(allocator, "myapp");
    defer builder.deinit();

    _ = builder.setVersion("1.0.0").setDescription("A test application");
    _ = try builder.addFlag("verbose", 'v', "Enable verbose output");
    _ = try builder.addOption("output", 'o', "Output file");
    _ = try builder.addPositional("input", "Input file");

    const spec = builder.build();

    try std.testing.expectEqualStrings("myapp", spec.name);
    try std.testing.expectEqualStrings("1.0.0", spec.version.?);
    try std.testing.expectEqual(@as(usize, 3), spec.args.len);
}

test "SchemaBuilder with subcommand" {
    const allocator = std.testing.allocator;

    var builder = SchemaBuilder.init(allocator, "cli");
    defer builder.deinit();

    _ = try builder.addSubcommand(.{
        .name = "init",
        .help = "Initialize project",
    });

    const spec = builder.build();
    try std.testing.expect(spec.hasSubcommands());
    try std.testing.expectEqual(@as(usize, 1), spec.subcommands.len);
}

test "SchemaBuilder with epilog" {
    const allocator = std.testing.allocator;

    var builder = SchemaBuilder.init(allocator, "app");
    defer builder.deinit();

    _ = builder.setEpilog("For more info, visit example.com");
    const spec = builder.build();

    try std.testing.expectEqualStrings("For more info, visit example.com", spec.epilog.?);
}
