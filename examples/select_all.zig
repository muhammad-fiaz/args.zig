const std = @import("std");
const args = @import("args");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "select-all",
        .description = "CMD-style --select/--all feature demo",
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
        .select_help = "Select one target type",
        .all_help = "Select all target types",
    });

    const argv = [_][]const u8{ "--select", "users" };
    var result = try parser.parse(&argv);
    defer result.deinit();

    const all_enabled = result.getBool("all") orelse false;
    const selected = result.getString("select") orelse "<none>";

    const selected_items = try args.parseCsvList(allocator, selected);
    defer args.deinitCsvList(allocator, selected_items);

    std.debug.print("all: {}\n", .{all_enabled});
    std.debug.print("select raw: {s}\n", .{selected});
    std.debug.print("select parsed:\n", .{});
    for (selected_items) |item| {
        std.debug.print("  - {s}\n", .{item});
    }
}
