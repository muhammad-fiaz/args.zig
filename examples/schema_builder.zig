//! Example demonstrating SchemaBuilder for programmatic schema construction.
//! Build argument schemas dynamically at runtime.

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Use SchemaBuilder to construct a schema programmatically
    var schema = args.SchemaBuilder.init(allocator, "schema-example");
    defer schema.deinit();

    // Add arguments via the fluent API
    _ = try schema.addFlag("verbose", 'v', "Verbose output");
    _ = try schema.addOption("output", 'o', "Output file");
    _ = try schema.addOption("count", 'n', "Count");
    _ = try schema.addPositional("input", "Input file");

    // Build the CommandSpec from the schema
    const spec = schema.build();

    // Create a parser from the spec and add extras
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = spec.name,
        .description = spec.description,
    });
    defer parser.deinit();

    // Add the args from the built spec
    for (spec.args) |arg| {
        try parser.addArg(arg);
    }

    var result = try parser.parseProcess(init);
    defer result.deinit();

    const verbose = result.getBool("verbose") orelse false;
    const output = result.getString("output") orelse "out.txt";
    const count = result.getInt("count") orelse 1;
    const input = result.getString("input") orelse "stdin";

    if (verbose) {
        std.debug.print("[VERBOSE] Schema-built parser results:\n", .{});
    }
    std.debug.print("  Input:  {s}\n", .{input});
    std.debug.print("  Output: {s}\n", .{output});
    std.debug.print("  Count:  {d}\n", .{count});
}
