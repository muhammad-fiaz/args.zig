//! Basic example demonstrating args.zig fundamentals.
//! Shows flags, options, positional arguments, and result handling.

const std = @import("std");
const args = @import("args");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create argument parser
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "basic-example",
        .version = "1.0.0",
        .description = "A basic example demonstrating args.zig features",
        .epilog = "For more information, visit https://github.com/muhammad-fiaz/args.zig",
    });
    defer parser.deinit();

    // Add a boolean flag
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    // Add a quiet flag
    try parser.addFlag("quiet", .{
        .short = 'q',
        .help = "Suppress all output",
    });

    // Add a string option with default
    try parser.addOption("output", .{
        .short = 'o',
        .help = "Output file path",
        .default = "output.txt",
    });

    // Add an integer option
    try parser.addOption("count", .{
        .short = 'n',
        .help = "Number of iterations",
        .value_type = .int,
        .default = "1",
    });

    // Add a float option
    try parser.addOption("rate", .{
        .short = 'r',
        .help = "Processing rate (0.0 to 1.0)",
        .value_type = .float,
        .default = "0.5",
    });

    // Add an option with choices
    try parser.addOption("format", .{
        .short = 'f',
        .help = "Output format",
        .choices = &[_][]const u8{ "json", "xml", "csv", "yaml" },
        .default = "json",
    });

    // Add a counter (verbosity level)
    try parser.addCounter("debug", .{
        .short = 'd',
        .help = "Increase debug level (can be repeated)",
    });

    // Add a positional argument
    try parser.addPositional("input", .{
        .help = "Input file to process",
        .required = true,
    });

    // Parse command line arguments
    var result = try parser.parseProcess();
    defer result.deinit();

    // Access parsed values
    const verbose = result.getBool("verbose") orelse false;
    const quiet = result.getBool("quiet") orelse false;
    const output = result.getString("output") orelse "output.txt";
    const count = result.getInt("count") orelse 1;
    const rate = result.getFloat("rate") orelse 0.5;
    const format = result.getString("format") orelse "json";
    const input = result.getString("input") orelse "unknown";

    // Get debug level from counter
    const debug_val = result.get("debug");
    const debug_level: u32 = if (debug_val) |val| val.counter else 0;

    // Display results
    if (!quiet) {
        std.debug.print("\n=== Basic Example Results ===\n", .{});
        std.debug.print("Input file:   {s}\n", .{input});
        std.debug.print("Output file:  {s}\n", .{output});
        std.debug.print("Format:       {s}\n", .{format});
        std.debug.print("Count:        {d}\n", .{count});
        std.debug.print("Rate:         {d:.2}\n", .{rate});
        std.debug.print("Verbose:      {}\n", .{verbose});
        std.debug.print("Debug level:  {d}\n", .{debug_level});

        if (verbose) {
            std.debug.print("\n[VERBOSE] Processing with detailed output...\n", .{});
        }

        if (debug_level > 0) {
            std.debug.print("[DEBUG] Debug level {d} enabled\n", .{debug_level});
        }
    }
}
