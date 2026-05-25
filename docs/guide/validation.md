# Validation

args.zig provides robust validation mechanisms to ensure your application receives correct input.

## Built-in Validation

### Type Checking
Arguments are automatically validated against their `value_type`.
- `.int`, `.uint`: Must be valid integers.
- `.float`: Must be valid floating-point numbers.
- `.bool`: Must be `true`, `false`, `1`, `0`, `yes`, `no`, etc.

### Choices
You can restrict values to a specific set of strings using `.choices`.

```zig
try parser.addOption("output-format", .{
    .short = 'f',
    .choices = &[_][]const u8{ "json", "yaml", "xml" },
    .help = "Output format",
});
```

If the user provides a value not in the list, parsing fails.

### Soft Validation (Expect)
If you want to suggest expected values but not strictly enforce them (depending on configuration), use `.expect`.

```zig
try parser.addOption("env", .{
    .short = 'e',
    .expect = &[_][]const u8{ "dev", "prod" },
    .help = "Environment",
});
```

Behavior depends on `Config`:
- **Strict Mode**: behaves like `choices` (errors on mismatch).
- **Permissive Mode** (default): prints a warning if value is not in `expect` list, but accepts it.

## Positional Validation

Validation options are available for positional arguments too.

```zig
try parser.addPositional("mode", .{
    .choices = &[_][]const u8{ "dev", "prod" },
});
```

`addPositional` also supports `.expect`, `.validator`, and `.hidden`.


## Custom Validators

For more complex validation logic, you can provide a custom validator function. A validator function takes the string value and returns a `ValidationResult`.

```zig
const std = @import("std");
const args = @import("args");

fn validatePort(val: []const u8) args.validation.ValidationResult {
    const port = std.fmt.parseInt(u16, val, 10) catch return .{ .err = "not a valid integer" };
    if (port < 1024) return .{ .err = "port must be >= 1024 (privileged)" };
    return .{ .ok = {} };
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    // ... setup parser ...

    try parser.addOption("port", .{
        .short = 'p',
        .help = "Listening port",
        .validator = validatePort,
    });
}
```

If validation fails, the error message returned in `.err` will be displayed to the user.

## Built-in File And Filename Validators

args.zig includes reusable built-ins for common file workflows:

- `Validators.pathExists`
- `Validators.fileExists`
- `Validators.directoryExists`
- `Validators.extension(...)`
- `Validators.existingFileWithExtension(...)`
- `Validators.fileNameSafe`
- `Validators.fileNameWithExtensions(...)`
- `Validators.fileNameLength(min, max)`

## Typed Input Validators

args.zig also provides reusable validators for common app and API inputs:

- `Validators.emailAddress` / `Validators.email`
- `Validators.httpUrl` / `Validators.url`
- `Validators.ipv4` / `Validators.ip`
- `Validators.ipv6`
- `Validators.ipAny` / `Validators.anyIp`
- `Validators.hostname`
- `Validators.port`
- `Validators.endpoint` / `Validators.hostPort`
- `Validators.keyValuePair` / `Validators.keyValue`
- `Validators.uuid`
- `Validators.isoDate` / `Validators.date`
- `Validators.isoDateTime` / `Validators.dateTime`
- `Validators.year`
- `Validators.time`
- `Validators.json`
- `Validators.absolutePath`
- `Validators.intRange(min, max)`
- `Validators.floatRange(min, max)`

You can use them directly:

```zig
try parser.addOption("email", .{ .validator = args.Validators.email });
try parser.addOption("endpoint", .{ .validator = args.Validators.url });
try parser.addOption("host-v6", .{ .validator = args.Validators.ipv6 });
try parser.addOption("any-ip", .{ .validator = args.Validators.anyIp });
try parser.addOption("peer", .{ .validator = args.Validators.anyIp });
try parser.addOption("label", .{ .value_type = .key_value, .validator = args.Validators.keyValuePair });
try parser.addOption("run-date", .{ .validator = args.Validators.date });
```

Or use high-level parser helpers:

```zig
try parser.addEmailOption("email", .{});
try parser.addUrlOption("endpoint", .{});
try parser.addIpv4Option("host", .{});
try parser.addIpOption("host-any", .{});
try parser.addIpv6Option("host-v6", .{});
try parser.addHostNameOption("hostname", .{});
try parser.addPortOption("port", .{});
try parser.addEndpointOption("service", .{}); // host:port
try parser.addKeyValueOption("label", .{}); // key=value
try parser.addUuidOption("request-id", .{});
try parser.addIsoDateOption("run-date", .{});
try parser.addIsoDateTimeOption("timestamp", .{});
try parser.addYearOption("year", .{});
try parser.addTimeOption("time", .{});
try parser.addAbsolutePathOption("workspace", .{});
try parser.addJsonOption("payload", .{});
```

### Typed Helper Options (Setting Values)

Every typed helper accepts the same practical option fields used by `addOption` for day-to-day CLI design:

- `.short` for short flags like `-e`
- `.help` for help text
- `.default` for fallback values
- `.required` to force user input
- `.env_var` to read from environment variables
- `.aliases` for alternate long names
- `.validator` to override the default built-in validator

### Decryption / Decoding Options

For secrets or encoded payloads, args.zig can decode values before validation and storage.

- `addDecryptionOption(...)` decodes Base64 input into plain text.
- `.url_safe = true` switches to URL-safe Base64 decoding.
- `addOption(..., .{ .decode_mode = ... })` and `addPositional(..., .{ .decode_mode = ... })` provide low-level control.

```zig
try parser.addDecryptionOption("secret", .{ .required = true });
try parser.addDecryptionOption("session", .{ .url_safe = true });

try parser.addOption("payload", .{
    .decode_mode = .base64_std,
});
```

```zig
try parser.addEmailOption("email", .{
    .short = 'e',
    .help = "User email",
    .required = true,
    .env_var = "APP_EMAIL",
});

try parser.addEndpointOption("service", .{
    .help = "Service endpoint in host:port format",
    .default = "localhost:8080",
});

try parser.addOption("retries", .{
    .short = 'r',
    .help = "Retry count (1-10)",
    .value_type = .int,
    .validator = args.Validators.intRange(1, 10),
    .default = "3",
});
```

### Getting Values After Parse

Most typed helper values are stored as strings, so retrieve them with `getString(...)`.
For numeric options where you set `.value_type = .int`, use `getInt(...)`.

```zig
var parsed = try parser.parseProcess(init);
defer parsed.deinit();

const email = parsed.getString("email") orelse "";
const service = parsed.getString("service") orelse "localhost:8080";
const retries = parsed.getInt("retries") orelse 3;
```

### CLI Example

```bash
myapp \
  --email ops@example.com \
  --service api.example.com:443 \
  --retries 5
```

When a value is missing, defaults and environment fallbacks are used (if configured).

## Validator Composition

You can combine validators without duplicating logic:

```zig
const output_name_validator = args.Validators.all(&[_]args.ValidatorFn{
    args.Validators.fileExt(&[_][]const u8{"json"}, false),
    args.Validators.fileNameLength(3, 64),
});

try parser.addOption("output-name", .{
    .validator = output_name_validator,
});
```

Use `args.Validators.any(...)` for OR-style matching.

## Simplified Direct API

For common filename rules, use one direct call:

```zig
const output_name_validator = args.Validators.filePolicy(&[_][]const u8{"json"}, false, 3, 64);
```

Alias shortcuts are also available:

- `args.Validators.all(...)` / `args.Validators.any(...)`
- `args.Validators.fileName`
- `args.Validators.fileExt(...)`
- `args.Validators.filePolicy(...)`
