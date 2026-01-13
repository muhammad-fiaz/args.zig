//! Help text generation for args.zig.

const std = @import("std");
const schema = @import("schema.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");
const Color = utils.Color;

pub const CommandSpec = schema.CommandSpec;
pub const ArgSpec = schema.ArgSpec;
pub const SubcommandSpec = schema.SubcommandSpec;

/// Generate help text for a command specification.
pub fn generateHelp(allocator: std.mem.Allocator, spec: CommandSpec, use_colors: bool) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    const reset = Color.get(Color.reset, use_colors);
    const bold = Color.get(Color.bold, use_colors);
    const dim = Color.get(Color.dim, use_colors);
    const yellow = Color.get(Color.yellow, use_colors);
    const green = Color.get(Color.green, use_colors);
    const cyan = Color.get(Color.cyan, use_colors);

    if (spec.description) |desc| {
        try writer.print("{s}{s}{s}\n\n", .{ bold, desc, reset });
    }

    try writer.print("{s}USAGE:{s}\n", .{ yellow, reset });
    try writer.print("    {s}{s}{s}", .{ bold, spec.name, reset });

    if (spec.args.len > 0) try writer.writeAll(" [OPTIONS]");

    for (spec.args) |arg| {
        if (arg.positional) {
            if (arg.required) {
                try writer.print(" <{s}>", .{arg.name});
            } else {
                try writer.print(" [{s}]", .{arg.name});
            }
        }
    }

    if (spec.subcommands.len > 0) try writer.writeAll(" <COMMAND>");
    try writer.writeAll("\n\n");

    if (spec.subcommands.len > 0) {
        try writer.print("{s}COMMANDS:{s}\n", .{ yellow, reset });
        for (spec.subcommands) |sub| {
            if (sub.hidden) continue;
            try writer.print("    {s}{s}{s}", .{ green, sub.name, reset });
            const padding = if (sub.name.len < 20) 20 - sub.name.len else 2;
            try writer.writeByteNTimes(' ', padding);
            if (sub.help) |h| try writer.print("{s}", .{h});
            try writer.writeAll("\n");
        }
        try writer.writeAll("\n");
    }

    var has_positionals = false;
    for (spec.args) |arg| {
        if (arg.positional and !arg.hidden) {
            has_positionals = true;
            break;
        }
    }

    if (has_positionals) {
        try writer.print("{s}ARGUMENTS:{s}\n", .{ yellow, reset });
        for (spec.args) |arg| {
            if (!arg.positional or arg.hidden) continue;
            try writer.print("    {s}<{s}>{s}", .{ cyan, arg.name, reset });
            const padding = if (arg.name.len + 2 < 20) 20 - arg.name.len - 2 else 2;
            try writer.writeByteNTimes(' ', padding);
            if (arg.help) |h| try writer.print("{s}", .{h});
            if (arg.required) try writer.print(" {s}[required]{s}", .{ dim, reset });
            try writer.writeAll("\n");
        }
        try writer.writeAll("\n");
    }

    var has_options = false;
    for (spec.args) |arg| {
        if (!arg.positional and !arg.hidden) {
            has_options = true;
            break;
        }
    }

    const cfg = config.getConfig();

    // 1. Grouped Options
    for (spec.groups) |group| {
        var has_group_options = false;
        for (spec.args) |arg| {
            if (arg.positional or arg.hidden) continue;
            if (arg.group) |gname| {
                if (utils.eql(gname, group.name)) {
                    has_group_options = true;
                    break;
                }
            }
        }

        if (has_group_options) {
            try writer.print("{s}{s}:{s}\n", .{ yellow, group.name, reset });
            if (group.description) |desc| {
                try writer.print("  {s}{s}\n\n", .{ dim, desc });
            }

            for (spec.args) |arg| {
                if (arg.positional or arg.hidden) continue;
                if (arg.group) |gname| {
                    if (utils.eql(gname, group.name)) {
                        try printOption(writer, arg, cfg, use_colors);
                    }
                }
            }
            try writer.writeAll("\n");
        }
    }

    // 2. Ungrouped Options
    var has_ungrouped = false;
    for (spec.args) |arg| {
        if (!arg.positional and !arg.hidden and arg.group == null) {
            has_ungrouped = true;
            break;
        }
    }

    if (has_ungrouped or spec.add_help or spec.add_version) {
        try writer.print("{s}OPTIONS:{s}\n", .{ yellow, reset });

        for (spec.args) |arg| {
            if (arg.positional or arg.hidden) continue;
            if (arg.group == null) {
                try printOption(writer, arg, cfg, use_colors);
            }
        }

        if (spec.add_help) {
            try writer.print("    {s}-h{s}, {s}--help{s}", .{ green, reset, green, reset });
            try writer.writeByteNTimes(' ', 12);
            try writer.print("Print help\n", .{});
        }

        if (spec.add_version and spec.version != null) {
            try writer.print("    {s}-V{s}, {s}--version{s}", .{ green, reset, green, reset });
            try writer.writeByteNTimes(' ', 9);
            try writer.print("Print version\n", .{});
        }
    }

    if (spec.epilog) |epilog| try writer.print("\n{s}\n", .{epilog});

    return result.toOwnedSlice(allocator);
}

fn printOption(writer: anytype, arg: ArgSpec, cfg: config.Config, use_colors: bool) !void {
    const reset = Color.get(Color.reset, use_colors);
    const green = Color.get(Color.green, use_colors);
    const dim = Color.get(Color.dim, use_colors);
    const yellow = Color.get(Color.yellow, use_colors);

    try writer.writeAll("    ");
    if (arg.short) |s| {
        try writer.print("{s}-{c}{s}", .{ green, s, reset });
        if (arg.long != null) try writer.writeAll(", ") else try writer.writeAll("  ");
    } else {
        try writer.writeAll("    ");
    }
    var opt_len: usize = 4;
    if (arg.long) |l| {
        try writer.print("{s}--{s}{s}", .{ green, l, reset });
        opt_len += l.len + 2;
    }
    if (!arg.isFlag()) {
        const metavar = arg.metavar orelse arg.value_type.typeName();
        try writer.print(" <{s}>", .{metavar});
        opt_len += metavar.len + 3;
    }
    const padding = if (opt_len < 24) 24 - opt_len else 2;
    try writer.writeByteNTimes(' ', padding);
    if (arg.help) |h| try writer.writeAll(h);

    if (arg.choices.len > 0) {
        try writer.print(" {s}[choices: ", .{dim});
        for (arg.choices, 0..) |choice, i| {
            try writer.print("{s}", .{choice});
            if (i < arg.choices.len - 1) try writer.writeAll(", ");
        }
        try writer.print("]{s}", .{reset});
    }

    if (cfg.show_defaults) {
        if (arg.default) |d| try writer.print(" {s}[default: {s}]{s}", .{ dim, d, reset });
    }
    if (cfg.show_env_vars) {
        if (arg.env_var) |e| try writer.print(" {s}[env: {s}]{s}", .{ dim, e, reset });
    }
    if (arg.deprecated) |dep| try writer.print(" {s}[DEPRECATED: {s}]{s}", .{ yellow, dep, reset });
    try writer.writeAll("\n");
}

/// Generate a short usage line.
pub fn generateUsage(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("Usage: {s}", .{spec.name});

    for (spec.args) |arg| {
        if (arg.positional) {
            if (arg.required) {
                try writer.print(" <{s}>", .{arg.name});
            } else {
                try writer.print(" [{s}]", .{arg.name});
            }
        }
    }

    if (spec.args.len > 0) try writer.writeAll(" [OPTIONS]");
    if (spec.subcommands.len > 0) try writer.writeAll(" <COMMAND>");

    return result.toOwnedSlice(allocator);
}

pub fn generateVersion(spec: CommandSpec) []const u8 {
    return spec.version orelse "unknown";
}

test "generateHelp basic" {
    const allocator = std.testing.allocator;

    const spec = CommandSpec{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A test application",
        .args = &[_]ArgSpec{
            .{ .name = "verbose", .short = 'v', .long = "verbose", .help = "Enable verbose", .action = .store_true },
            .{ .name = "input", .help = "Input file", .positional = true, .required = true },
        },
    };

    const help_text = try generateHelp(allocator, spec, false);
    defer allocator.free(help_text);

    try std.testing.expect(std.mem.indexOf(u8, help_text, "myapp") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "verbose") != null);
}

test "generateUsage" {
    const allocator = std.testing.allocator;

    const spec = CommandSpec{
        .name = "test",
        .args = &[_]ArgSpec{.{ .name = "file", .positional = true, .required = true }},
    };

    const usage = try generateUsage(allocator, spec);
    defer allocator.free(usage);

    try std.testing.expect(std.mem.indexOf(u8, usage, "test") != null);
}

test "generateVersion" {
    const spec1 = CommandSpec{ .name = "app", .version = "1.2.3" };
    try std.testing.expectEqualStrings("1.2.3", generateVersion(spec1));

    const spec2 = CommandSpec{ .name = "app" };
    try std.testing.expectEqualStrings("unknown", generateVersion(spec2));
}
