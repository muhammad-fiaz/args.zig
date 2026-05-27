//! Help text generation for args.zig.

const std = @import("std");
const schema = @import("schema.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

pub const CommandSpec = schema.CommandSpec;
pub const ArgSpec = schema.ArgSpec;
pub const SubcommandSpec = schema.SubcommandSpec;

/// Generate help text for a command specification using global config.
pub fn generateHelp(allocator: std.mem.Allocator, spec: CommandSpec, use_colors: bool) ![]const u8 {
    return generateHelpWithConfig(allocator, spec, use_colors, config.getConfig());
}

/// Generate help text for a command specification using an explicit config.
pub fn generateHelpWithConfig(allocator: std.mem.Allocator, spec: CommandSpec, use_colors: bool, cfg: config.Config) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const writer = &aw.writer;

    const theme = utils.resolveTheme(use_colors, cfg.colors);
    const reset = theme.reset;
    const bold = theme.bold;
    const dim = theme.dim;
    const header = theme.header;
    const option = theme.option;
    const argument = theme.argument;
    const display_name = cfg.program_name orelse spec.name;

    if (spec.description) |desc| {
        try writer.print("{s}{s}{s}\n\n", .{ bold, desc, reset });
    }

    try writer.print("{s}{s}{s}\n", .{ header, constants.HelpText.usage, reset });
    try writer.print("    {s}{s}{s}", .{ bold, display_name, reset });

    if (spec.args.len > 0) try writer.writeAll(constants.HelpFormat.options_tag);

    for (spec.args) |arg| {
        if (arg.positional) {
            if (arg.hidden) continue;
            if (arg.required) {
                try writer.print(" <{s}>", .{arg.name});
            } else {
                try writer.print(" [{s}]", .{arg.name});
            }
        }
    }

    if (spec.subcommands.len > 0) try writer.writeAll(constants.HelpFormat.command_tag);
    try writer.writeAll("\n\n");

    if (spec.subcommands.len > 0) {
        try writer.print("{s}{s}{s}\n", .{ header, constants.HelpText.commands, reset });
        for (spec.subcommands) |sub| {
            if (sub.hidden) continue;
            try writer.print("    {s}{s}{s}", .{ option, sub.name, reset });
            const padding = if (sub.name.len < 20) 20 - sub.name.len else 2;
            for (0..padding) |_| try writer.writeByte(' ');
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
        try writer.print("{s}{s}{s}\n", .{ header, constants.HelpText.arguments, reset });
        for (spec.args) |arg| {
            if (!arg.positional or arg.hidden) continue;
            try writer.print("    {s}<{s}>{s}", .{ argument, arg.name, reset });
            const padding = if (arg.name.len + 2 < 20) 20 - arg.name.len - 2 else 2;
            for (0..padding) |_| try writer.writeByte(' ');
            if (arg.help) |h| try writer.print("{s}", .{h});
            if (arg.required) try writer.print(" {s}{s}{s}", .{ dim, constants.HelpFormat.required_annotation, reset });
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
            try writer.print("{s}{s}:{s}\n", .{ header, group.name, reset });
            if (group.description) |desc| {
                try writer.print("  {s}{s}\n\n", .{ dim, desc });
            }

            for (spec.args) |arg| {
                if (arg.positional or arg.hidden) continue;
                if (arg.group) |gname| {
                    if (utils.eql(gname, group.name)) {
                        try printOption(writer, arg, cfg, theme);
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
        try writer.print("{s}{s}{s}\n", .{ header, constants.HelpText.options, reset });

        for (spec.args) |arg| {
            if (arg.positional or arg.hidden) continue;
            if (arg.group == null) {
                try printOption(writer, arg, cfg, theme);
            }
        }

        if (spec.add_help) {
            try writer.print("    {s}-h{s}, {s}--help{s}", .{ option, reset, option, reset });
            for (0..12) |_| try writer.writeByte(' ');
            try writer.print("{s}\n", .{constants.HelpText.print_help});
        }

        if (spec.add_version and spec.version != null) {
            try writer.print("    {s}-V{s}, {s}--version{s}", .{ option, reset, option, reset });
            for (0..9) |_| try writer.writeByte(' ');
            try writer.print("{s}\n", .{constants.HelpText.print_version});
        }
    }

    if (cfg.app_author) |author| {
        try writer.print("\n{s}{s}:{s} {s}\n", .{ header, constants.HelpText.author, reset, author });
    }

    if (spec.epilog) |epilog| try writer.print("\n{s}\n", .{epilog});

    return aw.toOwnedSlice();
}

fn printOption(writer: anytype, arg: ArgSpec, cfg: config.Config, theme: utils.ColorTheme) !void {
    const reset = theme.reset;
    const option = theme.option;
    const dim = theme.meta;
    const header = theme.section;

    try writer.writeAll("    ");
    if (arg.short) |s| {
        try writer.print("{s}-{c}{s}", .{ option, s, reset });
        if (arg.long != null) try writer.writeAll(", ") else try writer.writeAll("  ");
    } else {
        try writer.writeAll("    ");
    }
    var opt_len: usize = 4;
    if (arg.long) |l| {
        try writer.print("{s}--{s}{s}", .{ option, l, reset });
        opt_len += l.len + 2;
    }
    if (!arg.isFlag()) {
        const metavar = arg.metavar orelse arg.value_type.typeName();
        try writer.print(" <{s}>", .{metavar});
        opt_len += metavar.len + 3;
    }
    const indent_width = if (cfg.help_indent >= 4) cfg.help_indent else 4;
    const padding = if (opt_len < indent_width) indent_width - opt_len else 2;
    for (0..padding) |_| try writer.writeByte(' ');

    var current_col = 4 + opt_len + padding;
    if (arg.help) |h| {
        if (cfg.help_line_width > 0 and current_col + h.len > cfg.help_line_width and cfg.help_indent > 0) {
            try writer.writeAll("\n");
            for (0..cfg.help_indent) |_| try writer.writeByte(' ');
            current_col = cfg.help_indent;
        }
        try writer.writeAll(h);
        current_col += h.len;
    }

    if (arg.choices.len > 0) {
        try writer.print(" {s}{s}", .{ dim, constants.HelpFormat.choices_format });
        current_col += 10;
        for (arg.choices, 0..) |choice, i| {
            try writer.print("{s}", .{choice});
            current_col += choice.len;
            if (i < arg.choices.len - 1) try writer.writeAll(", ");
            if (i < arg.choices.len - 1) current_col += 2;
        }
        try writer.print("{s}{s}", .{ constants.HelpFormat.choices_close, reset });
        current_col += 1;
    }

    if (cfg.show_defaults) {
        if (arg.default) |d| {
            const meta_len = 11 + d.len;
            if (cfg.help_line_width > 0 and current_col + meta_len > cfg.help_line_width and cfg.help_indent > 0) {
                try writer.writeAll("\n");
                for (0..cfg.help_indent) |_| try writer.writeByte(' ');
                current_col = cfg.help_indent;
            }
            try writer.print(" {s}{s}{s}{s}", .{ dim, constants.HelpFormat.default_label, d, constants.HelpFormat.close_bracket });
            current_col += meta_len;
        }
    }
    if (cfg.show_env_vars) {
        if (arg.env_var) |e| {
            const meta_len = 7 + e.len;
            if (cfg.help_line_width > 0 and current_col + meta_len > cfg.help_line_width and cfg.help_indent > 0) {
                try writer.writeAll("\n");
                for (0..cfg.help_indent) |_| try writer.writeByte(' ');
                current_col = cfg.help_indent;
            }
            try writer.print(" {s}{s}{s}{s}", .{ dim, constants.HelpFormat.env_label, e, constants.HelpFormat.close_bracket });
            current_col += meta_len;
        }
    }
    if (cfg.allow_negated_flags and arg.long != null and (arg.action == .store_true or arg.action == .store_false)) {
        const negate = arg.long.?;
        const meta_len = 14 + negate.len;
        if (cfg.help_line_width > 0 and current_col + meta_len > cfg.help_line_width and cfg.help_indent > 0) {
            try writer.writeAll("\n");
            for (0..cfg.help_indent) |_| try writer.writeByte(' ');
            current_col = cfg.help_indent;
        }
        try writer.print(" {s}{s}{s}{s}{s}", .{ dim, constants.HelpFormat.negate_label, negate, constants.HelpFormat.close_bracket, reset });
        current_col += meta_len;
    }
    if (arg.deprecated) |dep| {
        const meta_len = 14 + dep.len;
        if (cfg.help_line_width > 0 and current_col + meta_len > cfg.help_line_width and cfg.help_indent > 0) {
            try writer.writeAll("\n");
            for (0..cfg.help_indent) |_| try writer.writeByte(' ');
        }
        try writer.print(" {s}[{s}: {s}]{s}", .{ header, constants.HelpText.deprecated, dep, reset });
    }
    try writer.writeAll("\n");
}

/// Generate a short usage line.
pub fn generateUsage(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const writer = &aw.writer;

    try writer.print(constants.HelpFormat.usage_format, .{spec.name});

    for (spec.args) |arg| {
        if (arg.positional) {
            if (arg.hidden) continue;
            if (arg.required) {
                try writer.print(" <{s}>", .{arg.name});
            } else {
                try writer.print(" [{s}]", .{arg.name});
            }
        }
    }

    if (spec.args.len > 0) try writer.writeAll(constants.HelpFormat.options_tag);
    if (spec.subcommands.len > 0) try writer.writeAll(constants.HelpFormat.command_tag);

    return aw.toOwnedSlice();
}

pub fn generateVersion(spec: CommandSpec) []const u8 {
    return spec.version orelse constants.Defaults.unknown_version;
}

test "generateHelp basic" {
    const allocator = std.testing.allocator;
    config.initConfig(config.Config.default());
    defer config.resetConfig();

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
    config.initConfig(config.Config.default());
    defer config.resetConfig();

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

test "generateHelp uses program_name and app_author from config" {
    const allocator = std.testing.allocator;

    const spec = CommandSpec{
        .name = "internal",
        .description = "A configured help demo",
        .args = &[_]ArgSpec{.{ .name = "verbose", .long = "verbose", .action = .store_true }},
    };

    const cfg = config.Config{
        .program_name = "my-cli",
        .app_author = "Args Maintainers",
    };

    const help_text = try generateHelpWithConfig(allocator, spec, false, cfg);
    defer allocator.free(help_text);

    try std.testing.expect(std.mem.indexOf(u8, help_text, "my-cli") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Author:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Args Maintainers") != null);
}

test "printOption honors help_indent and line width wrapping" {
    const allocator = std.testing.allocator;

    const spec = CommandSpec{
        .name = "wrap-test",
        .args = &[_]ArgSpec{.{
            .name = "long",
            .long = "really-long-option-name",
            .help = "This is a long help sentence that should wrap when line width is restricted.",
        }},
    };

    const cfg = config.Config{
        .help_indent = 12,
        .help_line_width = 40,
    };

    const help_text = try generateHelpWithConfig(allocator, spec, false, cfg);
    defer allocator.free(help_text);

    try std.testing.expect(std.mem.indexOf(u8, help_text, "\n            This is a long help") != null);
}
