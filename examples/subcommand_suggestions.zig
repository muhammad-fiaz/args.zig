const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;

    const argv = try init.minimal.args.toSlice(init.arena.allocator());

    if (argv.len > 1 and std.mem.eql(u8, argv[1], "--help")) {
        std.debug.print("Run this example without args to trigger an unknown-subcommand suggestion demo.\n", .{});
        return;
    }

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "subcommand-demo",
        .description = "Shows built-in closest-match suggestions for unknown subcommands",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .suggest_closest = true,
            .suggestion_max_distance = 3,
            .unknown_subcommand_hint = "Use one of: init, clone, commit",
        },
    });
    defer parser.deinit();

    try parser.addSubcommand(.{ .name = "init", .help = "Initialize a repository" });
    try parser.addSubcommand(.{ .name = "clone", .help = "Clone from remote" });
    try parser.addSubcommand(.{ .name = "commit", .help = "Record local changes" });

    const bad = [_][]const u8{"clnoe"};
    _ = parser.parse(&bad) catch |err| {
        switch (err) {
            error.UnknownSubcommand => std.debug.print("subcommand example -> {s}\n", .{args.errors.formatParseError(error.UnknownSubcommand)}),
            else => std.debug.print("subcommand example -> unexpected error: {any}\n", .{err}),
        }
        return;
    };
}
