const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "error-handling",
        .description = "Shows duplicate handling, validation errors, and unknown option suggestions",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .suggest_closest = true,
            .suggestion_max_distance = 4,
            .error_prefix = "ParseError",
            .warning_prefix = "ParseWarning",
            .unknown_option_hint = "Try --help to list available options",
            .unknown_subcommand_hint = "Use one of the documented subcommands",
        },
    });
    defer parser.deinit();

    try parser.addEmailOption("email", .{ .short = 'e', .required = true });
    try parser.addPortOption("port", .{});
    try parser.addOption("format", .{
        .choices = &[_][]const u8{ "json", "yaml", "toml" },
        .suggestion_hint = "Allowed values: json, yaml, toml",
        .custom_error_message = "format must be one of json/yaml/toml",
    });
    try parser.addSubcommand(.{ .name = "init", .help = "Initialize" });
    try parser.addSubcommand(.{ .name = "check", .help = "Run checks" });

    const bad_duplicate = [_][]const u8{ "--email", "one@example.com", "--email", "two@example.com" };
    _ = parser.parse(&bad_duplicate) catch |err| {
        std.debug.print("duplicate example -> {s}\n", .{@errorName(err)});
        return;
    };

    const bad_validation = [_][]const u8{ "--email", "ok@example.com", "--port", "70000" };
    _ = parser.parse(&bad_validation) catch |err| {
        std.debug.print("validation example -> {s}\n", .{@errorName(err)});
        return;
    };

    const bad_choice = [_][]const u8{ "--email", "ok@example.com", "--format", "jsn" };
    _ = parser.parse(&bad_choice) catch |err| {
        std.debug.print("choice example -> {s}\n", .{@errorName(err)});
        return;
    };

    const unknown_option = [_][]const u8{ "--email", "ok@example.com", "--porrt", "443" };
    _ = parser.parse(&unknown_option) catch |err| {
        std.debug.print("unknown option example -> {s}\n", .{@errorName(err)});
        return;
    };

    const builtin_option_typo = [_][]const u8{ "--email", "ok@example.com", "--verison" };
    _ = parser.parse(&builtin_option_typo) catch |err| {
        std.debug.print("builtin option typo example -> {s}\n", .{@errorName(err)});
        return;
    };

    const unknown_subcommand = [_][]const u8{"chcek"};
    _ = parser.parse(&unknown_subcommand) catch |err| {
        std.debug.print("unknown subcommand example -> {s}\n", .{@errorName(err)});
        return;
    };
}
