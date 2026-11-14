const std = @import("std");
const Token = @import("token.zig").Token;
const Kind = @import("token.zig").Kind;

pub const LexError = error{
    UnexpectedCharacter,
    InvalidNumber,
};

pub fn lex(
    allocator: std.mem.Allocator,
    source: []const u8,
) (LexError || std.mem.Allocator.Error)![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    errdefer tokens.deinit(allocator);

    var i: usize = 0;

    while (i < source.len) {
        const c = source[i];

        // no whitespaces
        if (std.ascii.isWhitespace(c)) {
            i += 1;
            continue;
        }

        const start = i;

        if (std.ascii.isDigit(c) or
            (c == '.' and i + 1 < source.len and
                std.ascii.isDigit(source[i + 1])))
        {
            i = scanNumber(source, i);

            const lexeme = source[start..i];
            const value = std.fmt.parseFloat(f64, lexeme) catch {
                return LexError.InvalidNumber;
            };

            try tokens.append(allocator, .{
                .kind = .number,
                .lexeme = lexeme,
                .number_value = value,
            });

            continue;
        }

        if (isIdentifierStart(c)) {
            i += 1;

            while (i < source.len and
                isIdentifierContinue(source[i]))
            {
                i += 1;
            }

            try tokens.append(allocator, .{
                .kind = .identifier,
                .lexeme = source[start..i],
            });

            continue;
        }

        const kind: ?Kind = switch (c) {
            '+' => .plus,
            '-' => .minus,
            '*' => .multiply,
            '/' => .divide,
            '^' => .power,
            '(' => .left_paren,
            ')' => .right_paren,
            '=' => .equal,
            else => null,
        };

        if (kind) |token_kind| {
            try tokens.append(allocator, .{
                .kind = token_kind,
                .lexeme = source[start .. start + 1],
            });

            i += 1;
        } else {
            return LexError.UnexpectedCharacter;
        }
    }

    try tokens.append(allocator, .{
        .kind = .eof,
        .lexeme = source[source.len..],
    });

    return try tokens.toOwnedSlice(allocator);
}

fn isIdentifierStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isIdentifierContinue(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}

fn scanNumber(source: []const u8, start: usize) usize {
    var i = start;

    while (i < source.len and std.ascii.isDigit(source[i])) {
        i += 1;
    }

    if (i < source.len and source[i] == '.') {
        i += 1;

        while (i < source.len and std.ascii.isDigit(source[i])) {
            i += 1;
        }
    }

    if (i < source.len and
        (source[i] == 'e' or source[i] == 'E'))
    {
        i += 1;

        if (i < source.len and
            (source[i] == '+' or source[i] == '-'))
        {
            i += 1;
        }

        const exponent_start = i;

        while (i < source.len and std.ascii.isDigit(source[i])) {
            i += 1;
        }

        if (i == exponent_start) {
            return i;
        }
    }

    return i;
}

test "lex arithmetic expression" {
    const allocator = std.testing.allocator;

    const tokens = try lex(
        allocator,
        "2 + 3 * 4",
    );
    defer allocator.free(tokens);

    try std.testing.expectEqual(@as(usize, 6), tokens.len);

    try std.testing.expectEqual(Kind.number, tokens[0].kind);
    try std.testing.expectEqual(Kind.plus, tokens[1].kind);
    try std.testing.expectEqual(Kind.number, tokens[2].kind);
    try std.testing.expectEqual(Kind.multiply, tokens[3].kind);
    try std.testing.expectEqual(Kind.number, tokens[4].kind);
    try std.testing.expectEqual(Kind.eof, tokens[5].kind);
}

test "lex identifiers" {
    const allocator = std.testing.allocator;

    const tokens = try lex(
        allocator,
        "velocity + mass_initial * x_1",
    );
    defer allocator.free(tokens);

    try std.testing.expectEqualStrings(
        "velocity",
        tokens[0].lexeme,
    );

    try std.testing.expectEqualStrings(
        "mass_initial",
        tokens[2].lexeme,
    );

    try std.testing.expectEqualStrings(
        "x_1",
        tokens[4].lexeme,
    );
}

test "lex decimal numbers" {
    const allocator = std.testing.allocator;

    const tokens = try lex(
        allocator,
        "3.14 + .5",
    );
    defer allocator.free(tokens);

    try std.testing.expectApproxEqAbs(
        3.14,
        tokens[0].number_value,
        0.000001,
    );

    try std.testing.expectApproxEqAbs(
        0.5,
        tokens[2].number_value,
        0.000001,
    );
}

test "lex parentheses and exponent" {
    const allocator = std.testing.allocator;

    const tokens = try lex(
        allocator,
        "(a + 2)^3",
    );
    defer allocator.free(tokens);

    try std.testing.expectEqual(Kind.left_paren, tokens[0].kind);
    try std.testing.expectEqual(Kind.power, tokens[5].kind);
    try std.testing.expectEqual(Kind.right_paren, tokens[7].kind);
}

test "reject unexpected character" {
    try std.testing.expectError(
        LexError.UnexpectedCharacter,
        lex(std.testing.allocator, "2 @ 3"),
    );
}
