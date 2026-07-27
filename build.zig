const std = @import("std");

/// Forward extra CLI args to a run step in a way compatible with both Zig 0.16
/// and 0.17+. In 0.17 the `b.args` field was removed and replaced by
/// `run.addPassthruArgs()`. We detect this at comptime via `@hasDecl`.
inline fn passthruArgs(run: *std.Build.Step.Run, b: *std.Build) void {
    if (comptime @hasDecl(std.Build.Step.Run, "addPassthruArgs")) {
        run.addPassthruArgs();
    } else {
        // Zig 0.16: b.args is a nullable []const []const u8 field on Build.
        if (b.args) |args| run.addArgs(args);
    }
}

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

    // Opt-in examples (not built by default).
    // When consumed as a library dependency these steps are never created.
    // Build them with `zig build example-<name>` or `zig build -Dbuild-examples=true`.
    const build_examples = b.option(bool, "build-examples", "Build example programs") orelse false;

    if (build_examples) {
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
            .{ .name = "export_args", .path = "examples/export_args.zig" },
            .{ .name = "prefix_option", .path = "examples/prefix_option.zig" },
            .{ .name = "secret_option", .path = "examples/secret_option.zig" },
            .{ .name = "range_validation", .path = "examples/range_validation.zig" },
            .{ .name = "env_option", .path = "examples/env_option.zig" },
            .{ .name = "result_accessors", .path = "examples/result_accessors.zig" },
            .{ .name = "schema_builder", .path = "examples/schema_builder.zig" },
            .{ .name = "quick_parse", .path = "examples/quick_parse.zig" },
        };

        const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");

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

            if (target.result.os.tag == .windows) {
                exe.root_module.linkSystemLibrary("ws2_32", .{});
            }

            const install_exe = b.addInstallArtifact(exe, .{});

            const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
            example_step.dependOn(&install_exe.step);

            const run_exe = b.addRunArtifact(exe);
            run_exe.step.dependOn(&install_exe.step);
            passthruArgs(run_exe, b);

            const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
            run_step.dependOn(&run_exe.step);

            if (!example.skip_run_all) {
                run_all_examples.dependOn(&run_exe.step);
            }
        }
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
    passthruArgs(run_tests, b);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Opt-in benchmark.
    const run_bench_step = b.step("bench", "Run benchmarks");
    const build_benchmarks = b.option(bool, "build-benchmarks", "Build benchmark program") orelse false;

    if (build_benchmarks) {
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
        passthruArgs(run_bench, b);

        run_bench_step.dependOn(&run_bench.step);
    }

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
    const test_all_step = b.step("test-all", "Run all tests and benchmarks sequentially");
    test_all_step.dependOn(test_step);
    if (build_benchmarks) {
        test_all_step.dependOn(run_bench_step);
    }

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
