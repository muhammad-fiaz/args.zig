//! Demonstration of conflicts, requirements, conditional requirements, and mutual exclusion in args.zig.
//! Run with: zig build run-conflict_demo -- --help

const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;

    var ap = try args.ArgumentParser.init(allocator, .{
        .name = "conflict-demo",
        .config = .{ .exit_on_error = false },
    });
    defer ap.deinit();

    ap.description = "A demonstration of advanced argument validation and relations (conflicts/requires/exclusions)";

    // Set up arguments
    try ap.addFlag("mysql", .{ .help = "Use MySQL database backend" });
    try ap.addFlag("postgres", .{ .help = "Use PostgreSQL database backend" });

    try ap.addOption("host", .{ .help = "Database server host address" });
    try ap.addOption("port", .{ .help = "Database server port" });
    try ap.addOption("user", .{ .help = "Database username" });
    try ap.addOption("password", .{ .help = "Database password" });

    // 1. Mutual Exclusion: At most one of MySQL or Postgres backends may be used.
    try ap.addMutualExclusion(&[_][]const u8{ "mysql", "postgres" });

    // 2. Conditional Requirement: host and user are required IF mysql OR postgres is used.
    try ap.addRequiredIf("host", "mysql", null);
    try ap.addRequiredIf("host", "postgres", null);
    try ap.addRequiredIf("user", "mysql", null);
    try ap.addRequiredIf("user", "postgres", null);

    // 3. Simple Requirement: password is required IF user is provided.
    try ap.addRequires("password", "user");

    // 4. Conflicts: --postgres conflicts with --port 3306 (which is MySQL-specific).
    try ap.addRequiredIf("port", "mysql", "3306");

    // Parse arguments
    var result = ap.parseProcess(init) catch |err| {
        // If error occurred (and exit_on_error is false, or we caught it), handle here.
        std.debug.print("Failed to parse arguments: {any}\n", .{err});
        return;
    };
    defer result.deinit();

    std.debug.print("Successfully validated database configuration!\n", .{});
    if (result.contains("mysql")) {
        std.debug.print("Backend: MySQL\n", .{});
    } else if (result.contains("postgres")) {
        std.debug.print("Backend: PostgreSQL\n", .{});
    }
    const host = result.getString("host") orelse "localhost";
    const port = result.getString("port") orelse "default";
    const user = result.getString("user") orelse "(none)";
    std.debug.print("Server:  {s}:{s}\n", .{ host, port });
    std.debug.print("User:    {s}\n", .{user});
}
