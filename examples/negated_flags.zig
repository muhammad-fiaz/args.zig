const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "negated-flags",
        .description = "Demonstrates --no-flag support",
        .config = .{
            .exit_on_error = false,
            .allow_negated_flags = true,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addFlag("cache", .{ .help = "Enable cache" });

    // store_false pairs naturally with negated syntax:
    // --color sets false, --no-color sets true.
    try parser.addArg(.{
        .name = "color",
        .long = "color",
        .action = .store_false,
        .help = "Disable color output",
    });

    const argv = [_][]const u8{ "--no-cache", "--no-color" };

    var result = try parser.parse(&argv);
    defer result.deinit();

    std.debug.print("cache: {}\n", .{result.getBool("cache") orelse true});
    std.debug.print("color: {}\n", .{result.getBool("color") orelse false});
}
