const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "question-flow",
        .description = "Interactive select/all flow for CMD-style tools",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addSelectOrAll(.{
        .select_short = 's',
        .all_short = 'a',
        .select_choices = &[_][]const u8{ "users", "groups", "logs" },
    });

    // Provide one direct arg to keep the example runnable in non-interactive CI.
    // Remove argv and call parseProcess(init) for fully interactive usage.
    const argv = [_][]const u8{ "--select", "users" };
    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    const decision = try args.resolveSelectOrAllWithPrompt(&parsed, .{
        .question = "Select target to process",
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .default_choice = "users",
        .allow_all = true,
        .max_attempts = 3,
    }, init.io);

    switch (decision) {
        .all => std.debug.print("Decision: all\n", .{}),
        .selected => |name| std.debug.print("Decision: {s}\n", .{name}),
    }
}
