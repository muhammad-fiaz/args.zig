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
        "Workflow Helpers",
        "Validation",
        "Generation",
        "Export",
        "Additional",
    };
};

const ITERATIONS = 10_000;
const WARMUP = 100;

var bench_io: std.Io = undefined;
const use_colors = !builtin.is_test;

fn printResults(results: []const BenchmarkResult) void {
    const theme = args.utils.resolveTheme(use_colors, args.Config.colorful().colors);
    const reset = theme.reset;
    const header = theme.header;
    const section = theme.section;
    const accent = theme.accent;

    const sep = "----------------------------------------------------------------------------------------------------";

    std.debug.print("\n", .{});
    std.debug.print("{s}{s}{s}", .{ header, sep, reset });
    std.debug.print("\n", .{});
    std.debug.print("{s}                                 ARGS.ZIG BENCHMARK RESULTS{s}\n", .{ accent, reset });
    std.debug.print("{s}{s}{s}", .{ header, sep, reset });
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

        std.debug.print("\n{s}[{s}]{s}\n", .{ section, cat, reset });
        std.debug.print("{s}{s}{s}", .{ header, sep, reset });
        std.debug.print("\n", .{});
        std.debug.print("{s}{s:<40} {s:>25} {s:>25}{s}\n", .{ accent, "Benchmark", "Ops/sec", "Avg Latency (ns)", reset });
        std.debug.print("{s}{s}{s}", .{ header, sep, reset });
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

    const sep_long = "------------------------------------------------------------------------------------------------------------------------------------";

    std.debug.print("\n", .{});
    std.debug.print("{s}{s}{s}", .{ header, sep_long, reset });
    std.debug.print("\n", .{});
}

fn runBenchmark(
    name: []const u8,
    allocator: std.mem.Allocator,
    io: std.Io,
    comptime benchFn: anytype,
    category: []const u8,
) !BenchmarkResult {
    // Warmup
    for (0..WARMUP) |_| {
        try benchFn(allocator);
    }

    // Benchmark
    const bench_start = std.Io.Timestamp.now(io, .boot);
    for (0..ITERATIONS) |_| {
        try benchFn(allocator);
    }
    const bench_end = std.Io.Timestamp.now(io, .boot);
    const total_time_ns = @as(u64, @intCast(bench_end.nanoseconds - bench_start.nanoseconds));

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

fn initBenchParser(allocator: std.mem.Allocator, name: []const u8) !args.ArgumentParser {
    return args.ArgumentParser.init(allocator, .{
        .name = name,
        .config = args.Config.minimal(),
    });
}

fn parseAndCleanup(parser: *args.ArgumentParser, argv: []const []const u8) !void {
    var result = try parser.parse(argv);
    result.deinit();
}

// -- Benchmark Functions --

fn benchmarkSimpleFlags(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-q", "--force" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addFlag("quiet", .{ .short = 'q' });
    try parser.addFlag("force", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkMultipleOptions(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-o", "output.txt", "-n", "42", "--config", "app.conf" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addOption("output", .{ .short = 'o' });
    try parser.addOption("number", .{ .short = 'n', .value_type = .int });
    try parser.addOption("config", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkPositionals(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "input.txt", "output.txt", "backup.txt" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addPositional("source", .{});
    try parser.addPositional("dest", .{});
    try parser.addPositional("backup", .{ .required = false });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkCounters(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-v", "-v", "-d", "-d" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addCounter("verbose", .{ .short = 'v' });
    try parser.addCounter("debug", .{ .short = 'd' });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkSubcommands(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "build", "--release", "--target", "native" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
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
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkMixedArgs(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{
        "-v",       "-v",         "-v",        "--output=result.json",
        "-n",       "100",        "--format",  "json",
        "--config", "config.yml", "input.txt",
    };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addCounter("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o' });
    try parser.addOption("number", .{ .short = 'n', .value_type = .int });
    try parser.addOption("format", .{ .short = 'f' });
    try parser.addOption("config", .{ .short = 'c' });
    try parser.addPositional("input", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkArgumentGroups(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--host", "localhost", "-p", "8080" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addArgumentGroup("Network", .{ .description = "Network options" });
    try parser.addOption("host", .{});
    try parser.addOption("port", .{ .short = 'p' });
    parser.setGroup(null);
    try parseAndCleanup(&parser, &test_args);
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

fn benchmarkCompletionGenerationZsh(allocator: std.mem.Allocator) !void {
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "myapp",
        .version = "1.0.0",
        .config = args.Config.minimal(),
    });
    try parser.addFlag("verbose", .{ .short = 'v', .help = "Enable verbose output" });
    try parser.addOption("output", .{ .short = 'o', .help = "Output file" });
    const completion = try parser.generateCompletion(.zsh);
    allocator.free(completion);
    parser.deinit();
}

fn benchmarkCallbacks(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-v", "-v", "--output", "file.txt" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addArg(.{ .name = "verbose", .short = 'v', .action = .callback_flag, .callback = struct {
        fn cb(_: []const u8, _: ?[]const u8) void {}
    }.cb });

    try parser.addArg(.{ .name = "output", .long = "output", .action = .callback, .callback = struct {
        fn cb(_: []const u8, _: ?[]const u8) void {}
    }.cb });

    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkExpectValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "-e", "prod" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();
    try parser.addOption("env", .{
        .short = 'e',
        .expect = &[_][]const u8{ "dev", "prod", "stage" },
    });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkFileExtensionValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--input", "settings.json" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFileOptionWithExtensions("input", &[_][]const u8{ "json", "yaml", "toml" }, .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkFileNamePolicyValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--output-name", "result.json" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    const output_name_validator = args.Validators.filePolicy(&[_][]const u8{"json"}, false, 3, 64);
    try parser.addFileNameOption("output-name", .{ .validator = output_name_validator });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkTypedInputValidation(allocator: std.mem.Allocator) !void {
    const cwd_abs = try std.process.currentPathAlloc(bench_io, allocator);
    defer allocator.free(cwd_abs);

    const test_args = [_][]const u8{
        "--email",      "ops@example.com",
        "--endpoint",   "https://api.example.com/v1",
        "--host",       "10.0.0.8",
        "--host-any",   "fe80::1",
        "--host-v6",    "2001:db8::1",
        "--hostname",   "api.example.com",
        "--service",    "api.example.com:443",
        "--label",      "env=prod",
        "--request-id", "123e4567-e89b-12d3-a456-426614174000",
        "--run-date",   "2026-03-30",
        "--timestamp",  "2026-03-30T15:30:10Z",
        "--year",       "2026",
        "--time",       "15:30:10",
        "--port",       "8080",
        "--workspace",  cwd_abs,
        "--payload",    "{\"ok\":true}",
    };

    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addEmailOption("email", .{});
    try parser.addUrlOption("endpoint", .{});
    try parser.addIpv4Option("host", .{});
    try parser.addIpOption("host-any", .{});
    try parser.addIpv6Option("host-v6", .{});
    try parser.addHostNameOption("hostname", .{});
    try parser.addEndpointOption("service", .{});
    try parser.addKeyValueOption("label", .{});
    try parser.addUuidOption("request-id", .{});
    try parser.addIsoDateOption("run-date", .{});
    try parser.addIsoDateTimeOption("timestamp", .{});
    try parser.addYearOption("year", .{});
    try parser.addTimeOption("time", .{});
    try parser.addPortOption("port", .{});
    try parser.addAbsolutePathOption("workspace", .{});
    try parser.addJsonOption("payload", .{});

    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkDecryptionOption(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--secret", "c2VjcmV0LXRva2Vu" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addDecryptionOption("secret", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkSelectOrAllStrictCsv(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--select", "users,gr,users" };

    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addSelectOrAllCsv(.{});

    var parsed = try parser.parse(&test_args);
    defer parsed.deinit();

    var resolved = try args.resolveSelectOrAllStrict(allocator, &parsed, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .allow_prefix_match = true,
        .dedupe = true,
    });
    defer resolved.deinit();
}

fn benchmarkStructParsing(allocator: std.mem.Allocator) !void {
    const Config = struct {
        verbose: bool,
        output: ?[]const u8,
        count: i32,
    };
    const test_args = [_][]const u8{ "--count", "42", "--verbose", "--output", "file.txt" };

    var parsed = try args.parseInto(allocator, Config, .{
        .name = "bench",
        .config = args.Config.minimal(),
    }, &test_args, null);
    parsed.deinit();
}

fn benchmarkNegatedFlags(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--no-cache", "--color" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFlag("cache", .{});
    try parser.addFalseFlag("color", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkSelectOrAllHelpers(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--select", "users" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addSelectOrAll(.{
        .select_choices = &[_][]const u8{ "users", "groups", "logs" },
    });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkIncludeExcludeStrict(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--include", "users,groups", "--exclude", "logs" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addIncludeExclude(.{});

    var result = try parser.parse(&test_args);
    defer result.deinit();

    var filters = try args.resolveIncludeExcludeStrict(allocator, &result, .{
        .choices = &[_][]const u8{ "users", "groups", "logs" },
        .all_keyword = "all",
    });
    defer filters.deinit();
}

fn benchmarkPromptResolutionParsed(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const test_args = [_][]const u8{"--all"};
    var parser = try initBenchParser(std.heap.c_allocator, "bench");
    defer parser.deinit();

    try parser.addSelectOrAll(.{
        .select_choices = &[_][]const u8{ "users", "groups", "logs" },
    });

    var parsed = try parser.parse(&test_args);
    defer parsed.deinit();

    var input_reader: std.Io.Reader = .fixed("\n");
    var out_buf: [512]u8 = undefined;
    var output_writer: std.Io.Writer = .fixed(&out_buf);

    const decision = try args.resolveSelectOrAllWithPromptIO(
        &parsed,
        .{ .choices = &[_][]const u8{ "users", "groups", "logs" } },
        &input_reader,
        &output_writer,
    );
    _ = decision;
}

fn benchmarkSuggestionLookup(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const candidates = [_][]const u8{ "verbose", "version", "output", "config", "endpoint", "hostname", "service" };
    const sug = args.errors.findClosestMatch("endpont", &candidates, 3);
    _ = sug;
}

fn benchmarkSubcommandSuggestionLookup(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const candidates = [_][]const u8{ "init", "clone", "commit", "checkout", "status", "push", "pull" };
    const sug = args.errors.findClosestMatch("clnoe", &candidates, 3);
    _ = sug;
}

fn benchmarkExportArgs(allocator: std.mem.Allocator) !void {
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o' });
    try parser.addOption("port", .{ .short = 'p', .value_type = .int });
    try parser.addPositional("input", .{});
    try parser.addSubcommand(.{ .name = "serve", .help = "Start server" });

    _ = parser.getAllArgs();
    _ = parser.getAllSubcommands();
    _ = parser.getAllGroups();
    _ = parser.exportSpec();
    _ = parser.getArgSpec("port");
    _ = parser.totalArgCount();
    _ = parser.totalSubcommandCount();
    _ = parser.totalGroupCount();
}

fn benchmarkBracketedListParsing(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--tags", "{rust,zig,go}" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addBracketedListOption("tags", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkDurationParsing(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--timeout", "1h30m" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addDurationOption("timeout", .{ .short = 't' });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkSizeParsing(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--size", "1GB" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addSizeOption("size", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkParseOrFallback(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--unknown-flag" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });

    var result = parser.parseOr(&test_args, null);
    result.deinit();
}

fn benchmarkMutualExclusion(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--json" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFlag("json", .{});
    try parser.addFlag("text", .{});
    try parser.addFlag("csv", .{});
    try parser.addMutualExclusion(&[_][]const u8{ "json", "text", "csv" });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkRequiresRelation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--host", "localhost", "--port", "8080" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addOption("host", .{});
    try parser.addOption("port", .{ .short = 'p' });
    try parser.addRequires("port", "host");
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkRequiredIfRelation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--ssl", "--cert-file", "cert.pem" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFlag("ssl", .{});
    try parser.addOption("cert-file", .{});
    try parser.addRequiredIf("cert-file", "ssl", null);
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkCaseInsensitiveParsing(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--VERBOSE" };
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "bench",
        .config = .{
            .check_for_updates = false,
            .show_update_notification = false,
            .use_colors = false,
            .show_defaults = false,
            .show_env_vars = false,
            .exit_on_error = false,
            .silent_errors = true,
            .case_sensitive = false,
        },
    });
    defer parser.deinit();

    try parser.addFlag("verbose", .{ .short = 'v' });
    try parser.addOption("output", .{ .short = 'o' });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkSecretOption(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--api-key", "sk-1234567890abcdef" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addSecretOption("api-key", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkEnvOption(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--database-url", "postgres://localhost/db" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addEnvOption("database-url", .{});
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkRangeValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--port", "8080", "--ratio", "0.75" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addRangeOption("port", u16, .{ .short = 'p', .min = 1, .max = 65535 });
    try parser.addRangeOption("ratio", f64, .{ .min = 0.0, .max = 1.0 });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkCharRangeValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--username", "alice" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addCharRangeOption("username", .{ .min = 3, .max = 32 });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkFormatValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--output-format", "json" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addFormatOption("output-format", .{
        .formats = &[_][]const u8{ "json", "yaml", "toml", "csv" },
    });
    try parseAndCleanup(&parser, &test_args);
}

fn benchmarkExtensionValidation(allocator: std.mem.Allocator) !void {
    const test_args = [_][]const u8{ "--input", "config.yaml" };
    var parser = try initBenchParser(allocator, "bench");
    defer parser.deinit();

    try parser.addExtensionOption("input", .{
        .extensions = &[_][]const u8{ ".json", ".yaml", ".toml" },
    });
    try parseAndCleanup(&parser, &test_args);
}

pub fn main(init: std.process.Init) !void {
    bench_io = init.io;
    const allocator = init.gpa;

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    // Disable update checking for benchmarks
    args.initConfig(args.Config.minimal());

    // Basic Parsing
    try results.append(allocator, try runBenchmark("Simple Flags (3 flags)", allocator, bench_io, benchmarkSimpleFlags, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Multiple Options (3 options)", allocator, bench_io, benchmarkMultipleOptions, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Positional Arguments (3 positionals)", allocator, bench_io, benchmarkPositionals, "Basic Parsing"));
    try results.append(allocator, try runBenchmark("Counters (-vvv -dd)", allocator, bench_io, benchmarkCounters, "Basic Parsing"));

    // Advanced Features
    try results.append(allocator, try runBenchmark("Subcommands (2 subcommands)", allocator, bench_io, benchmarkSubcommands, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Mixed Arguments (complex CLI)", allocator, bench_io, benchmarkMixedArgs, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Argument Groups", allocator, bench_io, benchmarkArgumentGroups, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Callbacks", allocator, bench_io, benchmarkCallbacks, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Expect Validation", allocator, bench_io, benchmarkExpectValidation, "Advanced Features"));
    try results.append(allocator, try runBenchmark("Declarative Structs", allocator, bench_io, benchmarkStructParsing, "Advanced Features"));

    // Workflow Helpers
    try results.append(allocator, try runBenchmark("Negated Flags", allocator, bench_io, benchmarkNegatedFlags, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Select/All Helpers", allocator, bench_io, benchmarkSelectOrAllHelpers, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Select/All CSV Strict Resolve", allocator, bench_io, benchmarkSelectOrAllStrictCsv, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Include/Exclude Strict Resolve", allocator, bench_io, benchmarkIncludeExcludeStrict, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Prompt Resolution (Parsed)", allocator, bench_io, benchmarkPromptResolutionParsed, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Suggestion Lookup", allocator, bench_io, benchmarkSuggestionLookup, "Workflow Helpers"));
    try results.append(allocator, try runBenchmark("Subcommand Suggestion Lookup", allocator, bench_io, benchmarkSubcommandSuggestionLookup, "Workflow Helpers"));

    // Validation
    try results.append(allocator, try runBenchmark("File Extension Validation", allocator, bench_io, benchmarkFileExtensionValidation, "Validation"));
    try results.append(allocator, try runBenchmark("File Name Policy Validation", allocator, bench_io, benchmarkFileNamePolicyValidation, "Validation"));
    try results.append(allocator, try runBenchmark("Typed Input Validation", allocator, bench_io, benchmarkTypedInputValidation, "Validation"));
    try results.append(allocator, try runBenchmark("Decryption Option (Base64)", allocator, bench_io, benchmarkDecryptionOption, "Validation"));

    // Generation
    try results.append(allocator, try runBenchmark("Help Text Generation", allocator, bench_io, benchmarkHelpGeneration, "Generation"));
    try results.append(allocator, try runBenchmark("Shell Completion Generation (Bash)", allocator, bench_io, benchmarkCompletionGeneration, "Generation"));
    try results.append(allocator, try runBenchmark("Shell Completion Generation (Zsh)", allocator, bench_io, benchmarkCompletionGenerationZsh, "Generation"));

    // Export
    try results.append(allocator, try runBenchmark("Export / Introspection API", allocator, bench_io, benchmarkExportArgs, "Export"));

    // Additional
    try results.append(allocator, try runBenchmark("Bracketed List Parsing ({a,b,c})", allocator, bench_io, benchmarkBracketedListParsing, "Additional"));
    try results.append(allocator, try runBenchmark("Duration Parsing (1h30m)", allocator, bench_io, benchmarkDurationParsing, "Additional"));
    try results.append(allocator, try runBenchmark("Size Parsing (1GB)", allocator, bench_io, benchmarkSizeParsing, "Additional"));
    try results.append(allocator, try runBenchmark("ParseOr Fallback (invalid args)", allocator, bench_io, benchmarkParseOrFallback, "Additional"));
    try results.append(allocator, try runBenchmark("Mutual Exclusion", allocator, bench_io, benchmarkMutualExclusion, "Additional"));
    try results.append(allocator, try runBenchmark("Requires Relation", allocator, bench_io, benchmarkRequiresRelation, "Additional"));
    try results.append(allocator, try runBenchmark("Required-If Relation", allocator, bench_io, benchmarkRequiredIfRelation, "Additional"));
    try results.append(allocator, try runBenchmark("Case-Insensitive Parsing", allocator, bench_io, benchmarkCaseInsensitiveParsing, "Additional"));
    try results.append(allocator, try runBenchmark("Secret Option", allocator, bench_io, benchmarkSecretOption, "Additional"));
    try results.append(allocator, try runBenchmark("Env Option", allocator, bench_io, benchmarkEnvOption, "Additional"));
    try results.append(allocator, try runBenchmark("Range Validation (int + float)", allocator, bench_io, benchmarkRangeValidation, "Additional"));
    try results.append(allocator, try runBenchmark("Char-Range Validation", allocator, bench_io, benchmarkCharRangeValidation, "Additional"));
    try results.append(allocator, try runBenchmark("Format Validation", allocator, bench_io, benchmarkFormatValidation, "Additional"));
    try results.append(allocator, try runBenchmark("Extension Validation", allocator, bench_io, benchmarkExtensionValidation, "Additional"));

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
    const md_file = std.Io.Dir.createFileAbsolute(bench_io, "benchmark-results.md", .{}) catch |err| {
        std.debug.print("Warning: Could not create benchmark-results.md: {}\n", .{err});
        return;
    };
    defer md_file.close(bench_io);

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
    try md_file.writeStreamingAll(bench_io, header);

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
        try md_file.writeStreamingAll(bench_io, cat_md);

        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d:.0} | {d:.0} |\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                }) catch continue;
                try md_file.writeStreamingAll(bench_io, line);
            }
        }
        try md_file.writeStreamingAll(bench_io, "</details>\n");
    }

    if (count > 0) {
        try md_file.writeStreamingAll(bench_io, "\n### 📈 Benchmark Summary\n\n");
        var summary_buf: [1024]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf,
            \\- **Total benchmarks run:** {d}
            \\- **Average throughput:** {d:.0} ops/sec
            \\- **Maximum throughput:** {d:.0} ops/sec ({s})
            \\- **Minimum throughput:** {d:.0} ops/sec ({s})
            \\- **Average latency:** {d:.0} ns
            \\
        , .{ count, avg_ops, max_ops, max_name, min_ops, min_name, avg_latency }) catch "";
        try md_file.writeStreamingAll(bench_io, summary);
    }

    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
}
