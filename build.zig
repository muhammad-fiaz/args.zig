const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the args module
    const args_module = b.createModule(.{
        .root_source_file = b.path("src/args.zig"),
    });

    // Expose the module for external projects that depend on this package.
    _ = b.addModule("args", .{
        .root_source_file = b.path("src/args.zig"),
    });

    const examples = [_]struct { name: []const u8, path: []const u8, skip_run_all: bool = false }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "advanced", .path = "examples/advanced.zig" },
        .{ .name = "update-check", .path = "examples/update_check.zig", .skip_run_all = true },
    };

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("args", args_module);
        exe.linkLibC();

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);

        // Add run step for each example
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        // Examples might need args to not fail or wait for input, adding --help is safe
        run_exe.addArg("--help");

        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);
    }

    // Create run-all-examples step that runs all examples sequentially
    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");
    var previous_run_step: ?*std.Build.Step = null;

    inline for (examples) |example| {
        if (example.skip_run_all) continue;
        const exe = b.addExecutable(.{
            .name = "run-all-" ++ example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("args", args_module);
        exe.linkLibC();

        const install_exe = b.addInstallArtifact(exe, .{});
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        run_exe.addArg("--help");

        // Make each run step depend on the previous run step to ensure sequential execution
        if (previous_run_step) |prev| {
            run_exe.step.dependOn(prev);
        }
        previous_run_step = &run_exe.step;
    }

    if (previous_run_step) |last| {
        run_all_examples.dependOn(last);
    }

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.linkLibC();

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });
    bench_exe.root_module.addImport("args", args_module);
    bench_exe.linkLibC();

    const install_bench = b.addInstallArtifact(bench_exe, .{});
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(&install_bench.step);

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Create comprehensive test-all step that runs everything sequentially
    const test_all_step = b.step("test-all", "Run all tests, benchmarks, and examples sequentially");

    // First run unit tests
    test_all_step.dependOn(test_step);

    // Then run benchmarks
    test_all_step.dependOn(bench_step);

    // Finally run all examples
    test_all_step.dependOn(run_all_examples);

    // Install step for library
    const lib = b.addLibrary(.{
        .name = "args",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    // Check step (Bonus: handy for LSP)
    const check_step = b.step("check", "Check for compilation errors");
    const check_main = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    check_step.dependOn(&check_main.step);

    // Format step
    const fmt_step = b.step("fmt", "Format source code");
    const fmt = b.addFmt(.{
        .paths = &.{ "src", "examples", "bench", "build.zig" },
    });
    fmt_step.dependOn(&fmt.step);
}
