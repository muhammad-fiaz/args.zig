//! File format option example demonstrating addFormatOption, addExtensionOption.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "format-demo",
        .version = "1.0.0",
        .description = "Demonstrates file format and extension options",
    });
    defer parser.deinit();

    const known_formats = &[_][]const u8{ "json", "yaml", "toml", "csv" };

    try parser.addFormatOption("input-format", .{
        .short = 'f',
        .help = "Input file format",
        .default = "json",
        .formats = known_formats,
    });

    const known_extensions = &[_][]const u8{ ".json", ".yaml", ".toml", ".csv" };

    try parser.addExtensionOption("output-ext", .{
        .short = 'o',
        .help = "Output file extension",
        .default = ".json",
        .extensions = known_extensions,
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    const input_fmt = result.getString("input-format") orelse "json";
    const output_ext = result.getString("output-ext") orelse ".json";
    std.debug.print("Input format: {s}\nOutput ext:  {s}\n", .{ input_fmt, output_ext });
}
