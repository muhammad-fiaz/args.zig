//! Advanced example demonstrating args.zig advanced features.
//! Shows subcommands, environment variables, completions, and more.

const std = @import("std");
const args = @import("args");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create argument parser with custom config
    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "advanced-cli",
        .version = "2.0.0",
        .description = "An advanced CLI demonstrating all args.zig features",
        .epilog = "Examples:\n  advanced-cli init myproject\n  advanced-cli build --release\n  advanced-cli deploy --env production",
    });
    defer parser.deinit();

    // Global options (apply to all subcommands)
    try parser.addFlag("verbose", .{
        .short = 'v',
        .help = "Enable verbose output",
    });

    try parser.addOption("config", .{
        .short = 'c',
        .help = "Configuration file path",
        .env_var = "CLI_CONFIG",
        .default = "config.yml",
    });

    // Add 'init' subcommand
    try parser.addSubcommand(.{
        .name = "init",
        .help = "Initialize a new project",
        .aliases = &[_][]const u8{"i"},
        .args = &[_]args.ArgSpec{
            .{
                .name = "name",
                .positional = true,
                .required = true,
                .help = "Project name",
            },
            .{
                .name = "template",
                .short = 't',
                .long = "template",
                .help = "Project template",
                .choices = &[_][]const u8{ "basic", "advanced", "minimal" },
                .default = "basic",
            },
            .{
                .name = "git",
                .short = 'g',
                .long = "git",
                .action = .store_true,
                .help = "Initialize git repository",
            },
        },
    });

    // Add 'build' subcommand
    try parser.addSubcommand(.{
        .name = "build",
        .help = "Build the project",
        .aliases = &[_][]const u8{"b"},
        .args = &[_]args.ArgSpec{
            .{
                .name = "release",
                .short = 'r',
                .long = "release",
                .action = .store_true,
                .help = "Build in release mode",
            },
            .{
                .name = "target",
                .long = "target",
                .help = "Build target",
                .default = "native",
            },
            .{
                .name = "jobs",
                .short = 'j',
                .long = "jobs",
                .value_type = .int,
                .help = "Number of parallel jobs",
                .default = "4",
            },
        },
    });

    // Add 'deploy' subcommand
    try parser.addSubcommand(.{
        .name = "deploy",
        .help = "Deploy the application",
        .aliases = &[_][]const u8{"d"},
        .args = &[_]args.ArgSpec{
            .{
                .name = "env",
                .short = 'e',
                .long = "env",
                .required = true,
                .help = "Deployment environment",
                .choices = &[_][]const u8{ "development", "staging", "production" },
            },
            .{
                .name = "force",
                .short = 'f',
                .long = "force",
                .action = .store_true,
                .help = "Force deployment without confirmation",
            },
            .{
                .name = "dry-run",
                .long = "dry-run",
                .action = .store_true,
                .help = "Simulate deployment without making changes",
            },
        },
    });

    // Add 'completion' subcommand for shell completions
    try parser.addSubcommand(.{
        .name = "completion",
        .help = "Generate shell completion script",
        .args = &[_]args.ArgSpec{
            .{
                .name = "shell",
                .positional = true,
                .required = true,
                .help = "Shell type (bash, zsh, fish, powershell, nushell)",
            },
        },
    });

    // Parse arguments
    var result = try parser.parseProcess();
    defer result.deinit();

    // Get global options
    const verbose = result.getBool("verbose") orelse false;
    const config = result.getString("config") orelse "config.yml";

    if (verbose) {
        std.debug.print("[VERBOSE] Using config: {s}\n", .{config});
    }

    // Handle subcommands
    if (result.subcommand) |cmd| {
        const sub_args = result.subcommand_args.?;

        if (std.mem.eql(u8, cmd, "init")) {
            const name = sub_args.getString("name").?;
            const template = sub_args.getString("template") orelse "basic";
            const init_git = sub_args.getBool("git") orelse false;

            std.debug.print("Initializing project '{s}' with template '{s}'\n", .{ name, template });
            if (init_git) {
                std.debug.print("  - Git repository will be initialized\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "build")) {
            const release = sub_args.getBool("release") orelse false;
            const target = sub_args.getString("target") orelse "native";
            const jobs = sub_args.getInt("jobs") orelse 4;

            const mode = if (release) "release" else "debug";
            std.debug.print("Building in {s} mode for target '{s}' with {d} jobs\n", .{ mode, target, jobs });
        } else if (std.mem.eql(u8, cmd, "deploy")) {
            const env = sub_args.getString("env").?;
            const force = sub_args.getBool("force") orelse false;
            const dry_run = sub_args.getBool("dry-run") orelse false;

            if (dry_run) {
                std.debug.print("[DRY-RUN] Would deploy to '{s}'\n", .{env});
            } else {
                std.debug.print("Deploying to '{s}'", .{env});
                if (force) std.debug.print(" (forced)", .{});
                std.debug.print("\n", .{});
            }
        } else if (std.mem.eql(u8, cmd, "completion")) {
            const shell_name = sub_args.getString("shell").?;

            // Generate completion script
            const shell = args.Shell.fromString(shell_name) orelse {
                std.debug.print("Unknown shell: {s}\n", .{shell_name});
                std.debug.print("Supported: bash, zsh, fish, powershell, nushell\n", .{});
                return;
            };

            const script = try parser.generateCompletion(shell);
            defer allocator.free(script);
            std.debug.print("{s}", .{script});
        }
    } else {
        // No subcommand - show help
        std.debug.print("No subcommand provided. Use --help for usage.\n", .{});
        try parser.printHelp();
    }
}
