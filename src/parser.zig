//! Core parsing logic for args.zig.
//! Handles tokenization, validation, and value mapping.

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

/// Internal parser structure that handles the parsing state.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    cfg: Config,
    short_map: std.AutoHashMap(u8, *const ArgSpec),
    long_map: std.StringHashMap(*const ArgSpec),
    long_key_storage: std.ArrayListUnmanaged([]const u8),

    /// Initializes a new parser instance with the given specification.
    pub fn init(allocator: std.mem.Allocator, spec: CommandSpec) !Parser {
        var self = Parser{
            .allocator = allocator,
            .spec = spec,
            .cfg = config_mod.getConfig(),
            .short_map = std.AutoHashMap(u8, *const ArgSpec).init(allocator),
            .long_map = std.StringHashMap(*const ArgSpec).init(allocator),
            .long_key_storage = .empty,
        };

        for (self.spec.args) |*arg| {
            if (arg.short) |s| {
                const key = if (self.cfg.case_sensitive) s else std.ascii.toLower(s);
                try self.short_map.put(key, arg);
            }
            if (arg.long) |l| {
                if (self.cfg.case_sensitive) {
                    try self.long_map.put(l, arg);
                } else {
                    const lowered = try self.copyLower(l);
                    try self.long_map.put(lowered, arg);
                }
            }
            for (arg.aliases) |alias| {
                if (self.cfg.case_sensitive) {
                    try self.long_map.put(alias, arg);
                } else {
                    const lowered = try self.copyLower(alias);
                    try self.long_map.put(lowered, arg);
                }
            }
        }

        return self;
    }

    /// Releases allocations used by the parser maps.
    pub fn deinit(self: *Parser) void {
        for (self.long_key_storage.items) |key| {
            self.allocator.free(key);
        }
        self.long_key_storage.deinit(self.allocator);
        self.short_map.deinit();
        self.long_map.deinit();
    }

    /// Parses the provided argument list.
    pub fn parse(self: *Parser, args: []const []const u8) !ParseResult {
        var result = ParseResult.init(self.allocator);
        errdefer result.deinit();

        for (self.spec.args) |arg| {
            if (arg.default) |def| {
                const value = try self.parseOwnedValue(&result, def, arg.value_type);
                try result.put(arg.getDestination(), value);
            }
        }

        var tokenizer = Tokenizer.initWithOptions(args, .{
            .allow_short_clusters = self.cfg.allow_short_clusters,
            .allow_inline_values = self.cfg.allow_inline_values,
            .allow_interspersed = self.cfg.allow_interspersed,
        });
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
                        try result.remaining.append(self.allocator, try self.copyAndTrackSlice(&result, rem.raw));
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
                    const value = try self.parseOwnedValue(result, env_val, arg.value_type);
                    try result.put(arg.getDestination(), value);
                } else |_| {}
            }
        }
    }

    fn copyLower(self: *Parser, text: []const u8) ![]const u8 {
        const lowered = try self.allocator.dupe(u8, text);
        errdefer self.allocator.free(lowered);
        _ = std.ascii.lowerString(lowered, lowered);
        try self.long_key_storage.append(self.allocator, lowered);
        return lowered;
    }

    fn getLongArgSpec(self: *Parser, name: []const u8) ?*const ArgSpec {
        if (self.cfg.case_sensitive) {
            return self.long_map.get(name);
        }

        var stack_buf: [256]u8 = undefined;
        if (name.len <= stack_buf.len) {
            @memcpy(stack_buf[0..name.len], name);
            _ = std.ascii.lowerString(stack_buf[0..name.len], stack_buf[0..name.len]);
            return self.long_map.get(stack_buf[0..name.len]);
        }

        const lowered = self.allocator.dupe(u8, name) catch return null;
        defer self.allocator.free(lowered);
        _ = std.ascii.lowerString(lowered, lowered);
        return self.long_map.get(lowered);
    }

    fn stripNoPrefix(self: *Parser, name: []const u8) ?[]const u8 {
        if (name.len < 3) return null;

        if (self.cfg.case_sensitive) {
            if (std.mem.startsWith(u8, name, "no-")) return name[3..];
            return null;
        }

        if (std.ascii.toLower(name[0]) == 'n' and std.ascii.toLower(name[1]) == 'o' and name[2] == '-') {
            return name[3..];
        }

        return null;
    }

    const NegatedMatch = struct {
        spec: *const ArgSpec,
        value: bool,
    };

    fn getNegatedLongSpec(self: *Parser, name: []const u8) ?NegatedMatch {
        if (!self.cfg.allow_negated_flags) return null;

        const base_name = self.stripNoPrefix(name) orelse return null;
        const spec = self.getLongArgSpec(base_name) orelse return null;

        return switch (spec.action) {
            .store_true => .{ .spec = spec, .value = false },
            .store_false => .{ .spec = spec, .value = true },
            else => null,
        };
    }

    fn validateChoiceWithCase(self: *Parser, value: []const u8, choices: []const []const u8) bool {
        if (self.cfg.case_sensitive) {
            return validation.validateChoice(value, choices);
        }

        for (choices) |choice| {
            if (std.ascii.eqlIgnoreCase(value, choice)) return true;
        }
        return false;
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

        if (!is_short and !self.cfg.allow_inline_values and utils.contains(name, "=")) {
            return errors.ParseError.InvalidFormat;
        }

        const arg_spec = if (is_short)
            self.short_map.get(if (self.cfg.case_sensitive) name[0] else std.ascii.toLower(name[0]))
        else
            self.getLongArgSpec(name);

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

            if (!is_short) {
                if (self.getNegatedLongSpec(name)) |negated| {
                    try result.put(negated.spec.getDestination(), .{ .boolean = negated.value });
                    return;
                }
            }

            if (self.cfg.parsing_mode == .ignore_unknown) return;

            if (self.cfg.parsing_mode == .permissive) {
                try result.remaining.append(self.allocator, try self.copyAndTrackSlice(result, tok.raw));
                return;
            }

            if (self.cfg.exit_on_error) {
                const prefix = if (is_short) "-" else "--";
                std.debug.print("Error: Unknown option '{s}{s}'\n", .{ prefix, name });

                if (!is_short) {
                    var candidates: std.ArrayListUnmanaged([]const u8) = .empty;
                    defer candidates.deinit(self.allocator);
                    var it = self.long_map.keyIterator();
                    while (it.next()) |k| try candidates.append(self.allocator, k.*);

                    if (utils.findClosest(name, candidates.items, 3)) |sug| {
                        std.debug.print("\n\tDid you mean '--{s}'?\n", .{sug});
                    }
                }
                std.process.exit(1);
            }
            return errors.ParseError.UnknownOption;
        }

        const spec = arg_spec.?;
        const dest = spec.getDestination();

        switch (spec.action) {
            .store_true => try result.put(dest, .{ .boolean = true }),
            .store_false => try result.put(dest, .{ .boolean = false }),
            .count => {
                const current = result.values.get(dest);
                const count: u32 = if (current) |c| blk: {
                    break :blk if (c == .counter) c.counter + 1 else 1;
                } else 1;
                try result.put(dest, .{ .counter = count });
            },
            .callback => {
                const next = tokenizer.peek();
                if (next.token_type != .value) return errors.ParseError.MissingValue;
                _ = tokenizer.next();

                // Validate if needed, but mainly we want to run the callback
                if (spec.validator) |v| {
                    const res = v(next.raw);
                    if (!res.isOk()) {
                        return errors.ValidationError.CustomValidationFailed;
                    }
                }

                if (spec.callback) |cb| {
                    cb(dest, next.raw);
                }

                const value = try self.parseOwnedValue(result, next.raw, spec.value_type);
                try result.put(dest, value);
            },
            .callback_flag => {
                if (spec.callback) |cb| {
                    cb(dest, null);
                }
                // Store as boolean true for the result map
                try result.put(dest, .{ .boolean = true });
            },
            .store, .append => {
                const next = tokenizer.peek();
                if (next.token_type != .value) return errors.ParseError.MissingValue;
                _ = tokenizer.next();
                const value = try self.parseOwnedValue(result, next.raw, spec.value_type);
                if (spec.validator) |v| {
                    const res = v(next.raw);
                    if (!res.isOk()) {
                        return errors.ValidationError.CustomValidationFailed;
                    }
                }
                if (spec.choices.len > 0 and !self.validateChoiceWithCase(next.raw, spec.choices)) {
                    return errors.ParseError.InvalidChoice;
                }
                if (spec.expect.len > 0) {
                    if (!self.validateChoiceWithCase(next.raw, spec.expect)) {
                        if (self.cfg.parsing_mode == .strict) {
                            if (!self.cfg.silent_errors) {
                                std.debug.print("Error: Value '{s}' is not in expected list for argument '{s}'. Expected one of: ", .{ next.raw, spec.name });
                                for (spec.expect, 0..) |expected_val, i| {
                                    std.debug.print("'{s}'", .{expected_val});
                                    if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                                }
                                std.debug.print("\n", .{});
                            }
                            if (self.cfg.exit_on_error) std.process.exit(1);
                            return errors.ParseError.InvalidValue;
                        } else {
                            // Warning mode
                            if (!self.cfg.silent_errors) {
                                std.debug.print("Warning: Value '{s}' is unexpected for argument '{s}'. Expected one of: ", .{ next.raw, spec.name });
                                for (spec.expect, 0..) |expected_val, i| {
                                    std.debug.print("'{s}'", .{expected_val});
                                    if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                                }
                                std.debug.print("\n", .{});
                            }
                        }
                    }
                }

                if (spec.action == .append) {
                    try result.positionals.append(self.allocator, try self.copyAndTrackSlice(result, next.raw));
                } else {
                    try result.put(dest, value);
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

        if (!self.cfg.allow_inline_values) {
            return errors.ParseError.InvalidFormat;
        }

        const arg_spec = self.getLongArgSpec(name) orelse
            if (name.len == 1) self.short_map.get(if (self.cfg.case_sensitive) name[0] else std.ascii.toLower(name[0])) else null;

        if (arg_spec == null) {
            if (self.getNegatedLongSpec(name) != null) {
                return errors.ParseError.InvalidFormat;
            }

            if (self.cfg.parsing_mode == .ignore_unknown) return;

            if (self.cfg.parsing_mode == .permissive) {
                try result.remaining.append(self.allocator, try self.copyAndTrackSlice(result, tok.raw));
                return;
            }

            if (self.cfg.exit_on_error) {
                const prefix = if (name.len == 1) "-" else "--";
                std.debug.print("Error: Unknown option '{s}{s}'\n", .{ prefix, name });

                if (name.len > 1) {
                    var candidates: std.ArrayListUnmanaged([]const u8) = .empty;
                    defer candidates.deinit(self.allocator);
                    var it = self.long_map.keyIterator();
                    while (it.next()) |k| try candidates.append(self.allocator, k.*);

                    if (utils.findClosest(name, candidates.items, 3)) |sug| {
                        std.debug.print("\n\tDid you mean '--{s}'?\n", .{sug});
                    }
                }
                std.process.exit(1);
            }
            return errors.ParseError.UnknownOption;
        }

        const spec = arg_spec.?;
        if (spec.isFlag()) {
            return errors.ParseError.InvalidFormat;
        }

        const dest = spec.getDestination();
        const value = try self.parseOwnedValue(result, value_str, spec.value_type);

        if (spec.validator) |v| {
            const res = v(value_str);
            if (!res.isOk()) {
                return errors.ValidationError.CustomValidationFailed;
            }
        }

        if (spec.choices.len > 0 and !self.validateChoiceWithCase(value_str, spec.choices)) {
            return errors.ParseError.InvalidChoice;
        }

        if (spec.expect.len > 0) {
            if (!self.validateChoiceWithCase(value_str, spec.expect)) {
                if (self.cfg.parsing_mode == .strict) {
                    if (!self.cfg.silent_errors) {
                        std.debug.print("Error: Value '{s}' is not in expected list for argument '{s}'. Expected one of: ", .{ value_str, spec.name });
                        for (spec.expect, 0..) |expected_val, i| {
                            std.debug.print("'{s}'", .{expected_val});
                            if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                        }
                        std.debug.print("\n", .{});
                    }
                    if (self.cfg.exit_on_error) std.process.exit(1);
                    return errors.ParseError.InvalidValue;
                } else {
                    if (!self.cfg.silent_errors) {
                        std.debug.print("Warning: Value '{s}' is unexpected for argument '{s}'. Expected one of: ", .{ value_str, spec.name });
                        for (spec.expect, 0..) |expected_val, i| {
                            std.debug.print("'{s}'", .{expected_val});
                            if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                        }
                        std.debug.print("\n", .{});
                    }
                }
            }
        }

        try result.put(dest, value);
    }

    fn handlePositional(self: *Parser, value_str: []const u8, index: usize, result: *ParseResult) !void {
        var pos_idx: usize = 0;
        for (self.spec.args) |arg| {
            if (arg.positional) {
                if (pos_idx == index) {
                    const value = try self.parseOwnedValue(result, value_str, arg.value_type);
                    if (arg.validator) |v| {
                        const res = v(value_str);
                        if (!res.isOk()) {
                            return errors.ValidationError.CustomValidationFailed;
                        }
                    }
                    if (arg.choices.len > 0 and !self.validateChoiceWithCase(value_str, arg.choices)) {
                        return errors.ParseError.InvalidChoice;
                    }
                    if (arg.expect.len > 0 and !self.validateChoiceWithCase(value_str, arg.expect)) {
                        if (self.cfg.parsing_mode == .strict) {
                            return errors.ParseError.InvalidValue;
                        }
                    }
                    try result.put(arg.getDestination(), value);
                    return;
                }
                pos_idx += 1;
            }
        }
        try result.positionals.append(self.allocator, try self.copyAndTrackSlice(result, value_str));
    }

    fn copyAndTrackSlice(self: *Parser, result: *ParseResult, value: []const u8) ![]const u8 {
        const owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned);
        try result.ownSlice(owned);
        return owned;
    }

    fn parseOwnedValue(self: *Parser, result: *ParseResult, raw: []const u8, value_type: types.ValueType) !ParsedValue {
        const owned = try self.copyAndTrackSlice(result, raw);
        return validation.parseValue(owned, value_type, self.allocator);
    }

    fn validateRequired(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (arg.required and !result.contains(arg.getDestination())) {
                return errors.ParseError.MissingRequired;
            }
        }
    }
};

/// Convenience function to parse arguments with a single call.
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

test "Parser owns parsed string memory" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "input", .short = 'i', .long = "input", .required = true },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    var args_list: std.ArrayListUnmanaged([]const u8) = .empty;

    try args_list.append(arena.allocator(), try arena.allocator().dupe(u8, "-i"));
    try args_list.append(arena.allocator(), try arena.allocator().dupe(u8, "./canvas/0001.xml"));

    var result = try parser.parse(args_list.items);
    defer result.deinit();

    // Free source argv buffers to verify ParseResult owns the parsed strings.
    args_list.deinit(arena.allocator());
    arena.deinit();

    try std.testing.expectEqualStrings("./canvas/0001.xml", result.getString("input").?);
}

test "Parser case-insensitive long options" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .case_sensitive = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "verbose", .long = "verbose", .action = .store_true },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{"--VERBOSE"};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expect(result.getBool("verbose").?);
}

test "Parser permissive unknown options" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .parsing_mode = .permissive });
    defer config_mod.resetConfig();

    const spec = CommandSpec{ .name = "test", .add_help = false, .args = &[_]ArgSpec{} };
    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{"--unknown"};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.remaining.items.len);
    try std.testing.expectEqualStrings("--unknown", result.remaining.items[0]);
}

test "Parser ignore unknown options" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .parsing_mode = .ignore_unknown });
    defer config_mod.resetConfig();

    const spec = CommandSpec{ .name = "test", .add_help = false, .args = &[_]ArgSpec{} };
    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{"--unknown"};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.remaining.items.len);
}

test "Parser disable interspersed options" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .allow_interspersed = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "verbose", .long = "verbose", .action = .store_true },
            .{ .name = "input", .positional = true },
        },
    };
    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{ "file.txt", "--verbose" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqualStrings("file.txt", result.getString("input").?);
    try std.testing.expect(result.getBool("verbose") == null);
    try std.testing.expectEqual(@as(usize, 1), result.positionals.items.len);
    try std.testing.expectEqualStrings("--verbose", result.positionals.items[0]);
}

test "Parser disable short clusters" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .allow_short_clusters = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{ .name = "test", .add_help = false, .args = &[_]ArgSpec{} };
    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const args = [_][]const u8{"-abc"};
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.positionals.items.len);
    try std.testing.expectEqualStrings("-abc", result.positionals.items[0]);
}

test "Parser supports negated long flags" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .allow_negated_flags = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "cache", .long = "cache", .action = .store_true },
            .{ .name = "color", .long = "color", .action = .store_false },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    {
        const argv = [_][]const u8{ "--no-cache", "--no-color" };
        var result = try parser.parse(&argv);
        defer result.deinit();

        try std.testing.expectEqual(@as(?bool, false), result.getBool("cache"));
        try std.testing.expectEqual(@as(?bool, true), result.getBool("color"));
    }
}

test "Parser rejects negated long flags when disabled" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .allow_negated_flags = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "cache", .long = "cache", .action = .store_true },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const argv = [_][]const u8{"--no-cache"};
    try std.testing.expectError(errors.ParseError.UnknownOption, parser.parse(&argv));
}

test "Parser case-insensitive choices when case_sensitive false" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .case_sensitive = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "level", .long = "level", .choices = &[_][]const u8{ "debug", "info" } },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    const argv = [_][]const u8{ "--level", "DEBUG" };
    var result = try parser.parse(&argv);
    defer result.deinit();

    try std.testing.expectEqualStrings("DEBUG", result.getString("level").?);
}

test "Parser validates positional choices" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "mode", .positional = true, .required = true, .choices = &[_][]const u8{ "dev", "prod" } },
        },
    };

    var parser = try Parser.init(allocator, spec);
    defer parser.deinit();

    {
        const argv = [_][]const u8{"dev"};
        var result = try parser.parse(&argv);
        defer result.deinit();
        try std.testing.expectEqualStrings("dev", result.getString("mode").?);
    }

    {
        const argv = [_][]const u8{"staging"};
        try std.testing.expectError(errors.ParseError.InvalidChoice, parser.parse(&argv));
    }
}
