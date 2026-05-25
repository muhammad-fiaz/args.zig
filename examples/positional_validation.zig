const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "positional-validation",
        .description = "Demonstrates positional choices and inverse flags",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addPositional("mode", .{
        .help = "Build mode",
        .choices = &[_][]const u8{ "dev", "prod", "test" },
    });

    // Explicit inverse flag helper: --color stores false.
    try parser.addFalseFlag("color", .{
        .help = "Disable color output",
    });

    const argv = [_][]const u8{ "prod", "--color" };

    var result = try parser.parse(&argv);
    defer result.deinit();

    std.debug.print("mode: {s}\n", .{result.getString("mode") orelse "<missing>"});
    std.debug.print("color: {}\n", .{result.getBool("color") orelse true});
}
