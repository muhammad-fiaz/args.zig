const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "file-support",
        .description = "File and extension support helpers",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addFileOptionWithExtensions("input", &[_][]const u8{ "json", "yaml", "toml" }, .{
        .short = 'i',
        .help = "Input config file",
        .must_exist = false,
    });

    try parser.addDirectoryOption("workspace", .{
        .short = 'w',
        .help = "Workspace directory",
        .must_exist = false,
    });

    const output_name_validator = args.Validators.filePolicy(&[_][]const u8{"json"}, false, 3, 64);

    try parser.addFileNameOption("output-name", .{
        .short = 'o',
        .help = "Output file name (must end with .json)",
        .validator = output_name_validator,
    });

    const argv = [_][]const u8{ "--input", "settings.json", "--workspace", "./", "--output-name", "result.json" };
    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    std.debug.print("input: {s}\n", .{parsed.getString("input") orelse "<missing>"});
    std.debug.print("workspace: {s}\n", .{parsed.getString("workspace") orelse "<missing>"});
    std.debug.print("output-name: {s}\n", .{parsed.getString("output-name") orelse "<missing>"});
}
