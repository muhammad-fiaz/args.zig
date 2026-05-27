//! Bracketed list example demonstrating addBracketedListOption.
//! Parses inline bracket-delimited values: {a,b,c}, [a,b,c], <a,b,c>

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bracketed-list",
        .version = "1.0.0",
        .description = "Demonstrates bracket-delimited value parsing",
    });
    defer parser.deinit();

    try parser.addBracketedListOption("tags", .{
        .short = 't',
        .help = "Tags (e.g. {a,b,c} or [x,y,z] or <p,q,r>)",
    });

    try parser.addBracketedListOption("files", .{
        .short = 'f',
        .help = "Files (supports all bracket types)",
    });

    var result = parser.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try parser.printHelp();
            return;
        }
        return err;
    };
    defer result.deinit();

    if (result.getArray("tags")) |tags| {
        std.debug.print("Tags ({d}):\n", .{tags.len});
        for (tags, 0..) |tag, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, tag });
        }
    }

    if (result.getArray("files")) |files| {
        std.debug.print("Files ({d}):\n", .{files.len});
        for (files, 0..) |f, i| {
            std.debug.print("  [{d}] {s}\n", .{ i, f });
        }
    }
}
