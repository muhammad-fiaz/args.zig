const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "include-exclude-strict",
        .description = "Strict include/exclude normalization and validation",
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

    const argv = [_][]const u8{ "--include", "all,users", "--exclude", "logs" };
    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    var resolved = try args.resolveIncludeExcludeStrict(allocator, &parsed, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .all_keyword = "all",
    });
    defer resolved.deinit();

    std.debug.print("all: {}\n", .{resolved.all});

    std.debug.print("include:\n", .{});
    for (resolved.include) |item| {
        std.debug.print("  + {s}\n", .{item});
    }

    std.debug.print("exclude:\n", .{});
    for (resolved.exclude) |item| {
        std.debug.print("  - {s}\n", .{item});
    }
}
