# Argument Groups

args.zig allows you to organize your arguments into logical groups in the help output, and to enforce mutually exclusive constraints.

## Creating a Group

Use `addArgumentGroup` to create a new group and set it as the active group. All arguments added subsequently will belong to this group until `setGroup` is called or another group is created.

```zig
try parser.addArgumentGroup("Network Options", .{
    .description = "Configuration for network connectivity",
});

// These arguments belong to "Network Options"
try parser.addOption("host", .{ 
    .help = "Hostname or IP address",
    .default = "localhost" 
});
try parser.addOption("port", .{ 
    .short = 'p',
    .value_type = .int, 
    .help = "Port number" 
});

// Stop adding to the group
parser.setGroup(null);
```

In the help output, this will appear as:

```text
Network Options:
  Configuration for network connectivity

    --host <string>     Hostname or IP address [default: localhost]
    -p, --port <int>    Port number
```

## Mutually Exclusive Groups

You can create a group where only one of the arguments can be provided.

```zig
try parser.addArgumentGroup("Operation Mode", .{
    .exclusive = true,
    .required = true, // User MUST provide one of them
});

try parser.addFlag("server", .{ .help = "Run in server mode" });
try parser.addFlag("client", .{ .help = "Run in client mode" });
```

If the user provides both `--server` and `--client`, parsing will fail with an error.
