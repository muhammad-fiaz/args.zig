const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "decryption-options",
        .description = "Demonstrates automatic Base64 decryption/decoding for option values",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
        },
    });
    defer parser.deinit();

    try parser.addDecryptionOption("secret", .{
        .short = 's',
        .help = "Base64 encoded secret token",
        .required = true,
    });

    try parser.addDecryptionOption("session", .{
        .help = "URL-safe Base64 encoded session payload",
        .url_safe = true,
    });

    const argv = [_][]const u8{
        "--secret",  "c2VjcmV0LXRva2Vu",
        "--session", "c2Vzc2lvbi1kYXRh",
    };

    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    std.debug.print("secret: {s}\n", .{parsed.getString("secret") orelse "<missing>"});
    std.debug.print("session: {s}\n", .{parsed.getString("session") orelse "<missing>"});
}
