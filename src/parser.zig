//! Main argument parser for args.zig.

const std = @import("std");
const types = @import("types.zig");
const schema_mod = @import("schema.zig");
const tokenizer_mod = @import("tokenizer.zig");
const validation = @import("validation.zig");
const errors = @import("errors.zig");
const help = @import("help.zig");
const config_mod = @import("config.zig");
const utils = @import("utils.zig");

pub const ParseResult = types.ParseResult;
pub const ParsedValue = types.ParsedValue;
pub const ArgSpec = schema_mod.ArgSpec;
pub const CommandSpec = schema_mod.CommandSpec;
pub const Tokenizer = tokenizer_mod.Tokenizer;
pub const Token = tokenizer_mod.Token;
pub const TokenType = tokenizer_mod.TokenType;
pub const Config = config_mod.Config;

/// Main argument parser.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    cfg: Config,
    short_map: std.AutoHashMap(u8, *const ArgSpec),
    long_map: std.StringHashMap(*const ArgSpec),

    pub fn init(allocator: std.mem.Allocator, spec: CommandSpec) !Parser {
        var self = Parser{
            .allocator = allocator,
            .spec = spec,
            .cfg = config_mod.getConfig(),
            .short_map = std.AutoHashMap(u8, *const ArgSpec).init(allocator),
            .long_map = std.StringHashMap(*const ArgSpec).init(allocator),
        };

        for (self.spec.args) |*arg| {
            if (arg.short) |s| try self.short_map.put(s, arg);
            if (arg.long) |l| try self.long_map.put(l, arg);
            for (arg.aliases) |alias| {
                try self.long_map.put(alias, arg);
            }
        }

        return self;
    }

    pub fn deinit(self: *Parser) void {
        self.short_map.deinit();
        self.long_map.deinit();
    }

    pub fn parse(self: *Parser, args: []const []const u8) !ParseResult {
        var result = ParseResult.init(self.allocator);
        errdefer result.deinit();

        for (self.spec.args) |arg| {
            if (arg.default) |def| {
                const value = try validation.parseValue(def, arg.value_type, self.allocator);
                try result.values.put(arg.getDestination(), value);
            }
        }

        var tokenizer = Tokenizer.init(args);
        var positional_index: usize = 0;

        while (tokenizer.hasMore()) {
            const tok = tokenizer.next();

            switch (tok.token_type) {
                .long_option => try self.handleOption(tok, &tokenizer, &result, false),
                .short_option => try self.handleOption(tok, &tokenizer, &result, true),
                .option_with_value => try self.handleOptionWithValue(tok, &result),
                .value => {
                    if (positional_index == 0 and self.spec.subcommands.len > 0) {
                        for (self.spec.subcommands) |sub| {
                            if (utils.eql(tok.raw, sub.name)) {
                                result.subcommand = sub.name;
                                var sub_parser = try Parser.init(self.allocator, .{
                                    .name = sub.name,
                                    .args = sub.args,
                                    .subcommands = sub.subcommands,
                                });
                                defer sub_parser.deinit();
                                const sub_result = try sub_parser.parse(tokenizer.remaining());
                                result.subcommand_args = try self.allocator.create(ParseResult);
                                result.subcommand_args.?.* = sub_result;
                                return result;
                            }
                        }
                    }
                    try self.handlePositional(tok.raw, positional_index, &result);
                    positional_index += 1;
                },
                .separator => {
                    while (tokenizer.hasMore()) {
                        const rem = tokenizer.next();
                        try result.remaining.append(self.allocator, rem.raw);
                    }
                },
                .end => break,
                else => {},
            }
        }

        try self.processEnvVars(&result);
        try self.validateRequired(&result);
        try self.validateGroups(&result);
        return result;
    }

    fn processEnvVars(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (result.contains(arg.getDestination())) continue;

            var env_key_buf: [256]u8 = undefined;
            var env_key: ?[]const u8 = null;

            if (arg.env_var) |env| {
                env_key = env;
            } else if (self.cfg.env_prefix) |prefix| {
                // Determine name: use long option name or arg name
                const name = arg.long orelse arg.name;
                // Format: PREFIX_NAME (uppercase)
                const full_len = prefix.len + 1 + name.len;
                if (full_len <= env_key_buf.len) {
                    @memcpy(env_key_buf[0..prefix.len], prefix);
                    env_key_buf[prefix.len] = '_';
                    @memcpy(env_key_buf[prefix.len + 1 ..][0..name.len], name);

                    const slice = env_key_buf[0..full_len];
                    for (slice) |*c| c.* = std.ascii.toUpper(c.*);
                    env_key = slice;
                }
            }

            if (env_key) |key| {
                if (std.process.getEnvVarOwned(self.allocator, key)) |env_val| {
                    defer self.allocator.free(env_val);
                    const value = try validation.parseValue(env_val, arg.value_type, self.allocator);
                    try result.values.put(arg.getDestination(), value);
                } else |_| {}
            }
        }
    }

    fn validateGroups(self: *Parser, result: *ParseResult) !void {
        for (self.spec.groups) |group| {
            var found_count: usize = 0;
            for (self.spec.args) |arg| {
                if (arg.group) |gname| {
                    if (utils.eql(gname, group.name)) {
                        if (result.contains(arg.getDestination())) {
                            found_count += 1;
                        }
                    }
                }
            }

            if (group.exclusive and found_count > 1) return errors.ParseError.MutuallyExclusive;
            if (group.required and found_count == 0) return errors.ParseError.MissingRequired;
        }
    }

    fn handleOption(self: *Parser, tok: Token, tokenizer: *Tokenizer, result: *ParseResult, is_short: bool) !void {
        const name = tok.name orelse return errors.ParseError.InvalidFormat;

        const arg_spec = if (is_short)
            self.short_map.get(name[0])
        else
            self.long_map.get(name);

        if (arg_spec == null) {
            if (!is_short and utils.eql(name, "help")) {
                const help_text = try help.generateHelp(self.allocator, self.spec, self.cfg.use_colors);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (!is_short and utils.eql(name, "version")) {
                std.debug.print("{s} {s}\n", .{ self.spec.name, self.spec.version orelse "unknown" });
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (is_short and name[0] == 'h') {
                const help_text = try help.generateHelp(self.allocator, self.spec, self.cfg.use_colors);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (is_short and name[0] == 'V') {
                std.debug.print("{s} {s}\n", .{ self.spec.name, self.spec.version orelse "unknown" });
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            return errors.ParseError.UnknownOption;
        }

        const spec = arg_spec.?;
        const dest = spec.getDestination();

        switch (spec.action) {
            .store_true => try result.values.put(dest, .{ .boolean = true }),
            .store_false => try result.values.put(dest, .{ .boolean = false }),
            .count => {
                const current = result.values.get(dest);
                const count: u32 = if (current) |c| blk: {
                    break :blk if (c == .counter) c.counter + 1 else 1;
                } else 1;
                try result.values.put(dest, .{ .counter = count });
            },
            .store, .append => {
                const next = tokenizer.peek();
                if (next.token_type != .value) return errors.ParseError.MissingValue;
                _ = tokenizer.next();
                const value = try validation.parseValue(next.raw, spec.value_type, self.allocator);
                if (spec.validator) |v| {
                    const res = v(next.raw);
                    if (!res.isOk()) {
                        return errors.ValidationError.CustomValidationFailed;
                    }
                }
                if (spec.choices.len > 0 and !validation.validateChoice(next.raw, spec.choices)) {
                    return errors.ParseError.InvalidChoice;
                }
                if (spec.action == .append) {
                    try result.positionals.append(self.allocator, next.raw);
                } else {
                    try result.values.put(dest, value);
                }
            },
            .help => {
                const help_text = try help.generateHelp(self.allocator, self.spec, self.cfg.use_colors);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
            },
            .version => {
                std.debug.print("{s} {s}\n", .{ self.spec.name, self.spec.version orelse "unknown" });
                if (self.cfg.exit_on_error) std.process.exit(0);
            },
            else => {},
        }
    }

    fn handleOptionWithValue(self: *Parser, tok: Token, result: *ParseResult) !void {
        const name = tok.name orelse return errors.ParseError.InvalidFormat;
        const value_str = tok.inline_value orelse return errors.ParseError.MissingValue;

        const arg_spec = self.long_map.get(name) orelse
            if (name.len == 1) self.short_map.get(name[0]) else null;

        if (arg_spec == null) return errors.ParseError.UnknownOption;

        const spec = arg_spec.?;
        const dest = spec.getDestination();
        const value = try validation.parseValue(value_str, spec.value_type, self.allocator);

        if (spec.validator) |v| {
            const res = v(value_str);
            if (!res.isOk()) {
                return errors.ValidationError.CustomValidationFailed;
            }
        }

        if (spec.choices.len > 0 and !validation.validateChoice(value_str, spec.choices)) {
            return errors.ParseError.InvalidChoice;
        }

        try result.values.put(dest, value);
    }

    fn handlePositional(self: *Parser, value_str: []const u8, index: usize, result: *ParseResult) !void {
        var pos_idx: usize = 0;
        for (self.spec.args) |arg| {
            if (arg.positional) {
                if (pos_idx == index) {
                    const value = try validation.parseValue(value_str, arg.value_type, self.allocator);
                    if (arg.validator) |v| {
                        const res = v(value_str);
                        if (!res.isOk()) {
                            return errors.ValidationError.CustomValidationFailed;
                        }
                    }
                    try result.values.put(arg.getDestination(), value);
                    return;
                }
                pos_idx += 1;
            }
        }
        try result.positionals.append(self.allocator, value_str);
    }

    fn validateRequired(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (arg.required and !result.contains(arg.getDestination())) {
                return errors.ParseError.MissingRequired;
            }
        }
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, spec: CommandSpec, args: []const []const u8) !ParseResult {
    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();
    return parser.parse(args);
}

test "Parser basic parsing" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .add_version = false,
        .args = &[_]ArgSpec{
            .{ .name = "verbose", .short = 'v', .long = "verbose", .action = .store_true },
            .{ .name = "output", .short = 'o', .long = "output" },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{ "-v", "--output", "file.txt" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expect(result.getBool("verbose").?);
    try std.testing.expectEqualStrings("file.txt", result.getString("output").?);
}

test "Parser counter action" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "verbose", .short = 'v', .action = .count }},
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{ "-v", "-v", "-v" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(u32, 3), result.get("verbose").?.counter);
}

test "Parser inline value" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "output", .short = 'o', .long = "output" }},
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{"--output=result.txt"};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("result.txt", result.getString("output").?);
}

test "Parser positional arguments" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "input", .positional = true, .required = true },
            .{ .name = "output", .positional = true },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{ "input.txt", "output.txt" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("input.txt", result.getString("input").?);
    try std.testing.expectEqualStrings("output.txt", result.getString("output").?);
}

test "Parser default values" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "count", .long = "count", .value_type = .int, .default = "10" }},
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    var result = try parser.parse(&[_][]const u8{});
    defer result.deinit();

    try std.testing.expectEqual(@as(?i64, 10), result.getInt("count"));
}

test "Parser separator handling" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{ .name = "test", .add_help = false, .args = &[_]ArgSpec{} };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{ "--", "--not-option", "regular" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.remaining.items.len);
    try std.testing.expectEqualStrings("--not-option", result.remaining.items[0]);
}

test "Parser argument groups exclusive" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .groups = &[_]schema_mod.ArgumentGroup{
            .{ .name = "mode", .exclusive = true },
        },
        .args = &[_]ArgSpec{
            .{ .name = "server", .long = "server", .action = .store_true, .group = "mode" },
            .{ .name = "client", .long = "client", .action = .store_true, .group = "mode" },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    // Case 1: One option (valid)
    {
        const args = [_][]const u8{"--server"};
        var result = try parser.parse(&args);
        defer result.deinit();
        try std.testing.expect(result.getBool("server").?);
    }

    // Case 2: Both options (invalid)
    {
        const args = [_][]const u8{ "--server", "--client" };
        try std.testing.expectError(errors.ParseError.MutuallyExclusive, parser.parse(&args));
    }
}

test "Parser custom validator" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const Validator = struct {
        fn check(val: []const u8) validation.ValidationResult {
            if (val.len < 3) return .{ .err = "too short" };
            return .{ .ok = {} };
        }
    };

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "name", .long = "name", .validator = Validator.check },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    // Case 1: Valid input
    {
        const args = [_][]const u8{ "--name", "foo" };
        var result = try parser.parse(&args);
        defer result.deinit();
        try std.testing.expectEqualStrings("foo", result.getString("name").?);
    }

    {
        const args = [_][]const u8{ "--name", "fo" };
        try std.testing.expectError(errors.ValidationError.CustomValidationFailed, parser.parse(&args));
    }
}

test "Parser aliases" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "verbose", .long = "verbose", .aliases = &[_][]const u8{ "verb", "lvl" }, .action = .store_true },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    // Original long name
    {
        const args = [_][]const u8{"--verbose"};
        var result = try parser.parse(&args);
        defer result.deinit();
        try std.testing.expect(result.getBool("verbose").?);
    }

    // Alias 1
    {
        const args = [_][]const u8{"--verb"};
        var result = try parser.parse(&args);
        defer result.deinit();
        try std.testing.expect(result.getBool("verbose").?);
    }

    {
        const args = [_][]const u8{"--lvl"};
        var result = try parser.parse(&args);
        defer result.deinit();
        try std.testing.expect(result.getBool("verbose").?);
    }
}

test "Parser environment variables" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "host", .long = "host", .env_var = "TEST_HOST" },
            .{ .name = "port", .long = "port", .value_type = .int, .env_var = "TEST_PORT" },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    // Verify that the parser handles missing environment variables gracefully.
    // Note: Use a mock or specific platform logic for full environment variable testing.
    const args = [_][]const u8{};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expect(result.getString("host") == null);
}
