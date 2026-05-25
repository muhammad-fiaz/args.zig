const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "select-all",
        .description = "CMD-style --select/--all CSV feature demo",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addSelectOrAllCsv(.{
        .select_short = 's',
        .all_short = 'a',
        .select_help = "Select one or more target types",
        .all_help = "Select all target types",
    });

    const argv = [_][]const u8{ "--select", "users,gr,users" };
    var result = try parser.parse(&argv);
    defer result.deinit();

    var resolved = try args.resolveSelectOrAllStrict(allocator, &result, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .allow_prefix_match = true,
        .dedupe = true,
    });
    defer resolved.deinit();

    std.debug.print("all: {}\n", .{resolved.all});
    std.debug.print("select raw: {s}\n", .{result.getString("select") orelse "<none>"});
    std.debug.print("select parsed:\n", .{});
    for (resolved.selected) |item| {
        std.debug.print("  - {s}\n", .{item});
    }
}
