const std = @import("std");
const args = @import("args");

pub fn main(init: std.process.Init) !void {
    _ = init;
    const allocator = std.heap.c_allocator;

    var parser = try args.ArgumentParser.init(allocator, .{
        .name = "network-endpoints",
        .description = "Validate IPv4, IPv6, host:port, and retries in one CLI",
        .config = .{
            .exit_on_error = false,
            .check_for_updates = false,
            .silent_errors = true,
        },
    });
    defer parser.deinit();

    try parser.addIpv4Option("host", .{ .help = "Service IPv4 address" });
    try parser.addIpOption("host-any", .{ .help = "Service IP address (IPv4 or IPv6)" });
    try parser.addIpv6Option("host-v6", .{ .help = "Service IPv6 address" });
    try parser.addEndpointOption("service", .{ .help = "Service endpoint (host:port or [ipv6]:port)" });
    try parser.addPortOption("port", .{ .help = "Service port" });

    try parser.addOption("retries", .{
        .help = "Retry count (1-10)",
        .value_type = .int,
        .validator = args.Validators.intRange(1, 10),
        .default = "3",
    });

    const argv = [_][]const u8{
        "--host",
        "10.10.0.5",
        "--host-any",
        "fe80::10",
        "--host-v6",
        "2001:db8::10",
        "--service",
        "[2001:db8::10]:8443",
        "--port",
        "8443",
        "--retries",
        "4",
    };

    var parsed = try parser.parse(&argv);
    defer parsed.deinit();

    const host = parsed.getString("host") orelse "<missing>";
    const host_any = parsed.getString("host-any") orelse "<missing>";
    const host_v6 = parsed.getString("host-v6") orelse "<missing>";
    const service = parsed.getString("service") orelse "<missing>";
    const port = parsed.getString("port") orelse "<missing>";
    const retries = parsed.getInt("retries") orelse 0;

    std.debug.print("host: {s}\n", .{host});
    std.debug.print("host-any: {s}\n", .{host_any});
    std.debug.print("host-v6: {s}\n", .{host_v6});
    std.debug.print("service: {s}\n", .{service});
    std.debug.print("port: {s}\n", .{port});
    std.debug.print("retries: {d}\n", .{retries});
}
