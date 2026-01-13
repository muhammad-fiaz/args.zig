//! Shell completion generation for args.zig.

const std = @import("std");
const schema = @import("schema.zig");
const utils = @import("utils.zig");

pub const CommandSpec = schema.CommandSpec;
pub const ArgSpec = schema.ArgSpec;

/// Supported shell types for completion scripts.
pub const Shell = enum {
    bash,
    zsh,
    fish,
    powershell,
    nushell,

    pub fn fromString(s: []const u8) ?Shell {
        if (utils.eql(s, "bash")) return .bash;
        if (utils.eql(s, "zsh")) return .zsh;
        if (utils.eql(s, "fish")) return .fish;
        if (utils.eql(s, "powershell") or utils.eql(s, "pwsh")) return .powershell;
        if (utils.eql(s, "nushell") or utils.eql(s, "nu")) return .nushell;
        return null;
    }
};

/// Generate shell completion script.
pub fn generateCompletion(allocator: std.mem.Allocator, spec: CommandSpec, shell: Shell) ![]const u8 {
    return switch (shell) {
        .bash => generateBashCompletion(allocator, spec),
        .zsh => generateZshCompletion(allocator, spec),
        .fish => generateFishCompletion(allocator, spec),
        .powershell => generatePowershellCompletion(allocator, spec),
        .nushell => generateNushellCompletion(allocator, spec),
    };
}

fn generateBashCompletion(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("# Bash completion for {s}\n_{s}_completions() {{\n", .{ spec.name, spec.name });
    try writer.writeAll("    local cur=\"${COMP_WORDS[COMP_CWORD]}\"\n    local opts=\"");

    for (spec.args) |arg| {
        if (arg.hidden or arg.positional) continue;
        if (arg.short) |s| try writer.print("-{c} ", .{s});
        if (arg.long) |l| try writer.print("--{s} ", .{l});
    }
    try writer.writeAll("--help");
    if (spec.version != null) try writer.writeAll(" --version");
    try writer.writeAll("\"\n\n");

    if (spec.subcommands.len > 0) {
        try writer.writeAll("    local cmds=\"");
        for (spec.subcommands, 0..) |sub, i| {
            if (sub.hidden) continue;
            if (i > 0) try writer.writeAll(" ");
            try writer.writeAll(sub.name);
        }
        try writer.writeAll("\"\n");
    }

    try writer.writeAll("    if [[ ${cur} == -* ]]; then\n        COMPREPLY=($(compgen -W \"${opts}\" -- ${cur}))\n    else\n");
    if (spec.subcommands.len > 0) {
        try writer.writeAll("        COMPREPLY=($(compgen -W \"${cmds}\" -- ${cur}))\n");
    } else {
        try writer.writeAll("        COMPREPLY=($(compgen -f -- ${cur}))\n");
    }
    try writer.print("    fi\n}}\ncomplete -F _{s}_completions {s}\n", .{ spec.name, spec.name });

    return result.toOwnedSlice(allocator);
}

fn generateZshCompletion(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("#compdef {s}\n_{s}() {{\n    local -a opts args\n    opts=(\n", .{ spec.name, spec.name });

    for (spec.args) |arg| {
        if (arg.hidden or arg.positional) continue;
        if (arg.long) |l| {
            try writer.print("        '--{s}", .{l});
            if (arg.help) |h| try writer.print("[{s}]", .{h});
            try writer.writeAll("'\n");
        }
    }

    try writer.writeAll("        '--help[Print help]'\n");
    if (spec.version != null) try writer.writeAll("        '--version[Print version]'\n");
    try writer.print("    )\n    _arguments -s $opts\n}}\n_{s} \"$@\"\n", .{spec.name});

    return result.toOwnedSlice(allocator);
}

fn generateFishCompletion(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("# Fish completion for {s}\n\n", .{spec.name});

    for (spec.args) |arg| {
        if (arg.hidden or arg.positional) continue;
        try writer.print("complete -c {s}", .{spec.name});
        if (arg.short) |s| try writer.print(" -s {c}", .{s});
        if (arg.long) |l| try writer.print(" -l {s}", .{l});
        if (arg.help) |h| try writer.print(" -d '{s}'", .{h});
        try writer.writeAll("\n");
    }

    try writer.print("complete -c {s} -s h -l help -d 'Print help'\n", .{spec.name});
    if (spec.version != null) try writer.print("complete -c {s} -s V -l version -d 'Print version'\n", .{spec.name});

    for (spec.subcommands) |sub| {
        if (sub.hidden) continue;
        try writer.print("complete -c {s} -n '__fish_use_subcommand' -a {s}", .{ spec.name, sub.name });
        if (sub.help) |h| try writer.print(" -d '{s}'", .{h});
        try writer.writeAll("\n");
    }

    return result.toOwnedSlice(allocator);
}

fn generatePowershellCompletion(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("# PowerShell completion for {s}\nRegister-ArgumentCompleter -Native -CommandName {s} -ScriptBlock {{\n", .{ spec.name, spec.name });
    try writer.writeAll("    param($wordToComplete, $commandAst, $cursorPosition)\n    $completions = @(\n");

    for (spec.args) |arg| {
        if (arg.hidden or arg.positional) continue;
        if (arg.long) |l| {
            try writer.print("        [CompletionResult]::new('--{s}', '--{s}', 'ParameterName', '{s}')\n", .{ l, l, arg.help orelse l });
        }
    }

    try writer.writeAll("        [CompletionResult]::new('--help', '--help', 'ParameterName', 'Print help')\n");
    if (spec.version != null) {
        try writer.writeAll("        [CompletionResult]::new('--version', '--version', 'ParameterName', 'Print version')\n");
    }

    try writer.writeAll("    )\n    $completions | Where-Object { $_.CompletionText -like \"$wordToComplete*\" }\n}\n");

    return result.toOwnedSlice(allocator);
}

fn generateNushellCompletion(allocator: std.mem.Allocator, spec: CommandSpec) ![]const u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    const writer = result.writer(allocator);

    try writer.print("# Nushell completion for {s}\n\n", .{spec.name});
    try writer.print("extern \"{s}\" [\n", .{spec.name});

    for (spec.args) |arg| {
        if (arg.hidden or arg.positional) continue;

        try writer.writeAll("    ");
        if (arg.long) |l| {
            try writer.print("--{s}", .{l});
            if (arg.short) |s| try writer.print("(-{c})", .{s});
        } else if (arg.short) |s| {
            try writer.print("-{c}", .{s});
        }

        if (arg.value_type != .bool and arg.value_type != .counter) {
            const type_str = switch (arg.value_type) {
                .int, .uint, .counter => "int",
                .float => "number",
                .path => "path",
                else => "string",
            };
            try writer.print(": {s}", .{type_str});
        }

        if (arg.help) |h| try writer.print(" # {s}", .{h});
        try writer.writeAll("\n");
    }

    try writer.writeAll("    --help(-h) # Print help\n");
    if (spec.version != null) try writer.writeAll("    --version(-V) # Print version\n");

    try writer.writeAll("]\n");

    return result.toOwnedSlice(allocator);
}

test "Shell.fromString" {
    try std.testing.expectEqual(Shell.bash, Shell.fromString("bash").?);
    try std.testing.expectEqual(Shell.zsh, Shell.fromString("zsh").?);
    try std.testing.expectEqual(Shell.fish, Shell.fromString("fish").?);
    try std.testing.expectEqual(Shell.powershell, Shell.fromString("powershell").?);
    try std.testing.expectEqual(Shell.nushell, Shell.fromString("nushell").?);
    try std.testing.expectEqual(Shell.nushell, Shell.fromString("nu").?);
    try std.testing.expectEqual(@as(?Shell, null), Shell.fromString("unknown"));
}

test "generateBashCompletion" {
    const allocator = std.testing.allocator;
    const spec = CommandSpec{
        .name = "myapp",
        .args = &[_]ArgSpec{.{ .name = "verbose", .short = 'v', .long = "verbose", .action = .store_true }},
    };

    const completion = try generateCompletion(allocator, spec, .bash);
    defer allocator.free(completion);

    try std.testing.expect(std.mem.indexOf(u8, completion, "myapp") != null);
    try std.testing.expect(std.mem.indexOf(u8, completion, "--verbose") != null);
}

test "generateFishCompletion" {
    const allocator = std.testing.allocator;
    const spec = CommandSpec{
        .name = "test",
        .args = &[_]ArgSpec{.{ .name = "output", .short = 'o', .long = "output", .help = "Output file" }},
    };

    const completion = try generateCompletion(allocator, spec, .fish);
    defer allocator.free(completion);

    try std.testing.expect(std.mem.indexOf(u8, completion, "complete -c test") != null);
}
