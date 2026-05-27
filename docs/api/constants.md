---
title: Constants Reference
description: Complete reference for all centralized constant namespaces in args.zig, helping developers reuse strings and keep error messages consistent.
head:
- - meta
  - name: keywords
    content: zig, args.zig, constants, Defaults, Metavars, HelpText, ErrorMessages, ConfigWarnings
---

# Constants Reference

To prevent magic strings, duplicate literals, and inconsistent CLI outputs, `args.zig` centralizes all user-visible text, labels, default values, error messages, and warnings within the `constants` module.

## Import

```zig
const args = @import("args");
const constants = args.constants;
```

---

## Centralized Namespaces

### 1. `Defaults`

Standard default option/flag names, description strings, and prompt settings:

```zig
constants.Defaults.program_name          // "app"
constants.Defaults.error_prefix           // "Error"
constants.Defaults.warning_prefix         // "Warning"
constants.Defaults.note_prefix            // "Note"
constants.Defaults.unknown_version        // "unknown"
constants.Defaults.verbose_name           // "verbose"
constants.Defaults.quiet_name             // "quiet"
constants.Defaults.verbose_help           // "Increase verbosity level"
constants.Defaults.quiet_help             // "Decrease verbosity level (suppress output)"
constants.Defaults.select_name            // "select"
constants.Defaults.select_help            // "Select specific items"
constants.Defaults.all_name               // "all"
constants.Defaults.all_help               // "Select all items"
constants.Defaults.selection_group        // "Selection"
constants.Defaults.filters_group          // "Filters"
constants.Defaults.include_name           // "include"
constants.Defaults.include_help           // "Comma-separated include filters"
constants.Defaults.exclude_name           // "exclude"
constants.Defaults.exclude_help           // "Comma-separated exclude filters"
constants.Defaults.duration_name          // "duration"
constants.Defaults.duration_help          // "Duration (e.g. 1h30m, 45s, 2d)"
constants.Defaults.size_name              // "size"
constants.Defaults.size_help              // "Byte size (e.g. 1GB, 512MB, 4096)"
```

### 2. `Metavars`

Default placeholder labels displayed in help menus for typed values:

```zig
constants.Metavars.path           // "PATH"
constants.Metavars.abs_path       // "ABS_PATH"
constants.Metavars.file           // "FILE"
constants.Metavars.dir            // "DIR"
constants.Metavars.email          // "EMAIL"
constants.Metavars.url            // "URL"
constants.Metavars.ipv4           // "IPV4"
constants.Metavars.ipv6           // "IPV6"
constants.Metavars.host           // "HOST"
constants.Metavars.uuid           // "UUID"
constants.Metavars.json           // "JSON"
constants.Metavars.key_value      // "KEY=VALUE"
constants.Metavars.int            // "INT"
constants.Metavars.float          // "FLOAT"
constants.Metavars.uint           // "UINT"
constants.Metavars.hex            // "HEX"
constants.Metavars.duration       // "DURATION"
constants.Metavars.byte_size      // "SIZE"
constants.Metavars.range          // "N"
constants.Metavars.regex          // "PATTERN"
```

### 3. `HelpText`

Section labels and metadata headings used in generated help displays:

```zig
constants.HelpText.usage                 // "USAGE:"
constants.HelpText.commands              // "COMMANDS:"
constants.HelpText.arguments             // "ARGUMENTS:"
constants.HelpText.options               // "OPTIONS:"
constants.HelpText.print_help            // "Print help"
constants.HelpText.print_version         // "Print version"
constants.HelpText.author                // "Author"
constants.HelpText.choices               // "choices"
constants.HelpText.default_label         // "default"
...
```

### 4. `ErrorMessages`

Base messages returned by the `formatParseError`, `formatSchemaError`, and `formatValidationError` formatting helpers:

```zig
constants.ErrorMessages.parse_unknown_option         // "unknown option"
constants.ErrorMessages.parse_missing_required       // "missing required argument"
constants.ErrorMessages.parse_missing_value          // "missing value for option"
constants.ErrorMessages.parse_invalid_choice         // "invalid choice"
constants.ErrorMessages.parse_conflicting_arguments  // "conflicting arguments"
constants.ErrorMessages.parse_missing_dependency     // "missing required dependency"
constants.ErrorMessages.parse_required_if_violation  // "argument is required when another is present"
constants.ErrorMessages.parse_circular_conflict      // "circular conflict detected between arguments"
constants.ErrorMessages.schema_duplicate_argument    // "duplicate argument"
constants.ErrorMessages.schema_circular_dependency   // "circular dependency"
constants.ErrorMessages.schema_self_conflict         // "argument cannot conflict with itself"
constants.ErrorMessages.validation_out_of_range      // "value out of range"
constants.ErrorMessages.validation_file_not_found    // "file not found"
constants.ErrorMessages.validation_invalid_duration  // "invalid duration format..."
constants.ErrorMessages.validation_invalid_size      // "invalid size format..."
```

### 5. `ParserMessages`

Formatting strings used directly by the parser to structure error prints:

```zig
constants.ParserMessages.unknown_option       // "Unknown option '{s}{s}'\n"
constants.ParserMessages.unknown_subcommand   // "Unknown subcommand '{s}'\n"
constants.ParserMessages.decode_failed        // "failed to decode value for argument '{s}'\n"
constants.ParserMessages.did_you_mean         // "\n\tDid you mean '{s}{s}'?\n"
constants.ParserMessages.deprecated_option    // "Option '--{s}' is deprecated: {s}\n"
```

### 6. `ConflictMessages`

String structures that format argument conflicts:

```zig
constants.ConflictMessages.conflict_error           // "Option '--{s}' cannot be used together with '--{s}'\n"
constants.ConflictMessages.mutual_exclusion_error   // "Only one of the following options may be used: {s}\n"
constants.ConflictMessages.conflict_hint            // "\n\tRemove one of the conflicting options and try again.\n"
```

### 7. `DependencyMessages`

Formatting patterns for option requirements and conditional dependencies:

```zig
constants.DependencyMessages.requires_error           // "Option '--{s}' requires '--{s}' to also be provided\n"
constants.DependencyMessages.required_if_error        // "Option '--{s}' is required when '--{s}' is provided\n"
constants.DependencyMessages.required_if_value_error  // "Option '--{s}' is required when '--{s}' has value '{s}'\n"
```

### 8. `ConfigWarnings`

Messages returned by the configuration analyzer to identify conflicting config combinations:

```zig
constants.ConfigWarnings.permissive_exit_on_error
constants.ConfigWarnings.colors_silent_errors
constants.ConfigWarnings.suggest_zero_distance
constants.ConfigWarnings.negated_flags_strict
constants.ConfigWarnings.indent_exceeds_width
```

### 9. `DeprecationMessages`

Messages printed when deprecated options or positionals are supplied:

```zig
constants.DeprecationMessages.deprecated_arg          // "Warning: '--{s}' is deprecated. {s}\n"
constants.DeprecationMessages.use_instead             // "\n\tUse '--{s}' instead.\n"
```

### 10. `FeatureMessages`

Validation error strings for the new typed options (durations, sizes, ranges):

```zig
constants.FeatureMessages.duration_help_suffix      // " (format: 1h30m, 45s, 2d12h, etc.)"
constants.FeatureMessages.size_help_suffix          // " (format: 1GB, 512MB, 1024KB, 4096, etc.)"
constants.FeatureMessages.range_help_suffix         // " (range: {d}..{d})"
constants.FeatureMessages.invalid_duration_fmt      // "invalid duration '{s}': expected format like..."
constants.FeatureMessages.invalid_size_fmt          // "invalid size '{s}': expected format like..."
constants.FeatureMessages.out_of_range_fmt          // "value {d} is out of range [{d}, {d}] for '--{s}'\n"
```

### 11. `TypeNames`

Centralized default type names and stringified zero-values:

```zig
constants.TypeNames.string               // "STRING"
constants.TypeNames.int                  // "INT"
constants.TypeNames.duration             // "DURATION"
constants.TypeNames.byte_size            // "SIZE"
constants.TypeNames.default_duration     // "0s"
constants.TypeNames.default_size         // "0"
```

### 12. `ValidationMessages`

User-facing error messages returned by built-in validators:

```zig
constants.ValidationMessages.invalid_email              // "invalid email address"
constants.ValidationMessages.invalid_url                // "invalid URL (expected http/https)"
constants.ValidationMessages.invalid_ipv4               // "invalid IPv4 address"
constants.ValidationMessages.invalid_ipv6               // "invalid IPv6 address"
constants.ValidationMessages.invalid_uuid               // "invalid UUID"
constants.ValidationMessages.invalid_iso_date           // "invalid date (expected YYYY-MM-DD)"
constants.ValidationMessages.invalid_json               // "invalid JSON"
constants.ValidationMessages.invalid_hex_color          // "invalid hex color (expected #RGB, #RRGGBB, ...)"
constants.ValidationMessages.invalid_semver             // "invalid semantic version (expected MAJOR.MINOR.PATCH)"
constants.ValidationMessages.invalid_base64             // "invalid base64 string"
constants.ValidationMessages.invalid_mac                // "invalid MAC address (expected XX:XX:XX:XX:XX:XX)"
constants.ValidationMessages.invalid_file_name          // "invalid file name"
constants.ValidationMessages.file_not_exist             // "file does not exist"
constants.ValidationMessages.dir_not_exist              // "directory does not exist"
constants.ValidationMessages.path_not_exist             // "path does not exist"
constants.ValidationMessages.invalid_endpoint           // "invalid endpoint (expected host:port)"
constants.ValidationMessages.invalid_kv_pair            // "invalid key=value pair"
constants.ValidationMessages.must_be_alphanumeric       // "value must be alphanumeric"
constants.ValidationMessages.must_be_numeric            // "value must be numeric"
constants.ValidationMessages.invalid_int                // "invalid integer"
constants.ValidationMessages.int_out_of_range           // "integer is out of range"
```

### 13. `HelpFormat`

Format strings and labels used in help text generation:

```zig
// Reusable format strings
constants.HelpFormat.options_tag             // " [OPTIONS]"
constants.HelpFormat.command_tag             // " <COMMAND>"
constants.HelpFormat.required_annotation     // " [required]"
constants.HelpFormat.choices_format          // " [choices: "
constants.HelpFormat.choices_close           // "]"
constants.HelpFormat.default_label           // " [default: "
constants.HelpFormat.env_label               // " [env: "
constants.HelpFormat.negate_label            // " [negate: --no-"
constants.HelpFormat.close_bracket           // "]"
```

### 15. `UpdateNotification`

Banner format strings displayed when a new version is available:

```zig
constants.UpdateNotification.top_border      // "╭───────────────────────────────────────╮\n"
constants.UpdateNotification.message_line    // "│  A new version of ... available: ...  │\n"
constants.UpdateNotification.command_line    // "│  Run: zig fetch --save ...           │\n"
constants.UpdateNotification.bottom_border   // "╰───────────────────────────────────────╯\n"
```
