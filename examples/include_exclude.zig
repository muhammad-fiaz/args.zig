const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "include-exclude",
        .description = "CMD-style include/exclude filters",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addIncludeExclude(.{
        .include_short = 'i',
        .exclude_short = 'x',
    });

    const argv = [_][]const u8{ "--include", "users,groups,logs", "--exclude", "logs" };
    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    var resolved = try args.resolveIncludeExclude(allocator, &parsed, "include", "exclude");
    defer resolved.deinit();

    std.debug.print("include:\n", .{});
    for (resolved.include) |item| {
        std.debug.print("  + {s}\n", .{item});
    }

    std.debug.print("exclude:\n", .{});
    for (resolved.exclude) |item| {
        std.debug.print("  - {s}\n", .{item});
    }
}
