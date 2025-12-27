//! Command-line argument tokenizer for args.zig.

const std = @import("std");
const utils = @import("utils.zig");

/// Token types for command-line arguments.
pub const TokenType = enum {
    long_option,
    short_option,
    short_cluster,
    option_with_value,
    value,
    separator,
    end,
};

/// A single token from the argument stream.
pub const Token = struct {
    token_type: TokenType,
    raw: []const u8,
    name: ?[]const u8 = null,
    inline_value: ?[]const u8 = null,
    position: usize = 0,

    pub fn isOption(self: *const Token) bool {
        return self.token_type == .long_option or
            self.token_type == .short_option or
            self.token_type == .short_cluster or
            self.token_type == .option_with_value;
    }
};

/// Tokenizes command-line arguments into a stream of tokens.
pub const Tokenizer = struct {
    args: []const []const u8,
    index: usize = 0,
    past_separator: bool = false,
    cluster: ?[]const u8 = null,
    cluster_index: usize = 0,

    pub fn init(args: []const []const u8) Tokenizer {
        return .{ .args = args };
    }

    pub fn next(self: *Tokenizer) Token {
        if (self.cluster) |c| {
            if (self.cluster_index < c.len) {
                const cur_idx = self.cluster_index;
                self.cluster_index += 1;
                if (self.cluster_index >= c.len) {
                    self.cluster = null;
                    self.cluster_index = 0;
                }
                return .{
                    .token_type = .short_option,
                    .raw = c[cur_idx .. cur_idx + 1],
                    .name = c[cur_idx .. cur_idx + 1],
                    .position = self.index - 1,
                };
            }
        }

        if (self.index >= self.args.len) {
            return .{ .token_type = .end, .raw = "", .position = self.index };
        }

        const arg = self.args[self.index];
        const position = self.index;
        self.index += 1;

        if (self.past_separator) {
            return .{ .token_type = .value, .raw = arg, .position = position };
        }

        if (utils.eql(arg, "--")) {
            self.past_separator = true;
            return .{ .token_type = .separator, .raw = arg, .position = position };
        }

        if (arg.len > 2 and utils.startsWith(arg, "--")) {
            const content = arg[2..];
            if (utils.indexOf(content, '=')) |eq_pos| {
                return .{
                    .token_type = .option_with_value,
                    .raw = arg,
                    .name = content[0..eq_pos],
                    .inline_value = content[eq_pos + 1 ..],
                    .position = position,
                };
            }
            return .{
                .token_type = .long_option,
                .raw = arg,
                .name = content,
                .position = position,
            };
        }

        if (arg.len >= 2 and arg[0] == '-' and arg[1] != '-') {
            const content = arg[1..];
            if (utils.indexOf(content, '=')) |eq_pos| {
                if (eq_pos == 1) {
                    return .{
                        .token_type = .option_with_value,
                        .raw = arg,
                        .name = content[0..1],
                        .inline_value = content[2..],
                        .position = position,
                    };
                }
            }
            if (content.len == 1) {
                return .{
                    .token_type = .short_option,
                    .raw = arg,
                    .name = content,
                    .position = position,
                };
            }
            self.cluster = content;
            self.cluster_index = 1;
            return .{
                .token_type = .short_option,
                .raw = content[0..1],
                .name = content[0..1],
                .position = position,
            };
        }

        return .{ .token_type = .value, .raw = arg, .position = position };
    }

    pub fn peek(self: *Tokenizer) Token {
        const saved_index = self.index;
        const saved_past = self.past_separator;
        const saved_cluster = self.cluster;
        const saved_cluster_idx = self.cluster_index;

        const tok = self.next();

        self.index = saved_index;
        self.past_separator = saved_past;
        self.cluster = saved_cluster;
        self.cluster_index = saved_cluster_idx;

        return tok;
    }

    pub fn hasMore(self: *Tokenizer) bool {
        return self.peek().token_type != .end;
    }

    pub fn remaining(self: *const Tokenizer) []const []const u8 {
        if (self.index >= self.args.len) return &.{};
        return self.args[self.index..];
    }

    pub fn reset(self: *Tokenizer) void {
        self.index = 0;
        self.past_separator = false;
        self.cluster = null;
        self.cluster_index = 0;
    }
};

test "Tokenizer long option" {
    var tokenizer = Tokenizer.init(&[_][]const u8{"--verbose"});
    const tok = tokenizer.next();
    try std.testing.expectEqual(TokenType.long_option, tok.token_type);
    try std.testing.expectEqualStrings("verbose", tok.name.?);
}

test "Tokenizer long option with value" {
    var tokenizer = Tokenizer.init(&[_][]const u8{"--output=file.txt"});
    const tok = tokenizer.next();
    try std.testing.expectEqual(TokenType.option_with_value, tok.token_type);
    try std.testing.expectEqualStrings("output", tok.name.?);
    try std.testing.expectEqualStrings("file.txt", tok.inline_value.?);
}

test "Tokenizer short option" {
    var tokenizer = Tokenizer.init(&[_][]const u8{"-v"});
    const tok = tokenizer.next();
    try std.testing.expectEqual(TokenType.short_option, tok.token_type);
    try std.testing.expectEqualStrings("v", tok.name.?);
}

test "Tokenizer short cluster" {
    var tokenizer = Tokenizer.init(&[_][]const u8{"-abc"});
    const t1 = tokenizer.next();
    try std.testing.expectEqual(TokenType.short_option, t1.token_type);
    try std.testing.expectEqualStrings("a", t1.name.?);

    const t2 = tokenizer.next();
    try std.testing.expectEqual(TokenType.short_option, t2.token_type);
    try std.testing.expectEqualStrings("b", t2.name.?);

    const t3 = tokenizer.next();
    try std.testing.expectEqual(TokenType.short_option, t3.token_type);
    try std.testing.expectEqualStrings("c", t3.name.?);
}

test "Tokenizer separator" {
    var tokenizer = Tokenizer.init(&[_][]const u8{ "--", "--not-an-option" });
    const t1 = tokenizer.next();
    try std.testing.expectEqual(TokenType.separator, t1.token_type);

    const t2 = tokenizer.next();
    try std.testing.expectEqual(TokenType.value, t2.token_type);
    try std.testing.expectEqualStrings("--not-an-option", t2.raw);
}

test "Tokenizer value" {
    var tokenizer = Tokenizer.init(&[_][]const u8{"file.txt"});
    const tok = tokenizer.next();
    try std.testing.expectEqual(TokenType.value, tok.token_type);
    try std.testing.expectEqualStrings("file.txt", tok.raw);
}

test "Tokenizer peek and hasMore" {
    var tokenizer = Tokenizer.init(&[_][]const u8{ "-v", "file" });
    try std.testing.expect(tokenizer.hasMore());

    const peeked = tokenizer.peek();
    try std.testing.expectEqual(TokenType.short_option, peeked.token_type);

    const actual = tokenizer.next();
    try std.testing.expectEqual(TokenType.short_option, actual.token_type);
    try std.testing.expect(tokenizer.hasMore());
}

test "Tokenizer reset" {
    var tokenizer = Tokenizer.init(&[_][]const u8{ "-v", "file" });
    _ = tokenizer.next();
    _ = tokenizer.next();
    try std.testing.expect(!tokenizer.hasMore());

    tokenizer.reset();
    try std.testing.expect(tokenizer.hasMore());
}
