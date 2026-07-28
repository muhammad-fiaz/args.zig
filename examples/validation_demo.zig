const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    var parser = try args.ArgumentParser.init(init.arena.allocator(), .{
        .name = "validation-demo",
        .description = "Demonstrates built-in validators",
        .config = .{ .exit_on_error = false },
    });
    defer parser.deinit();

    try parser.addOption("color", .{
        .help = "Hex color code (#RRGGBB)",
        .validator = args.Validators.hexColor,
    });

    try parser.addOption("version", .{
        .help = "Semantic version string",
        .validator = args.Validators.semver,
    });

    try parser.addOption("mac", .{
        .help = "MAC address (XX:XX:XX:XX:XX:XX)",
        .validator = args.Validators.macAddress,
    });

    try parser.addOption("base64-input", .{
        .help = "Base64-encoded string",
        .validator = args.Validators.base64,
    });

    try parser.addOption("mode", .{
        .help = "Mode (lowercase)",
        .validator = args.Validators.lowercase,
    });

    try parser.addOption("env", .{
        .help = "Environment (uppercase)",
        .validator = args.Validators.uppercase,
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    if (result.getString("color")) |c| std.debug.print("Color: {s}\n", .{c});
    if (result.getString("version")) |v| std.debug.print("Version: {s}\n", .{v});
    if (result.getString("mac")) |m| std.debug.print("MAC: {s}\n", .{m});
}
