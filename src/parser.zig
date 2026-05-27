//! Core parsing logic for args.zig.
//! Handles tokenization, validation, and value mapping.

const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const schema_mod = @import("schema.zig");
const tokenizer_mod = @import("tokenizer.zig");
const validation = @import("validation.zig");
const errors = @import("errors.zig");
const help = @import("help.zig");
const config_mod = @import("config.zig");
const utils = @import("utils.zig");
const constants = @import("constants.zig");

pub const ParseResult = types.ParseResult;
pub const ParsedValue = types.ParsedValue;
pub const ArgSpec = schema_mod.ArgSpec;
pub const CommandSpec = schema_mod.CommandSpec;
pub const Tokenizer = tokenizer_mod.Tokenizer;
pub const Token = tokenizer_mod.Token;
pub const TokenType = tokenizer_mod.TokenType;
pub const Config = config_mod.Config;
const DecodedInput = validation.DecodedValue;

/// Internal parser structure that handles the parsing state.
pub const Parser = struct {
    allocator: std.mem.Allocator,
    spec: CommandSpec,
    cfg: Config,
    io: std.Io,
    env_map: ?*const std.process.Environ.Map,
    short_map: std.AutoHashMap(u8, *const ArgSpec),
    long_map: std.StringHashMap(*const ArgSpec),
    long_key_storage: std.ArrayList([]const u8),

    /// Initializes a new parser instance with the given specification.
    pub fn init(allocator: std.mem.Allocator, spec: CommandSpec, io: std.Io, env_map: ?*const std.process.Environ.Map) !Parser {
        return initWithConfig(allocator, spec, io, env_map, config_mod.getConfig());
    }

    pub fn initWithConfig(allocator: std.mem.Allocator, spec: CommandSpec, io: std.Io, env_map: ?*const std.process.Environ.Map, cfg: config_mod.Config) !Parser {
        var self = Parser{
            .allocator = allocator,
            .spec = spec,
            .cfg = cfg,
            .io = io,
            .env_map = env_map,
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

        var explicit_seen = std.StringHashMap(void).init(self.allocator);
        defer explicit_seen.deinit();

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
                .long_option => try self.handleOption(tok, &tokenizer, &result, &explicit_seen, false),
                .short_option => try self.handleOption(tok, &tokenizer, &result, &explicit_seen, true),
                .option_with_value => try self.handleOptionWithValue(tok, &result, &explicit_seen),
                .value => {
                    if (positional_index == 0 and self.spec.subcommands.len > 0) {
                        for (self.spec.subcommands) |sub| {
                            if (utils.eql(tok.raw, sub.name)) {
                                result.subcommand = sub.name;
                                var sub_parser = try Parser.init(self.allocator, .{
                                    .name = sub.name,
                                    .args = sub.args,
                                    .subcommands = sub.subcommands,
                                }, self.io, self.env_map);
                                defer sub_parser.deinit();
                                const sub_result = try sub_parser.parse(tokenizer.remaining());
                                result.subcommand_args = try self.allocator.create(ParseResult);
                                result.subcommand_args.?.* = sub_result;
                                return result;
                            }
                        }

                        if (!self.hasPositionalAt(0)) {
                            switch (self.cfg.parsing_mode) {
                                .strict => {
                                    self.printUnknownSubcommandAndMaybeExit(tok.raw);
                                    return errors.ParseError.UnknownSubcommand;
                                },
                                .interspersed => {
                                    self.printUnknownSubcommandAndMaybeExit(tok.raw);
                                    return errors.ParseError.UnknownSubcommand;
                                },
                                .permissive => {
                                    try self.appendUnknownAsRemaining(&result, tok.raw);
                                    continue;
                                },
                                .ignore_unknown => continue,
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
        self.validateDeprecations(&result);
        try self.validateConflicts(&result);
        try self.validateRequires(&result);
        try self.validateRequiredIf(&result);
        try self.validateMutualExclusions(&result);
        try self.validateGroups(&result);
        return result;
    }

    fn processEnvVars(self: *Parser, result: *ParseResult) !void {
        const env_map = self.env_map orelse return;
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
                if (env_map.get(key)) |env_val| {
                    const value = try self.parseOwnedValue(result, env_val, arg.value_type);
                    try result.put(arg.getDestination(), value);
                }
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

    fn normalizeShortKey(self: *Parser, key: u8) u8 {
        return if (self.cfg.case_sensitive) key else std.ascii.toLower(key);
    }

    fn appendUnknownAsRemaining(self: *Parser, result: *ParseResult, raw: []const u8) !void {
        try result.remaining.append(self.allocator, try self.copyAndTrackSlice(result, raw));
    }

    fn decodeInputForSpec(self: *Parser, spec: *const ArgSpec, raw: []const u8) !DecodedInput {
        return validation.decodeValueForMode(self.allocator, raw, spec.decode_mode) catch return errors.ParseError.InvalidValue;
    }

    fn hasPositionalAt(self: *Parser, target_index: usize) bool {
        var positional_index: usize = 0;
        for (self.spec.args) |arg| {
            if (!arg.positional) continue;
            if (positional_index == target_index) return true;
            positional_index += 1;
        }
        return false;
    }

    fn emitError(self: *Parser, comptime fmt: []const u8, args_tuple: anytype) void {
        if (self.cfg.silent_errors) return;
        const theme = utils.resolveTheme(self.cfg.use_colors, self.cfg.colors);
        std.debug.print("{s}{s}{s}: ", .{ theme.error_color, self.cfg.error_prefix, theme.reset });
        std.debug.print(fmt, args_tuple);
    }

    fn emitWarning(self: *Parser, comptime fmt: []const u8, args_tuple: anytype) void {
        if (self.cfg.silent_errors) return;
        const theme = utils.resolveTheme(self.cfg.use_colors, self.cfg.colors);
        std.debug.print("{s}{s}{s}: ", .{ theme.warning, self.cfg.warning_prefix, theme.reset });
        std.debug.print(fmt, args_tuple);
    }

    fn emitClosestSuggestion(self: *Parser, entered: []const u8, candidates: []const []const u8, prefix: []const u8) void {
        if (!self.cfg.suggest_closest) return;
        if (utils.findClosest(entered, candidates, self.cfg.suggestion_max_distance)) |sug| {
            if (!self.cfg.silent_errors) {
                std.debug.print(constants.ParserMessages.did_you_mean, .{ prefix, sug });
            }
        }
    }

    fn emitClosestSuggestionWithArgHint(self: *Parser, spec: *const ArgSpec, entered: []const u8, candidates: []const []const u8, prefix: []const u8) void {
        if (spec.suggestion_hint) |hint| {
            if (!self.cfg.silent_errors) std.debug.print(constants.ParserMessages.hint, .{hint});
            return;
        }
        self.emitClosestSuggestion(entered, candidates, prefix);
    }

    fn emitUnknownOptionFeedback(self: *Parser, name: []const u8, is_short: bool) void {
        const prefix = if (is_short) "-" else "--";
        if (self.cfg.unknown_option_message) |custom| {
            self.emitError("{s}\n", .{custom});
        } else {
            self.emitError(constants.ParserMessages.unknown_option, .{ prefix, name });
        }

        if (self.cfg.unknown_option_hint) |hint| {
            if (!self.cfg.silent_errors) std.debug.print(constants.ParserMessages.hint, .{hint});
            return;
        }

        if (!is_short and self.cfg.suggest_closest) {
            var candidates: std.ArrayList([]const u8) = .empty;
            defer candidates.deinit(self.allocator);
            var it = self.long_map.keyIterator();
            while (it.next()) |k| candidates.append(self.allocator, k.*) catch break;

            if (self.cfg.suggest_builtin_commands) {
                // Include built-in pseudo options so typos like --verison can be corrected.
                candidates.append(self.allocator, constants.Builtins.help) catch {};
                candidates.append(self.allocator, constants.Builtins.version) catch {};
            }

            self.emitClosestSuggestion(name, candidates.items, "--");
        }
    }

    fn emitUnknownSubcommandFeedback(self: *Parser, entered: []const u8) void {
        if (self.cfg.unknown_subcommand_message) |custom| {
            self.emitError("{s}\n", .{custom});
        } else {
            self.emitError(constants.ParserMessages.unknown_subcommand, .{entered});
        }

        if (self.cfg.unknown_subcommand_hint) |hint| {
            if (!self.cfg.silent_errors) std.debug.print(constants.ParserMessages.hint, .{hint});
            return;
        }

        if (self.cfg.suggest_closest and self.cfg.suggest_subcommands) {
            var candidates: std.ArrayList([]const u8) = .empty;
            defer candidates.deinit(self.allocator);
            for (self.spec.subcommands) |sub| candidates.append(self.allocator, sub.name) catch break;
            self.emitClosestSuggestion(entered, candidates.items, "");
        }
    }

    fn printUnknownSubcommandAndMaybeExit(self: *Parser, entered: []const u8) void {
        self.emitUnknownSubcommandFeedback(entered);
        if (self.cfg.exit_on_error) std.process.exit(1);
    }

    fn printUnknownOptionAndMaybeExit(self: *Parser, name: []const u8, is_short: bool) void {
        self.emitUnknownOptionFeedback(name, is_short);
        std.process.exit(1);
    }

    fn handleUnknownOption(self: *Parser, result: *ParseResult, raw: []const u8, name: []const u8, is_short: bool) !void {
        if (self.cfg.parsing_mode == .ignore_unknown) return;

        if (self.cfg.parsing_mode == .permissive) {
            try self.appendUnknownAsRemaining(result, raw);
            return;
        }

        if (self.cfg.exit_on_error) {
            self.printUnknownOptionAndMaybeExit(name, is_short);
        } else {
            self.emitUnknownOptionFeedback(name, is_short);
        }
        return errors.ParseError.UnknownOption;
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

            if (group.exclusive and found_count > 1) {
                self.emitError(constants.HelpFormat.group_exclusive_error, .{group.name});
                if (self.cfg.exit_on_error) std.process.exit(1);
                return errors.ParseError.MutuallyExclusive;
            }
            if (group.required and found_count == 0) {
                if (self.cfg.exit_on_error) {
                    const help_text = help.generateHelpWithConfig(self.allocator, self.spec, self.cfg.use_colors, self.cfg) catch std.process.exit(1);
                    std.debug.print("{s}", .{help_text});
                    self.allocator.free(help_text);
                    std.process.exit(1);
                }
                return errors.ParseError.MissingRequired;
            }
        }
    }

    fn isRepeatableAction(action: types.ArgAction) bool {
        return switch (action) {
            .append, .count, .extend, .callback_flag => true,
            else => false,
        };
    }

    fn checkDuplicateArgument(
        self: *Parser,
        spec: *const ArgSpec,
        seen: *std.StringHashMap(void),
        dest: []const u8,
    ) !void {
        _ = self;
        if (isRepeatableAction(spec.action)) return;
        if (seen.contains(dest)) return errors.ParseError.DuplicateArgument;
        try seen.put(dest, {});
    }

    fn handleOption(
        self: *Parser,
        tok: Token,
        tokenizer: *Tokenizer,
        result: *ParseResult,
        seen: *std.StringHashMap(void),
        is_short: bool,
    ) !void {
        const name = tok.name orelse return errors.ParseError.InvalidFormat;

        if (!is_short and !self.cfg.allow_inline_values and utils.contains(name, "=")) {
            return errors.ParseError.InvalidFormat;
        }

        const arg_spec = if (is_short)
            self.short_map.get(self.normalizeShortKey(name[0]))
        else
            self.getLongArgSpec(name);

        if (arg_spec == null) {
            if (!is_short and utils.eql(name, constants.Builtins.help)) {
                const help_text = try help.generateHelpWithConfig(self.allocator, self.spec, self.cfg.use_colors, self.cfg);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (!is_short and utils.eql(name, constants.Builtins.version)) {
                std.debug.print(constants.HelpFormat.version_format, .{ self.spec.name, self.spec.version orelse constants.Defaults.unknown_version });
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (is_short and name[0] == 'h') {
                const help_text = try help.generateHelpWithConfig(self.allocator, self.spec, self.cfg.use_colors, self.cfg);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }
            if (is_short and name[0] == 'V') {
                std.debug.print(constants.HelpFormat.version_format, .{ self.spec.name, self.spec.version orelse constants.Defaults.unknown_version });
                if (self.cfg.exit_on_error) std.process.exit(0);
                return;
            }

            if (!is_short) {
                if (self.getNegatedLongSpec(name)) |negated| {
                    try self.checkDuplicateArgument(negated.spec, seen, negated.spec.getDestination());
                    try result.put(negated.spec.getDestination(), .{ .boolean = negated.value });
                    return;
                }
            }

            return self.handleUnknownOption(result, tok.raw, name, is_short);
        }

        const spec = arg_spec.?;
        const dest = spec.getDestination();

        switch (spec.action) {
            .store_true => {
                try self.checkDuplicateArgument(spec, seen, dest);
                try result.put(dest, .{ .boolean = true });
            },
            .store_false => {
                try self.checkDuplicateArgument(spec, seen, dest);
                try result.put(dest, .{ .boolean = false });
            },
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
                const decoded = self.decodeInputForSpec(spec, next.raw) catch {
                    if (spec.custom_error_message) |custom| {
                        self.emitError("{s}\n", .{custom});
                    } else {
                        self.emitError(constants.ParserMessages.decode_failed, .{spec.name});
                    }
                    return errors.ParseError.InvalidValue;
                };
                defer decoded.deinit(self.allocator);

                // Validate if needed, but mainly we want to run the callback
                if (spec.validator) |v| {
                    const res = v(self.io, decoded.value);
                    if (!res.isOk()) {
                        if (res.getMessage()) |msg| {
                            if (spec.custom_error_message) |custom| {
                                self.emitError("{s}\n", .{custom});
                            } else {
                                self.emitError("{s}\n", .{msg});
                            }
                        }
                        return errors.ValidationError.CustomValidationFailed;
                    }
                }

                if (spec.callback) |cb| {
                    cb(dest, decoded.value);
                }

                try self.checkDuplicateArgument(spec, seen, dest);
                const value = try self.parseOwnedValue(result, decoded.value, spec.value_type);
                try result.put(dest, value);
            },
            .callback_flag => {
                if (spec.callback) |cb| {
                    cb(dest, null);
                }
                try self.checkDuplicateArgument(spec, seen, dest);
                // Store as boolean true for the result map
                try result.put(dest, .{ .boolean = true });
            },
            .store, .append => {
                if (spec.nargs.isVariadic() and spec.action != .append) {
                    const value = try self.parseVariadicValues(tokenizer, result, spec);
                    if (spec.validator) |v| {
                        if (value == .array and value.array.len > 0) {
                            const res = v(self.io, value.array[0]);
                            if (!res.isOk()) {
                                if (res.getMessage()) |msg| self.emitError("{s}\n", .{msg});
                                return errors.ValidationError.CustomValidationFailed;
                            }
                        }
                    }
                    try self.checkDuplicateArgument(spec, seen, dest);
                    try result.put(dest, value);
                } else {
                    const next = tokenizer.peek();
                    if (next.token_type != .value) return errors.ParseError.MissingValue;
                    _ = tokenizer.next();
                    const decoded = self.decodeInputForSpec(spec, next.raw) catch {
                        if (spec.custom_error_message) |custom| {
                            self.emitError("{s}\n", .{custom});
                        } else {
                            self.emitError(constants.ParserMessages.decode_failed, .{spec.name});
                        }
                        return errors.ParseError.InvalidValue;
                    };
                    defer decoded.deinit(self.allocator);
                    const value = if (spec.value_type == .array and spec.separator != 0)
                        try self.parseOwnedArrayValue(result, decoded.value, spec.separator)
                    else
                        try self.parseOwnedValue(result, decoded.value, spec.value_type);
                    if (spec.validator) |v| {
                        const res = v(self.io, decoded.value);
                        if (!res.isOk()) {
                            return errors.ValidationError.CustomValidationFailed;
                        }
                    }
                    if (spec.choices.len > 0 and !self.validateChoiceWithCase(decoded.value, spec.choices)) {
                        if (spec.custom_error_message) |custom| {
                            self.emitError("{s}\n", .{custom});
                        } else {
                            self.emitError(constants.ParserMessages.invalid_choice, .{ decoded.value, spec.name });
                        }
                        self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.choices, "");
                        return errors.ParseError.InvalidChoice;
                    }
                    if (spec.expect.len > 0) {
                        if (!self.validateChoiceWithCase(decoded.value, spec.expect)) {
                            if (self.cfg.parsing_mode == .strict) {
                                if (spec.custom_error_message) |custom| {
                                    self.emitError("{s}\n", .{custom});
                                } else {
                                    self.emitError(constants.ParserMessages.expected_one_of, .{ decoded.value, spec.name });
                                }
                                if (!self.cfg.silent_errors) {
                                    if (spec.custom_error_message == null) {
                                        for (spec.expect, 0..) |expected_val, i| {
                                            std.debug.print("'{s}'", .{expected_val});
                                            if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                                        }
                                        std.debug.print("\n", .{});
                                    }
                                }
                                self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.expect, "");
                                if (self.cfg.exit_on_error) std.process.exit(1);
                                return errors.ParseError.InvalidValue;
                            } else {
                                if (spec.custom_error_message) |custom| {
                                    self.emitWarning("{s}\n", .{custom});
                                } else {
                                    self.emitWarning(constants.ParserMessages.unexpected_value, .{ decoded.value, spec.name });
                                }
                                if (!self.cfg.silent_errors) {
                                    if (spec.custom_error_message == null) {
                                        for (spec.expect, 0..) |expected_val, i| {
                                            std.debug.print("'{s}'", .{expected_val});
                                            if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                                        }
                                        std.debug.print("\n", .{});
                                    }
                                }
                                self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.expect, "");
                            }
                        }
                    }
                    if (spec.action == .append) {
                        try self.appendToResultArray(result, spec.getDestination(), decoded.value);
                    } else {
                        try self.checkDuplicateArgument(spec, seen, dest);
                        try result.put(dest, value);
                    }
                }
            },
            .help => {
                const help_text = try help.generateHelpWithConfig(self.allocator, self.spec, self.cfg.use_colors, self.cfg);
                std.debug.print("{s}", .{help_text});
                self.allocator.free(help_text);
                if (self.cfg.exit_on_error) std.process.exit(0);
            },
            .version => {
                std.debug.print(constants.HelpFormat.version_format, .{ self.spec.name, self.spec.version orelse constants.Defaults.unknown_version });
                if (self.cfg.exit_on_error) std.process.exit(0);
            },
            else => {},
        }
    }

    fn handleOptionWithValue(
        self: *Parser,
        tok: Token,
        result: *ParseResult,
        seen: *std.StringHashMap(void),
    ) !void {
        const name = tok.name orelse return errors.ParseError.InvalidFormat;
        const value_str = tok.inline_value orelse return errors.ParseError.MissingValue;

        if (!self.cfg.allow_inline_values) {
            return errors.ParseError.InvalidFormat;
        }

        const arg_spec = self.getLongArgSpec(name) orelse
            if (name.len == 1) self.short_map.get(self.normalizeShortKey(name[0])) else null;

        if (arg_spec == null) {
            if (self.getNegatedLongSpec(name) != null) {
                return errors.ParseError.InvalidFormat;
            }

            return self.handleUnknownOption(result, tok.raw, name, name.len == 1);
        }

        const spec = arg_spec.?;
        if (spec.isFlag()) {
            return errors.ParseError.InvalidFormat;
        }

        const dest = spec.getDestination();
        const decoded = self.decodeInputForSpec(spec, value_str) catch {
            if (spec.custom_error_message) |custom| {
                self.emitError("{s}\n", .{custom});
            } else {
                self.emitError(constants.ParserMessages.decode_failed, .{spec.name});
            }
            return errors.ParseError.InvalidValue;
        };
        defer decoded.deinit(self.allocator);

        const value = if (spec.value_type == .array and spec.separator != 0)
            try self.parseOwnedArrayValue(result, decoded.value, spec.separator)
        else
            try self.parseOwnedValue(result, decoded.value, spec.value_type);

        if (spec.validator) |v| {
            const res = v(self.io, decoded.value);
            if (!res.isOk()) {
                if (res.getMessage()) |msg| {
                    if (spec.custom_error_message) |custom| {
                        self.emitError("{s}\n", .{custom});
                    } else {
                        self.emitError("{s}\n", .{msg});
                    }
                }
                return errors.ValidationError.CustomValidationFailed;
            }
        }

        if (spec.choices.len > 0 and !self.validateChoiceWithCase(decoded.value, spec.choices)) {
            if (spec.custom_error_message) |custom| {
                self.emitError("{s}\n", .{custom});
            } else {
                self.emitError(constants.ParserMessages.invalid_choice, .{ decoded.value, spec.name });
            }
            self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.choices, "");
            return errors.ParseError.InvalidChoice;
        }

        if (spec.expect.len > 0) {
            if (!self.validateChoiceWithCase(decoded.value, spec.expect)) {
                if (self.cfg.parsing_mode == .strict) {
                    if (spec.custom_error_message) |custom| {
                        self.emitError("{s}\n", .{custom});
                    } else {
                        self.emitError(constants.ParserMessages.expected_one_of, .{ decoded.value, spec.name });
                    }
                    if (!self.cfg.silent_errors) {
                        if (spec.custom_error_message == null) {
                            for (spec.expect, 0..) |expected_val, i| {
                                std.debug.print("'{s}'", .{expected_val});
                                if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                            }
                            std.debug.print("\n", .{});
                        }
                    }
                    self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.expect, "");
                    if (self.cfg.exit_on_error) std.process.exit(1);
                    return errors.ParseError.InvalidValue;
                } else {
                    if (spec.custom_error_message) |custom| {
                        self.emitWarning("{s}\n", .{custom});
                    } else {
                        self.emitWarning(constants.ParserMessages.unexpected_value, .{ decoded.value, spec.name });
                    }
                    if (!self.cfg.silent_errors) {
                        if (spec.custom_error_message == null) {
                            for (spec.expect, 0..) |expected_val, i| {
                                std.debug.print("'{s}'", .{expected_val});
                                if (i < spec.expect.len - 1) std.debug.print(", ", .{});
                            }
                            std.debug.print("\n", .{});
                        }
                    }
                    self.emitClosestSuggestionWithArgHint(spec, decoded.value, spec.expect, "");
                }
            }
        }

        try self.checkDuplicateArgument(spec, seen, dest);
        try result.put(dest, value);
    }

    fn handlePositional(self: *Parser, value_str: []const u8, index: usize, result: *ParseResult) !void {
        var pos_idx: usize = 0;
        for (self.spec.args) |arg| {
            if (arg.positional) {
                if (pos_idx == index) {
                    const decoded = self.decodeInputForSpec(&arg, value_str) catch return errors.ParseError.InvalidValue;
                    defer decoded.deinit(self.allocator);

                    const value = try self.parseOwnedValue(result, decoded.value, arg.value_type);
                    if (arg.validator) |v| {
                        const res = v(self.io, decoded.value);
                        if (!res.isOk()) {
                            return errors.ValidationError.CustomValidationFailed;
                        }
                    }
                    if (arg.choices.len > 0 and !self.validateChoiceWithCase(decoded.value, arg.choices)) {
                        return errors.ParseError.InvalidChoice;
                    }
                    if (arg.expect.len > 0 and !self.validateChoiceWithCase(decoded.value, arg.expect)) {
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

    fn parseOwnedArrayValue(self: *Parser, result: *ParseResult, raw: []const u8, separator: u8) !ParsedValue {
        // Strip brackets if enabled
        const inner = if (self.cfg.allow_brackets) (utils.stripBrackets(raw) orelse raw) else raw;

        var count: usize = 0;
        {
            var it = std.mem.splitScalar(u8, inner, separator);
            while (it.next()) |part| {
                if (std.mem.trim(u8, part, " ").len > 0) count += 1;
            }
        }

        const raw_buf = try self.allocator.alloc(u8, count * @sizeOf([]const u8));
        errdefer self.allocator.free(raw_buf);

        const buf: [][]const u8 = @ptrCast(@alignCast(raw_buf));

        var idx: usize = 0;
        var it = std.mem.splitScalar(u8, inner, separator);
        while (it.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len > 0) {
                buf[idx] = try self.copyAndTrackSlice(result, trimmed);
                idx += 1;
            }
        }

        try result.ownSlice(raw_buf);
        return .{ .array = buf[0..count] };
    }

    /// Parse zero or more values into an array.
    fn parseVariadicValues(self: *Parser, tokenizer: *Tokenizer, result: *ParseResult, spec: *const ArgSpec) !ParsedValue {
        // First pass: count values
        var count: usize = 0;
        const nargs = spec.nargs;
        const max = nargs.maxCount();
        const is_remainder = nargs == .remainder;
        var saved_indices: std.ArrayList(usize) = .empty;

        while (true) {
            if (max) |m| if (count >= m) break;
            const next = tokenizer.peek();
            if (next.token_type == .end or next.token_type == .separator) break;
            if (!is_remainder and (next.token_type == .long_option or next.token_type == .short_option or next.token_type == .short_cluster or next.token_type == .option_with_value)) break;
            _ = tokenizer.next();
            try saved_indices.append(self.allocator, tokenizer.index - 1);
            count += 1;
        }

        if (count < nargs.minCount()) {
            return errors.ParseError.MissingValue;
        }

        // Allocate and collect values
        const buf = try self.allocator.alloc(u8, count * @sizeOf([]const u8));
        errdefer self.allocator.free(buf);
        const items: [][]const u8 = @ptrCast(@alignCast(buf));

        for (saved_indices.items, 0..) |idx, i| {
            const decoded = if (self.cfg.allow_brackets)
                (utils.stripBrackets(tokenizer.args[idx]) orelse tokenizer.args[idx])
            else
                tokenizer.args[idx];
            items[i] = try self.copyAndTrackSlice(result, decoded);
        }
        saved_indices.deinit(self.allocator);

        try result.ownSlice(buf);
        return .{ .array = items[0..count] };
    }

    /// Append a value to an array in the result, creating the array if needed.
    fn appendToResultArray(self: *Parser, result: *ParseResult, dest: []const u8, raw_value: []const u8) !void {
        const owned = try self.copyAndTrackSlice(result, raw_value);
        const old_arr = if (result.get(dest)) |existing|
            if (existing == .array) existing.array else null
        else
            null;

        const new_len = if (old_arr) |a| a.len + 1 else 1;
        const raw_buf = try self.allocator.alloc(u8, new_len * @sizeOf([]const u8));
        errdefer self.allocator.free(raw_buf);
        const buf: [][]const u8 = @ptrCast(@alignCast(raw_buf));
        if (old_arr) |a| {
            for (a, 0..) |item, i| buf[i] = item;
        }
        buf[new_len - 1] = owned;
        try result.ownSlice(raw_buf);
        try result.put(dest, .{ .array = buf[0..new_len] });
    }

    fn findArgSpec(self: *const Parser, name: []const u8) ?ArgSpec {
        for (self.spec.args) |arg| {
            if (std.mem.eql(u8, arg.name, name)) return arg;
            if (arg.long) |l| {
                if (std.mem.eql(u8, l, name)) return arg;
            }
            if (arg.dest) |d| {
                if (std.mem.eql(u8, d, name)) return arg;
            }
        }
        return null;
    }

    fn validateRequired(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (arg.required and !result.contains(arg.getDestination())) {
                if (self.cfg.exit_on_error) {
                    const help_text = help.generateHelpWithConfig(self.allocator, self.spec, self.cfg.use_colors, self.cfg) catch std.process.exit(1);
                    std.debug.print("{s}", .{help_text});
                    self.allocator.free(help_text);
                    std.process.exit(1);
                }
                return errors.ParseError.MissingRequired;
            }
        }
    }

    fn validateDeprecations(self: *Parser, result: *ParseResult) void {
        for (self.spec.args) |arg| {
            if (arg.deprecated) |reason| {
                if (result.contains(arg.getDestination())) {
                    if (arg.positional) {
                        self.emitWarning(constants.DeprecationMessages.deprecated_positional, .{ arg.name, reason });
                    } else {
                        if (reason.len > 0) {
                            self.emitWarning(constants.DeprecationMessages.deprecated_arg, .{ arg.name, reason });
                        } else {
                            self.emitWarning(constants.DeprecationMessages.deprecated_arg_no_reason, .{arg.name});
                        }
                    }
                }
            }
        }
    }

    fn validateConflicts(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (result.contains(arg.getDestination())) {
                for (arg.conflicts_with) |conflict_name| {
                    if (self.findArgSpec(conflict_name)) |conflict_arg| {
                        if (result.contains(conflict_arg.getDestination())) {
                            // Check for circular conflict
                            var is_circular = false;
                            for (conflict_arg.conflicts_with) |c_name| {
                                if (std.mem.eql(u8, c_name, arg.name) or
                                    (arg.long != null and std.mem.eql(u8, c_name, arg.long.?)))
                                {
                                    is_circular = true;
                                    break;
                                }
                            }

                            if (is_circular) {
                                self.emitError(constants.DependencyMessages.circular_conflict_warn, .{ arg.name, conflict_arg.name });
                                if (self.cfg.exit_on_error) std.process.exit(1);
                                return errors.ParseError.CircularConflict;
                            } else {
                                self.emitError(constants.ConflictMessages.conflict_error, .{ arg.name, conflict_arg.name });
                                if (!self.cfg.silent_errors) {
                                    std.debug.print(constants.ConflictMessages.conflict_hint, .{});
                                }
                                if (self.cfg.exit_on_error) std.process.exit(1);
                                return errors.ParseError.ConflictingArguments;
                            }
                        }
                    } else {
                        if (result.contains(conflict_name)) {
                            self.emitError(constants.ConflictMessages.conflict_error, .{ arg.name, conflict_name });
                            if (!self.cfg.silent_errors) {
                                std.debug.print(constants.ConflictMessages.conflict_hint, .{});
                            }
                            if (self.cfg.exit_on_error) std.process.exit(1);
                            return errors.ParseError.ConflictingArguments;
                        }
                    }
                }
            }
        }
    }

    fn validateRequires(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            if (result.contains(arg.getDestination())) {
                for (arg.requires) |req_name| {
                    var found = false;
                    if (self.findArgSpec(req_name)) |req_arg| {
                        if (result.contains(req_arg.getDestination())) {
                            found = true;
                        }
                    } else {
                        if (result.contains(req_name)) {
                            found = true;
                        }
                    }

                    if (!found) {
                        self.emitError(constants.DependencyMessages.requires_error, .{ arg.name, req_name });
                        if (!self.cfg.silent_errors) {
                            std.debug.print(constants.DependencyMessages.dependency_hint, .{});
                        }
                        if (self.cfg.exit_on_error) std.process.exit(1);
                        return errors.ParseError.MissingDependency;
                    }
                }
            }
        }
    }

    fn validateRequiredIf(self: *Parser, result: *ParseResult) !void {
        for (self.spec.args) |arg| {
            for (arg.required_if) |req| {
                var triggered = false;
                if (self.findArgSpec(req.when_arg)) |when_spec| {
                    const dest = when_spec.getDestination();
                    if (result.contains(dest)) {
                        if (req.when_value) |val| {
                            if (result.values.get(dest)) |p_val| {
                                var p_val_str_buf: [128]u8 = undefined;
                                const p_val_str = blk: {
                                    switch (p_val) {
                                        .string => |s| break :blk s,
                                        .int => |i| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{i}) catch "",
                                        .uint => |u| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{u}) catch "",
                                        .float => |f| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{f}) catch "",
                                        .boolean => |b| break :blk if (b) "true" else "false",
                                        .counter => |c| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{c}) catch "",
                                        else => break :blk "",
                                    }
                                };
                                if (std.mem.eql(u8, p_val_str, val)) {
                                    triggered = true;
                                }
                            }
                        } else {
                            triggered = true;
                        }
                    }
                } else {
                    if (result.contains(req.when_arg)) {
                        if (req.when_value) |val| {
                            if (result.values.get(req.when_arg)) |p_val| {
                                var p_val_str_buf: [128]u8 = undefined;
                                const p_val_str = blk: {
                                    switch (p_val) {
                                        .string => |s| break :blk s,
                                        .int => |i| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{i}) catch "",
                                        .uint => |u| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{u}) catch "",
                                        .float => |f| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{f}) catch "",
                                        .boolean => |b| break :blk if (b) "true" else "false",
                                        .counter => |c| break :blk std.fmt.bufPrint(&p_val_str_buf, "{d}", .{c}) catch "",
                                        else => break :blk "",
                                    }
                                };
                                if (std.mem.eql(u8, p_val_str, val)) {
                                    triggered = true;
                                }
                            }
                        } else {
                            triggered = true;
                        }
                    }
                }

                if (triggered and !result.contains(arg.getDestination())) {
                    if (req.when_value) |val| {
                        self.emitError(constants.DependencyMessages.required_if_value_error, .{ arg.name, req.when_arg, val });
                    } else {
                        self.emitError(constants.DependencyMessages.required_if_error, .{ arg.name, req.when_arg });
                    }
                    if (!self.cfg.silent_errors) {
                        std.debug.print(constants.DependencyMessages.dependency_hint, .{});
                    }
                    if (self.cfg.exit_on_error) std.process.exit(1);
                    return errors.ParseError.RequiredIfViolation;
                }
            }
        }
    }

    fn validateMutualExclusions(self: *Parser, result: *ParseResult) !void {
        for (self.spec.mutual_exclusions) |group| {
            var found_count: usize = 0;
            for (group) |name| {
                var is_present = false;
                if (self.findArgSpec(name)) |spec| {
                    if (result.contains(spec.getDestination())) {
                        is_present = true;
                    }
                } else {
                    if (result.contains(name)) {
                        is_present = true;
                    }
                }

                if (is_present) {
                    found_count += 1;
                }
            }

            if (found_count > 1) {
                var options_buf: [512]u8 = undefined;
                var offset: usize = 0;
                for (group, 0..) |name, idx| {
                    const printed = std.fmt.bufPrint(options_buf[offset..], "--{s}", .{name}) catch "";
                    offset += printed.len;
                    if (idx < group.len - 1 and offset + 2 <= options_buf.len) {
                        @memcpy(options_buf[offset .. offset + 2], ", ");
                        offset += 2;
                    }
                }
                const formatted = options_buf[0..offset];

                self.emitError(constants.ConflictMessages.mutual_exclusion_error, .{formatted});

                if (!self.cfg.silent_errors) {
                    std.debug.print(constants.ConflictMessages.conflict_hint, .{});
                }
                if (self.cfg.exit_on_error) std.process.exit(1);
                return errors.ParseError.MutuallyExclusive;
            }
        }
    }
};

/// Convenience function to parse arguments with a single call.
pub fn parseArgs(allocator: std.mem.Allocator, spec: CommandSpec, args: []const []const u8) !ParseResult {
    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();
    return parser.parse(args);
}

pub fn defaultIo() std.Io {
    if (builtin.is_test) return std.testing.io;
    return std.Io.failing;
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    var result = try parser.parse(&[_][]const u8{});
    defer result.deinit();

    try std.testing.expectEqual(@as(?i64, 10), result.getInt("count"));
}

test "Parser duplicate singleton option returns DuplicateArgument" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "email", .long = "email" }},
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{ "--email", "one@example.com", "--email", "two@example.com" };
    try std.testing.expectError(errors.ParseError.DuplicateArgument, parser.parse(&argv));
}

test "Parser decodes base64 option values" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "decode",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "secret", .long = "secret", .decode_mode = .base64_std }},
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{ "--secret", "c2VjcmV0" };
    var result = try parser.parse(&argv);
    defer result.deinit();

    try std.testing.expectEqualStrings("secret", result.getString("secret").?);
}

test "Parser invalid base64 decode returns InvalidValue" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "decode",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "secret", .long = "secret", .decode_mode = .base64_std }},
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{ "--secret", "@@not-base64@@" };
    try std.testing.expectError(errors.ParseError.InvalidValue, parser.parse(&argv));
}

test "Parser duplicate count option is allowed" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "verbose", .short = 'v', .action = .count }},
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{ "-v", "-v" };
    var result = try parser.parse(&argv);
    defer result.deinit();
    try std.testing.expectEqual(@as(?i64, 2), result.getInt("verbose"));
}

test "Parser unknown subcommand returns UnknownSubcommand when no positional exists" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .parsing_mode = .strict, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "git-like",
        .add_help = false,
        .subcommands = &[_]schema_mod.SubcommandSpec{
            .{ .name = "clone", .help = "Clone repo" },
            .{ .name = "commit", .help = "Commit changes" },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{"clnoe"};
    try std.testing.expectError(errors.ParseError.UnknownSubcommand, parser.parse(&argv));
}

test "Parser unknown subcommand in permissive mode is collected as remaining" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .parsing_mode = .permissive, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "git-like",
        .add_help = false,
        .subcommands = &[_]schema_mod.SubcommandSpec{
            .{ .name = "clone", .help = "Clone repo" },
            .{ .name = "commit", .help = "Commit changes" },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{"clnoe"};
    var result = try parser.parse(&argv);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.remaining.items.len);
    try std.testing.expectEqualStrings("clnoe", result.remaining.items[0]);
}

test "Parser first token can remain positional even when subcommands exist" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .parsing_mode = .strict, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "mixed",
        .add_help = false,
        .args = &[_]ArgSpec{.{ .name = "target", .positional = true }},
        .subcommands = &[_]schema_mod.SubcommandSpec{
            .{ .name = "init", .help = "Initialize" },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const argv = [_][]const u8{"unknown-value"};
    var result = try parser.parse(&argv);
    defer result.deinit();
    try std.testing.expectEqualStrings("unknown-value", result.getString("target").?);
}

test "Parser separator handling" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{ .name = "test", .add_help = false, .args = &[_]ArgSpec{} };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const args = [_][]const u8{ "--", "--not-option", "regular" };
    var result = try parser.parse(&args);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.remaining.items.len);
    try std.testing.expectEqualStrings("--not-option", result.remaining.items[0]);
}

test "Parser argument groups exclusive" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .silent_errors = true });
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
        fn check(io: std.Io, val: []const u8) validation.ValidationResult {
            _ = io;
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    var arena = std.heap.ArenaAllocator.init(allocator);
    var args_list: std.ArrayList([]const u8) = .empty;

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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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
    config_mod.initConfig(.{ .exit_on_error = false, .allow_negated_flags = false, .silent_errors = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "cache", .long = "cache", .action = .store_true },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
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

test "Parser array value with separator" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "hosts", .long = "hosts", .value_type = .array, .separator = ',' },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const args = [_][]const u8{ "--hosts", "a,b,c" };
    var result = try parser.parse(&args);
    defer result.deinit();

    const arr = result.getArray("hosts").?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
    try std.testing.expectEqualStrings("a", arr[0]);
    try std.testing.expectEqualStrings("b", arr[1]);
    try std.testing.expectEqualStrings("c", arr[2]);
}

test "Parser array value with separator via inline" {
    const allocator = std.testing.allocator;
    config_mod.initConfig(.{ .exit_on_error = false, .allow_inline_values = true });
    defer config_mod.resetConfig();

    const spec = CommandSpec{
        .name = "test",
        .add_help = false,
        .args = &[_]ArgSpec{
            .{ .name = "hosts", .long = "hosts", .value_type = .array, .separator = ',' },
        },
    };

    var parser = try Parser.init(allocator, spec, defaultIo(), null);
    defer parser.deinit();

    const args = [_][]const u8{"--hosts=a,b,c"};
    var result = try parser.parse(&args);
    defer result.deinit();

    const arr = result.getArray("hosts").?;
    try std.testing.expectEqual(@as(usize, 3), arr.len);
    try std.testing.expectEqualStrings("a", arr[0]);
    try std.testing.expectEqualStrings("b", arr[1]);
    try std.testing.expectEqualStrings("c", arr[2]);
}
