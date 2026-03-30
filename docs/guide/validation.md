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
