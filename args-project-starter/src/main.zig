const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "demo",
        .version = "1.0.0",
        .description = "Demo CLI app using args.zig",
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v', .help = "Verbose output" });
    try parser.addOption("name", .{ .short = 'n', .help = "Your name", .default = "World" });
    try parser.addPositional("file", .{ .help = "Input file to process", .required = true });

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const name = result.getString("name") orelse "World";
    const verbose = result.getBool("verbose") orelse false;
    const file = result.getString("file") orelse "?";

    if (verbose) {
        std.debug.print("Verbose mode enabled\n", .{});
    }
    std.debug.print("Hello, {s}! Processing file: {s}\n", .{ name, file });
}
