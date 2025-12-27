//! Comprehensive benchmarks for args.zig covering all features.

const std = @import("std");
const args = @import("args");

const ITERATIONS = 10_000;
const WARMUP = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Disable update checking for benchmarks
    args.initConfig(args.Config.minimal());

    printHeader();

    try benchmarkSimpleFlags(allocator);
    try benchmarkMultipleOptions(allocator);
    try benchmarkPositionals(allocator);
    try benchmarkCounters(allocator);
    try benchmarkSubcommands(allocator);
    try benchmarkMixedArgs(allocator);
    try benchmarkHelpGeneration(allocator);
    try benchmarkCompletionGeneration(allocator);

    printFooter();
    printSummary();
}

fn printHeader() void {
    std.debug.print("\n", .{});
    std.debug.print("==================================================================\n", .{});
    std.debug.print("                    ARGS.ZIG BENCHMARKS                       \n", .{});
    std.debug.print("                      v{s}                                 \n", .{args.VERSION});
    std.debug.print("==================================================================\n", .{});
    std.debug.print("  Iterations: {d:>10}     Warmup: {d:>10}                \n", .{ ITERATIONS, WARMUP });
    std.debug.print("==================================================================\n", .{});
    std.debug.print("\n", .{});
}

fn printFooter() void {
    std.debug.print("==================================================================\n", .{});
    std.debug.print("                    BENCHMARK COMPLETE                        \n", .{});
    std.debug.print("==================================================================\n", .{});
}

fn printSummary() void {
    std.debug.print("\n", .{});
    std.debug.print("Platform: {s}-{s}\n", .{ @tagName(@import("builtin").os.tag), @tagName(@import("builtin").cpu.arch) });
    std.debug.print("Zig Version: {s}\n", .{@import("builtin").zig_version_string});
    std.debug.print("args.zig Version: {s}\n", .{args.VERSION});
    std.debug.print("\n", .{});
}

fn printBenchResult(name: []const u8, elapsed: u64) void {
    const avg_ns = elapsed / ITERATIONS;
    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(elapsed)) / 1_000_000_000.0);

    std.debug.print("-- {s} ", .{name});
    const padding = 60 - name.len;
    for (0..padding) |_| std.debug.print("-", .{});
    std.debug.print("\n", .{});
    std.debug.print("   Iterations:    {d:>10}\n", .{ITERATIONS});
    std.debug.print("   Total time:    {d:>10.2} ms\n", .{@as(f64, @floatFromInt(elapsed)) / 1_000_000.0});
    std.debug.print("   Avg per parse: {d:>10} ns\n", .{avg_ns});
    std.debug.print("   Throughput:    {d:>10.0} ops/sec\n", .{ops_per_sec});
    std.debug.print("------------------------------------------------------------------\n\n", .{});
}

fn benchmarkSimpleFlags(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-q", "--force" };

    // Warmup
    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v' });
        try parser.addFlag("quiet", .{ .short = 'q' });
        try parser.addFlag("force", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    // Benchmark
    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v' });
        try parser.addFlag("quiet", .{ .short = 'q' });
        try parser.addFlag("force", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Simple Flags (3 flags)", elapsed);
}

fn benchmarkMultipleOptions(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-o", "output.txt", "-n", "42", "--config", "app.conf" };

    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addOption("output", .{ .short = 'o' });
        try parser.addOption("number", .{ .short = 'n', .value_type = .int });
        try parser.addOption("config", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addOption("output", .{ .short = 'o' });
        try parser.addOption("number", .{ .short = 'n', .value_type = .int });
        try parser.addOption("config", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Multiple Options (3 options)", elapsed);
}

fn benchmarkPositionals(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "input.txt", "output.txt", "backup.txt" };

    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addPositional("source", .{});
        try parser.addPositional("dest", .{});
        try parser.addPositional("backup", .{ .required = false });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addPositional("source", .{});
        try parser.addPositional("dest", .{});
        try parser.addPositional("backup", .{ .required = false });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Positional Arguments (3 positionals)", elapsed);
}

fn benchmarkCounters(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-v", "-v", "-d", "-d" };

    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addCounter("verbose", .{ .short = 'v' });
        try parser.addCounter("debug", .{ .short = 'd' });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addCounter("verbose", .{ .short = 'v' });
        try parser.addCounter("debug", .{ .short = 'd' });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Counters (-vvv -dd)", elapsed);
}

fn benchmarkSubcommands(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "build", "--release", "--target", "native" };

    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addSubcommand(.{
            .name = "build",
            .help = "Build the project",
            .args = &[_]args.ArgSpec{
                .{ .name = "release", .long = "release", .action = .store_true },
                .{ .name = "target", .long = "target", .default = "native" },
            },
        });
        try parser.addSubcommand(.{
            .name = "test",
            .help = "Run tests",
        });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addSubcommand(.{
            .name = "build",
            .help = "Build the project",
            .args = &[_]args.ArgSpec{
                .{ .name = "release", .long = "release", .action = .store_true },
                .{ .name = "target", .long = "target", .default = "native" },
            },
        });
        try parser.addSubcommand(.{
            .name = "test",
            .help = "Run tests",
        });
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Subcommands (2 subcommands)", elapsed);
}

fn benchmarkMixedArgs(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{
        "-v",       "-v",         "-v",        "--output=result.json",
        "-n",       "100",        "--format",  "json",
        "--config", "config.yml", "input.txt",
    };

    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addCounter("verbose", .{ .short = 'v' });
        try parser.addOption("output", .{ .short = 'o' });
        try parser.addOption("number", .{ .short = 'n', .value_type = .int });
        try parser.addOption("format", .{ .short = 'f' });
        try parser.addOption("config", .{ .short = 'c' });
        try parser.addPositional("input", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "bench",
            .config = args.Config.minimal(),
        });
        try parser.addCounter("verbose", .{ .short = 'v' });
        try parser.addOption("output", .{ .short = 'o' });
        try parser.addOption("number", .{ .short = 'n', .value_type = .int });
        try parser.addOption("format", .{ .short = 'f' });
        try parser.addOption("config", .{ .short = 'c' });
        try parser.addPositional("input", .{});
        var result = try parser.parse(&test_args);
        result.deinit();
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Mixed Arguments (complex CLI)", elapsed);
}

fn benchmarkHelpGeneration(allocator: std.mem.Allocator) !void {
    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "myapp",
            .version = "1.0.0",
            .description = "A sample application with comprehensive help",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
        try parser.addFlag("quiet", .{ .short = 'q', .help = "Suppress output" });
        try parser.addOption("output", .{ .short = 'o', .help = "Output file path" });
        try parser.addOption("config", .{ .short = 'c', .help = "Configuration file" });
        try parser.addPositional("input", .{ .help = "Input file to process" });
        const help_text = try parser.getHelp();
        allocator.free(help_text);
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "myapp",
            .version = "1.0.0",
            .description = "A sample application with comprehensive help",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
        try parser.addFlag("quiet", .{ .short = 'q', .help = "Suppress output" });
        try parser.addOption("output", .{ .short = 'o', .help = "Output file path" });
        try parser.addOption("config", .{ .short = 'c', .help = "Configuration file" });
        try parser.addPositional("input", .{ .help = "Input file to process" });
        const help_text = try parser.getHelp();
        allocator.free(help_text);
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Help Text Generation", elapsed);
}

fn benchmarkCompletionGeneration(allocator: std.mem.Allocator) !void {
    for (0..WARMUP) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "myapp",
            .version = "1.0.0",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
        try parser.addOption("output", .{ .short = 'o', .help = "Output file" });
        const completion = try parser.generateCompletion(.bash);
        allocator.free(completion);
        parser.deinit();
    }

    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        var parser = try args.ArgumentParser.init(allocator, .{
            .name = "myapp",
            .version = "1.0.0",
            .config = args.Config.minimal(),
        });
        try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
        try parser.addOption("output", .{ .short = 'o', .help = "Output file" });
        const completion = try parser.generateCompletion(.bash);
        allocator.free(completion);
        parser.deinit();
    }
    const elapsed = timer.read();

    printBenchResult("Shell Completion Generation (Bash)", elapsed);
}
