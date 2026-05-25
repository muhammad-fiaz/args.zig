const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "data-input-validation",
        .description = "Typed input validators for emails, URLs, dates, JSON, and IDs",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addEmailOption("email", .{ .short = 'e', .help = "User email" });
    try parser.addUrlOption("endpoint", .{ .short = 'u', .help = "API endpoint URL" });
    try parser.addIpv4Option("host", .{ .short = 'H', .help = "Service IPv4 address" });
    try parser.addIpOption("host-any", .{ .help = "Service IP address (IPv4 or IPv6)" });
    try parser.addIpv6Option("host-v6", .{ .help = "Service IPv6 address" });
    try parser.addHostNameOption("hostname", .{ .help = "Service DNS hostname" });
    try parser.addUuidOption("request-id", .{ .help = "Request UUID" });
    try parser.addIsoDateOption("run-date", .{ .help = "Run date (YYYY-MM-DD)" });
    try parser.addIsoDateTimeOption("timestamp", .{ .help = "Run timestamp (ISO)" });
    try parser.addYearOption("year", .{ .help = "Run year (YYYY)" });
    try parser.addTimeOption("time", .{ .help = "Run time (HH:MM[:SS])" });
    try parser.addPortOption("port", .{ .help = "Service port (1..65535)" });
    try parser.addEndpointOption("service", .{ .help = "Service endpoint (host:port)" });
    try parser.addKeyValueOption("label", .{ .help = "Metadata label as key=value" });
    try parser.addAbsolutePathOption("workspace", .{ .help = "Absolute workspace path" });
    try parser.addFileOption("input-file", .{ .help = "Input file path (absolute or relative)", .must_exist = false });
    try parser.addJsonOption("payload", .{ .help = "JSON payload" });

    try parser.addOption("retries", .{
        .short = 'r',
        .help = "Retry count (1-10)",
        .value_type = .int,
        .validator = args.Validators.intRange(1, 10),
    });

    const workspace_abs = try std.Io.Dir.cwd().realPathFileAlloc(init.io, ".", allocator);
    defer allocator.free(workspace_abs);

    const argv = [_][]const u8{
        "--email",
        "ops@example.com",
        "--endpoint",
        "https://api.example.com/v1/tasks",
        "--host",
        "10.1.2.3",
        "--host-any",
        "fe80::1",
        "--host-v6",
        "2001:db8::1",
        "--hostname",
        "api.example.com",
        "--request-id",
        "123e4567-e89b-12d3-a456-426614174000",
        "--run-date",
        "2026-03-30",
        "--timestamp",
        "2026-03-30T12:45:59Z",
        "--year",
        "2026",
        "--time",
        "12:45:59",
        "--port",
        "8080",
        "--service",
        "api.example.com:443",
        "--label",
        "env=prod",
        "--workspace",
        workspace_abs,
        "--input-file",
        "./input.json",
        "--payload",
        "{\"task\":\"sync\",\"ok\":true}",
        "--retries",
        "3",
    };

    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    std.debug.print("email: {s}\n", .{parsed.getString("email") orelse "<missing>"});
    std.debug.print("endpoint: {s}\n", .{parsed.getString("endpoint") orelse "<missing>"});
    std.debug.print("host: {s}\n", .{parsed.getString("host") orelse "<missing>"});
    std.debug.print("host-any: {s}\n", .{parsed.getString("host-any") orelse "<missing>"});
    std.debug.print("host-v6: {s}\n", .{parsed.getString("host-v6") orelse "<missing>"});
    std.debug.print("hostname: {s}\n", .{parsed.getString("hostname") orelse "<missing>"});
    std.debug.print("request-id: {s}\n", .{parsed.getString("request-id") orelse "<missing>"});
    std.debug.print("run-date: {s}\n", .{parsed.getString("run-date") orelse "<missing>"});
    std.debug.print("timestamp: {s}\n", .{parsed.getString("timestamp") orelse "<missing>"});
    std.debug.print("year: {s}\n", .{parsed.getString("year") orelse "<missing>"});
    std.debug.print("time: {s}\n", .{parsed.getString("time") orelse "<missing>"});
    std.debug.print("port: {s}\n", .{parsed.getString("port") orelse "<missing>"});
    std.debug.print("service: {s}\n", .{parsed.getString("service") orelse "<missing>"});
    if (parsed.getKeyValue("label")) |kv| {
        std.debug.print("label: {s}={s}\n", .{ kv.key, kv.value });
    } else {
        std.debug.print("label: <missing>\n", .{});
    }
    std.debug.print("workspace: {s}\n", .{parsed.getString("workspace") orelse "<missing>"});
    std.debug.print("input-file: {s}\n", .{parsed.getString("input-file") orelse "<missing>"});
    std.debug.print("payload: {s}\n", .{parsed.getString("payload") orelse "<missing>"});
    std.debug.print("retries: {d}\n", .{parsed.getInt("retries") orelse 0});
}
