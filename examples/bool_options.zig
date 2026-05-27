//! Demonstrates case-insensitive boolean parsing.
//! Values like TRUE/True/true, YES/Yes/yes, ON/On/on,
//! FALSE/False/false, NO/No/no, OFF/Off/off are all accepted.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bool-demo",
        .version = "1.0.0",
        .description = "Demonstrates case-insensitive boolean option parsing",
    });
    defer parser.deinit();

    try parser.addOption("enabled", .{
        .short = 'e',
        .help = "Enable feature (accepts: true/TRUE/True/yes/YES/on/ON/1)",
        .value_type = .bool,
        .default = "true",
    });

    try parser.addOption("debug", .{
        .short = 'd',
        .help = "Debug mode (accepts: false/FALSE/False/no/NO/off/OFF/0)",
        .value_type = .bool,
        .default = "false",
    });

    try parser.addFlag("flag", .{
        .short = 'f',
        .help = "Simple flag (no value needed)",
    });

    var result = parser.parseProcessOr(init, null);
    defer result.deinit();

    const enabled = result.getOrBool("enabled", true);
    const debug = result.getOrBool("debug", false);
    const flag = result.getBool("flag") orelse false;

    std.debug.print("enabled = {}  (type: bool)\n", .{enabled});
    std.debug.print("debug   = {}  (type: bool)\n", .{debug});
    std.debug.print("flag    = {}  (type: bool, store_true)\n", .{flag});
}
