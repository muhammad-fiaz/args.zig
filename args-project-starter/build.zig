const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const args_dep = b.dependency("args", .{
        .target = target,
        .optimize = optimize,
    });
    const args_module = args_dep.module("args");

    const exe = b.addExecutable(.{
        .name = "my-cli-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.root_module.addImport("args", args_module);

    const install_exe = b.addInstallArtifact(exe, .{});

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(&install_exe.step);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);

    b.installArtifact(exe);
}
