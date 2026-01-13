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

pub fn main() !void {
    // ... setup parser ...

    try parser.addOption("port", .{
        .short = 'p',
        .help = "Listening port",
        .validator = validatePort,
    });
}
```

If validation fails, the error message returned in `.err` will be displayed to the user.
