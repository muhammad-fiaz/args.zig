//! Export / introspection example demonstrating args.zig's export API.
//! Shows how to enumerate all registered arguments, subcommands, and groups
//! at runtime -- useful for documentation generators, client-side scaffolding,
//! protocol-level argument exchange, and CLI tooling.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "export-example",
        .version = "1.0.0",
        .description = "Demonstrates the export / introspection API",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    try parser.addOption("output", .{
        .short = 'o',
        .help = "Output file path",
        .default = "stdout",
    });

    try parser.addOption("port", .{
        .short = 'p',
        .help = "Listen port",
        .value_type = .int,
        .default = "8080",
    });

    try parser.addPositional("config", .{
        .help = "Path to configuration file",
        .required = true,
    });

    try parser.addArgumentGroup("Network", .{
        .description = "Connection-related options",
    });
    try parser.addOption("host", .{
        .short = 'H',
        .help = "Bind address",
    });

    try parser.addSubcommand(.{
        .name = "serve",
        .help = "Start the server",
    });
    try parser.addSubcommand(.{
        .name = "check",
        .help = "Validate configuration",
    });

    // Parse or show help
    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    // Export all registered arguments
    const all_args = parser.getAllArgs();
    std.debug.print("\n=== Registered Arguments ({d}) ===\n", .{all_args.len});
    for (all_args) |arg| {
        std.debug.print("  {s}", .{arg.name});
        if (arg.short) |s| {
            std.debug.print("  (-{c})", .{s});
        }
        std.debug.print("  [{s}]", .{arg.value_type.typeName()});
        if (arg.required) std.debug.print("  REQUIRED", .{});
        if (arg.default) |d| std.debug.print("  (default: {s})", .{d});
        if (arg.help) |h| std.debug.print("  -- {s}", .{h});
        std.debug.print("\n", .{});
    }

    // Export all subcommands
    const subs = parser.getAllSubcommands();
    std.debug.print("\n=== Subcommands ({d}) ===\n", .{subs.len});
    for (subs) |sub| {
        std.debug.print("  {s}", .{sub.name});
        if (sub.help) |h| std.debug.print("  -- {s}", .{h});
        std.debug.print("\n", .{});
    }

    // Export all groups
    const groups = parser.getAllGroups();
    std.debug.print("\n=== Argument Groups ({d}) ===\n", .{groups.len});
    for (groups) |group| {
        std.debug.print("  {s}", .{group.name});
        if (group.description) |d| std.debug.print("  -- {s}", .{d});
        std.debug.print("  (exclusive: {}, required: {})", .{ group.exclusive, group.required });
        std.debug.print("\n", .{});
    }

    // Full spec snapshot
    const spec = parser.exportSpec();
    std.debug.print("\n=== Full Spec Snapshot ===\n", .{});
    std.debug.print("  name:    {s}\n", .{spec.name});
    std.debug.print("  version: {s}\n", .{spec.version orelse "n/a"});
    std.debug.print("  args:    {d}\n", .{spec.args.len});
    std.debug.print("  subs:    {d}\n", .{spec.subcommands.len});

    // Look up a single argument
    if (parser.getArgSpec("port")) |port_spec| {
        std.debug.print("\n=== Lookup: 'port' ===\n", .{});
        std.debug.print("  name:      {s}\n", .{port_spec.name});
        std.debug.print("  type:      {s}\n", .{port_spec.value_type.typeName()});
        std.debug.print("  default:   {s}\n", .{port_spec.default orelse "none"});
        std.debug.print("  dest:      {s}\n", .{port_spec.getDestination()});
    }

    // Parsed values alongside the exported specs
    std.debug.print("\n=== Parsed Values ===\n", .{});
    std.debug.print("  verbose: {}\n", .{result.getBool("verbose") orelse false});
    std.debug.print("  output:  {s}\n", .{result.getString("output") orelse "stdout"});
    std.debug.print("  port:    {d}\n", .{result.getInt("port") orelse 8080});
    std.debug.print("  config:  {s}\n", .{result.getString("config") orelse "n/a"});

    if (result.hasSubcommand()) {
        std.debug.print("  sub:     {s}\n", .{result.subcommand.?});
    }
}
