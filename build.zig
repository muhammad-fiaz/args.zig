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
        .{ .name = "config_modes", .path = "examples/config_modes.zig" },
        .{ .name = "negated_flags", .path = "examples/negated_flags.zig" },
        .{ .name = "positional_validation", .path = "examples/positional_validation.zig" },
        .{ .name = "select_all", .path = "examples/select_all.zig" },
        .{ .name = "question_flow", .path = "examples/question_flow.zig" },
        .{ .name = "include_exclude", .path = "examples/include_exclude.zig" },
        .{ .name = "include_exclude_strict", .path = "examples/include_exclude_strict.zig" },
        .{ .name = "file_support", .path = "examples/file_support.zig" },
        .{ .name = "data_input_validation", .path = "examples/data_input_validation.zig" },
        .{ .name = "network_endpoints", .path = "examples/network_endpoints.zig" },
        .{ .name = "error_handling", .path = "examples/error_handling.zig" },
        .{ .name = "subcommand_suggestions", .path = "examples/subcommand_suggestions.zig" },
        .{ .name = "decryption_options", .path = "examples/decryption_options.zig" },
        .{ .name = "custom_parsing", .path = "examples/custom_parsing.zig" },
        .{ .name = "callbacks", .path = "examples/callbacks.zig" },
        .{ .name = "key_value", .path = "examples/key_value.zig" },
        .{ .name = "struct_demo", .path = "examples/struct_demo.zig" },
        .{ .name = "expect_validation", .path = "examples/expect_validation.zig" },
        .{ .name = "int_float_options", .path = "examples/int_float_options.zig" },
        .{ .name = "hex_option", .path = "examples/hex_option.zig" },
        .{ .name = "log_level", .path = "examples/log_level.zig" },
        .{ .name = "advanced_struct", .path = "examples/advanced_struct.zig" },
        .{ .name = "env_var_config", .path = "examples/env_var_config.zig" },
        .{ .name = "list_option", .path = "examples/list_option.zig" },
        .{ .name = "validation_demo", .path = "examples/validation_demo.zig" },
        .{ .name = "conflict_demo", .path = "examples/conflict_demo.zig" },
        .{ .name = "config_warnings", .path = "examples/config_warnings.zig" },
        .{ .name = "duration_size", .path = "examples/duration_size.zig" },
        .{ .name = "subcommand_range", .path = "examples/subcommand_range.zig" },
        .{ .name = "update_check", .path = "examples/update_check.zig", .skip_run_all = true },
        .{ .name = "bracketed_list", .path = "examples/bracketed_list.zig" },
        .{ .name = "format_option", .path = "examples/format_option.zig" },
        .{ .name = "fallback_parse", .path = "examples/fallback_parse.zig" },
        .{ .name = "append_option", .path = "examples/append_option.zig" },
        .{ .name = "multi_value", .path = "examples/multi_value.zig" },
        .{ .name = "bool_options", .path = "examples/bool_options.zig" },
    };

    // Create run-all-examples step that runs all examples sequentially
    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");

    // Build examples in smaller batches to avoid OOM
    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });
        exe.root_module.addImport("args", args_module);

        // Link ws2_32 on Windows for networking examples
        if (target.result.os.tag == .windows) {
            exe.root_module.linkSystemLibrary("ws2_32", .{});
        }

        const install_exe = b.addInstallArtifact(exe, .{});

        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);

        // Add run step for each example
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        run_exe.addArg("--help");

        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);
    }

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/args.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    if (target.result.os.tag == .windows) {
        tests.root_module.linkSystemLibrary("ws2_32", .{});
    }

    const run_tests = b.addRunArtifact(tests);
    if (b.args) |args| {
        run_tests.addArgs(args);
    }
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Benchmark
    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .link_libc = true,
        }),
    });
    bench_exe.root_module.addImport("args", args_module);

    if (target.result.os.tag == .windows) {
        bench_exe.root_module.linkSystemLibrary("ws2_32", .{});
    }

    const install_bench = b.addInstallArtifact(bench_exe, .{});
    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.step.dependOn(&install_bench.step);
    if (b.args) |args| {
        run_bench.addArgs(args);
    }

    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Docs generation
    const docs_step = b.step("docs", "Generate documentation");
    const docs_obj = b.addObject(.{
        .name = "args",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/args.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

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
            .link_libc = true,
        }),
    });
    b.installArtifact(lib);
}
