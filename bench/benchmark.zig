//! Comprehensive benchmarks for args.zig covering all features.

const std = @import("std");
const args = @import("args");
const builtin = @import("builtin");

/// Benchmark results structure
const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_time_ns: u64,
    ops_per_sec: f64,
    avg_latency_ns: f64,
    category: []const u8,

    // Static categories for grouping
    const categories = [_][]const u8{
        "Basic Parsing",
        "Advanced Features",
        "Generation",
    };
};

const ITERATIONS = 10_000;
const WARMUP = 100;

fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});
    std.debug.print("                                 ARGS.ZIG BENCHMARK RESULTS\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        std.debug.print("\n[{s}]\n", .{cat});
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});
        std.debug.print("{s:<40} {s:>25} {s:>25}\n", .{ "Benchmark", "Ops/sec", "Avg Latency (ns)" });
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<50} {d:>25.0} {d:>30.0}\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                });
            }
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("=" ** 130, .{});
    std.debug.print("\n", .{});
}

fn runBenchmark(
    name: []const u8,
    allocator: std.mem.Allocator,
    comptime benchFn: anytype,
    category: []const u8,
) !BenchmarkResult {
    // Warmup
    for (0..WARMUP) |_| {
        try benchFn(allocator);
    }

    // Benchmark
    var timer = try std.time.Timer.start();
    for (0..ITERATIONS) |_| {
        try benchFn(allocator);
    }
    const total_time_ns = timer.read();

    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0);
    const avg_latency_ns = @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    return BenchmarkResult{
        .name = name,
        .iterations = ITERATIONS,
        .total_time_ns = total_time_ns,
        .ops_per_sec = ops_per_sec,
        .avg_latency_ns = avg_latency_ns,
        .category = category,
    };
}

// -- Benchmark Functions --

fn benchmarkSimpleFlags(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-q", "--force" };
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

fn benchmarkMultipleOptions(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-o", "output.txt", "-n", "42", "--config", "app.conf" };
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

fn benchmarkPositionals(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "input.txt", "output.txt", "backup.txt" };
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

fn benchmarkCounters(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-v", "-v", "-d", "-d" };
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

fn benchmarkSubcommands(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "build", "--release", "--target", "native" };
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

fn benchmarkMixedArgs(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{
        "-v",       "-v",         "-v",        "--output=result.json",
        "-n",       "100",        "--format",  "json",
        "--config", "config.yml", "input.txt",
    };
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

fn benchmarkArgumentGroups(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--host", "localhost", "-p", "8080" };
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bench",
        .config = args.Config.minimal(),
    });
    try parser.addArgumentGroup("Network", .{ .description = "Network options" });
    try parser.addOption("host", .{});
    try parser.addOption("port", .{ .short = 'p' });
    parser.setGroup(null);
    var result = try parser.parse(&test_args);
    result.deinit();
    parser.deinit();
}

fn benchmarkHelpGeneration(allocator: std.mem.Allocator) !void {
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

fn benchmarkCompletionGeneration(allocator: std.mem.Allocator) !void {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    // Disable update checking for benchmarks
    args.initConfig(args.Config.minimal());

    // Basic Parsing
    try results.append(allocator, try runBenchmark("Simple Flags (3 flags)", allocator, benchmarkSimpleFlags, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Multiple Options (3 options)", allocator, benchmarkMultipleOptions, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Positional Arguments (3 positionals)", allocator, benchmarkPositionals, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Counters (-vvv -dd)", allocator, benchmarkCounters, "Basic Parsing"));

    // Advanced Features
    try results.append(allocator, try runBenchmark("Subcommands (2 subcommands)", allocator, benchmarkSubcommands, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Mixed Arguments (complex CLI)", allocator, benchmarkMixedArgs, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Argument Groups", allocator, benchmarkArgumentGroups, "Advanced Features"));

    // Generation
    try results.append(allocator, try runBenchmark("Help Text Generation", allocator, benchmarkHelpGeneration, "Generation"));
    try results.append(allocator, try runBenchmark("Shell Completion Generation (Bash)", allocator, benchmarkCompletionGeneration, "Generation"));

    // Print all results to console
    printResults(results.items);

    // Summary Statistics
    var total_ops: f64 = 0;
    var max_ops: f64 = 0;
    var min_ops: f64 = std.math.floatMax(f64);
    var count: usize = 0;
    var max_name: []const u8 = "";
    var min_name: []const u8 = "";

    for (results.items) |r| {
        total_ops += r.ops_per_sec;
        count += 1;
        if (r.ops_per_sec > max_ops) {
            max_ops = r.ops_per_sec;
            max_name = r.name;
        }
        if (r.ops_per_sec < min_ops) {
            min_ops = r.ops_per_sec;
            min_name = r.name;
        }
    }

    const avg_ops = if (count > 0) total_ops / @as(f64, @floatFromInt(count)) else 0;
    const avg_latency = if (avg_ops > 0) 1_000_000_000.0 / avg_ops else 0;

    // Write final Markdown report
    const md_file = std.fs.cwd().createFile("benchmark-results.md", .{}) catch |err| {
        std.debug.print("Warning: Could not create benchmark-results.md: {}\n", .{err});
        return;
    };
    defer md_file.close();

    const md_header =
        \\#### 📊 ARGS.ZIG BENCHMARK RESULTS
        \\
        \\**Environment Details:**
        \\- **Platform:** {s}
        \\- **Architecture:** {s}
        \\- **Warmup Iterations:** {d}
        \\- **Benchmark Iterations:** {d}
        \\
        \\
    ;

    var header_buf: [1024]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, md_header, .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        WARMUP,
        ITERATIONS,
    }) catch "";
    try md_file.writeAll(header);

    // Write categorized tables
    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        const cat_md = std.fmt.allocPrint(allocator,
            \\
            \\<details>
            \\<summary><strong>{s}</strong></summary>
            \\
            \\| Benchmark | Ops/sec (higher is better) | Avg Latency (ns) (lower is better) |
            \\| :--- | :--- | :--- |
            \\
        , .{cat}) catch continue;
        defer allocator.free(cat_md);
        try md_file.writeAll(cat_md);

        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d:.0} | {d:.0} |\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                }) catch continue;
                try md_file.writeAll(line);
            }
        }
        try md_file.writeAll("</details>\n");
    }

    if (count > 0) {
        try md_file.writeAll("\n### 📈 Benchmark Summary\n\n");
        var summary_buf: [1024]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf,
            \\- **Total benchmarks run:** {d}
            \\- **Average throughput:** {d:.0} ops/sec
            \\- **Maximum throughput:** {d:.0} ops/sec ({s})
            \\- **Minimum throughput:** {d:.0} ops/sec ({s})
            \\- **Average latency:** {d:.0} ns
            \\
        , .{ count, avg_ops, max_ops, max_name, min_ops, min_name, avg_latency }) catch "";
        try md_file.writeAll(summary);
    }

    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
}
