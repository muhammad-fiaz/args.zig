//! Demonstration of character string length range validation and integer range validation
//! on both global options and subcommand arguments in args.zig.
//! Run with:
//!   zig build run-subcommand_range -- --username alice --port 8080
//!   zig build run-subcommand_range -- db --key api_token --size 500

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;

    // 1. Initialize global argument parser
    var ap = try args.ArgumentParser.init(allocator, .{
        .name = "subcommand-range-demo",
        .config = .{ .exit_on_error = false },
    });
    defer ap.deinit();

    ap.description = "Demonstrates character string length and integer range validation on global and subcommand inputs";

    // 2. Add global range options
    // Main option: username (character length between 3 and 12 chars)
    try ap.addCharRangeOption("username", .{
        .short = 'u',
        .min = 3,
        .max = 12,
        .help = "Username to associate with request (3..12 characters)",
    });

    // Main option: port (integer value in range 1024..65535)
    try ap.addRangeOption("port", i64, comptime .{
        .short = 'p',
        .min = 1024,
        .max = 65535,
        .default = "8080",
        .help = "Listening port (range: 1024..65535)",
    });

    // 3. Define subcommand db with its own range-validated option specs
    const db_args = [_]args.ArgSpec{
        .{
            .name = "key",
            .long = "key",
            .help = "Database key identifier (range: 4..16 chars)",
            .validator = args.Validators.charRange(4, 16),
            .required = true,
        },
        .{
            .name = "size",
            .long = "size",
            .help = "Storage pool size (range: 10..500)",
            .value_type = .int,
            .validator = args.Validators.intRange(10, 500),
            .default = "100",
        },
    };

    try ap.addSubcommand(.{
        .name = "db",
        .help = "Execute database storage pool configuration commands",
        .args = &db_args,
    });

    // 4. Parse the process arguments
    var result = ap.parseProcess(init) catch |err| {
        if (err == args.ParseError.MissingRequired) {
            try ap.printHelp();
            return;
        }
        std.debug.print("Input validation failed: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    // 5. Display successfully parsed inputs
    std.debug.print("Successfully validated inputs!\n", .{});

    if (result.getString("username")) |username| {
        std.debug.print("  - Global username: '{s}' (valid character length 3..12)\n", .{username});
    }

    const port_val = result.get("port").?.asInt().?;
    std.debug.print("  - Global port:     {d} (valid integer range 1024..65535)\n", .{port_val});

    // Check if subcommand was parsed
    if (result.subcommand) |sub| {
        std.debug.print("Executed subcommand: {s}\n", .{sub});
        if (result.subcommand_args) |sub_res| {
            const key = sub_res.getString("key").?;
            const size = sub_res.get("size").?.asInt().?;
            std.debug.print("  - Subcommand key:  '{s}' (valid character length 4..16)\n", .{key});
            std.debug.print("  - Subcommand size: {d} (valid integer range 10..500)\n", .{size});
        }
    }
}
