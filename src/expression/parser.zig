const std = @import("std");
const ast = @import("ast.zig");
const Token = @import("token.zig").Token;
const Kind = @import("token.zig").Kind;

pub const ParseError = error{
    UnexpectedToken,
    ExpectedExpression,
    ExpectedRightParen,
    TrailingTokens,
};

const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []const Token,
    index: usize = 0,

    fn current(self: *Parser) Token {
        return self.tokens[self.index];
    }

    fn advance(self: *Parser) Token {
        const token = self.current();

        if (token.kind != .eof) {
            self.index += 1;
        }

        return token;
    }

    fn makeNode(
        self: *Parser,
        value: ast.Node,
    ) std.mem.Allocator.Error!*ast.Node {
        const node = try self.allocator.create(ast.Node);
        node.* = value;
        return node;
    }

    fn parseAdditive(
        self: *Parser,
    ) (ParseError || std.mem.Allocator.Error)!*ast.Node {
        var node = try self.parseMultiplicative();

        while (self.current().kind == .plus or
            self.current().kind == .minus)
        {
            const operator = self.advance();

            const right = try self.parseMultiplicative();

            const op: ast.BinaryOp =
                if (operator.kind == .plus)
                    .add
                else
                    .subtract;

            node = try self.makeNode(.{
                .binary = .{
                    .op = op,
                    .left = node,
                    .right = right,
                },
            });
        }

        return node;
    }

    fn parseMultiplicative(
        self: *Parser,
    ) (ParseError || std.mem.Allocator.Error)!*ast.Node {
        var node = try self.parseUnary();

        while (true) {
            const kind = self.current().kind;

            var op: ?ast.BinaryOp = null;
            var explicit_operator = true;

            switch (kind) {
                .multiply => op = .multiply,
                .divide => op = .divide,

                .identifier, .left_paren => {
                    op = .multiply;
                    explicit_operator = false;
                },

                else => break,
            }

            if (explicit_operator) {
                _ = self.advance();
            }

            const right = try self.parseUnary();

            node = try self.makeNode(.{
                .binary = .{
                    .op = op.?,
                    .left = node,
                    .right = right,
                },
            });
        }

        return node;
    }

    // unary signs
    fn parseUnary(
        self: *Parser,
    ) (ParseError || std.mem.Allocator.Error)!*ast.Node {
        const kind = self.current().kind;

        if (kind == .plus or kind == .minus) {
            _ = self.advance();

            const operand = try self.parseUnary();

            return self.makeNode(.{
                .unary = .{
                    .op = if (kind == .plus) .plus else .minus,
                    .operand = operand,
                },
            });
        }

        return self.parsePrimary();
    }

    fn parsePrimary(
        self: *Parser,
    ) (ParseError || std.mem.Allocator.Error)!*ast.Node {
        const token = self.current();

        switch (token.kind) {
            .number => {
                _ = self.advance();

                return self.makeNode(.{
                    .number = token.number_value,
                });
            },

            .identifier => {
                _ = self.advance();

                return self.makeNode(.{
                    .variable = token.lexeme,
                });
            },

            .left_paren => {
                _ = self.advance();

                const node = try self.parseAdditive();

                if (self.current().kind != .right_paren) {
                    return ParseError.ExpectedRightParen;
                }

                _ = self.advance();
                return node;
            },

            else => return ParseError.ExpectedExpression,
        }
    }
};

pub fn parse(
    allocator: std.mem.Allocator,
    tokens: []const Token,
) (ParseError || std.mem.Allocator.Error)!*ast.Node {
    if (tokens.len == 0) {
        return ParseError.ExpectedExpression;
    }

    var parser = Parser{
        .allocator = allocator,
        .tokens = tokens,
    };

    const root = try parser.parseAdditive();

    if (parser.current().kind != .eof) {
        return ParseError.TrailingTokens;
    }

    return root;
}

test "operator precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const tokens = try lexer.lex(allocator, "2 + 3 * 4");

    const root = try parse(allocator, tokens);

    try std.testing.expect(
        std.meta.activeTag(root.*) == .binary,
    );

    try std.testing.expectEqual(
        ast.BinaryOp.add,
        root.binary.op,
    );

    try std.testing.expect(
        std.meta.activeTag(root.binary.right.*) == .binary,
    );

    try std.testing.expectEqual(
        ast.BinaryOp.multiply,
        root.binary.right.binary.op,
    );
}

test "parentheses override precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const tokens = try lexer.lex(allocator, "(2 + 3) * 4");

    const root = try parse(allocator, tokens);

    try std.testing.expectEqual(
        ast.BinaryOp.multiply,
        root.binary.op,
    );

    try std.testing.expectEqual(
        ast.BinaryOp.add,
        root.binary.left.binary.op,
    );
}

test "implicit multiplication" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const tokens = try lexer.lex(allocator, "3x + 5x");

    const root = try parse(allocator, tokens);

    try std.testing.expectEqual(
        ast.BinaryOp.add,
        root.binary.op,
    );

    try std.testing.expectEqual(
        ast.BinaryOp.multiply,
        root.binary.left.binary.op,
    );
}

test "unary minus" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const tokens = try lexer.lex(allocator, "-5 + 2");

    const root = try parse(allocator, tokens);

    try std.testing.expect(
        std.meta.activeTag(root.binary.left.*) == .unary,
    );
}

test "reject missing closing parenthesis" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const tokens = try lexer.lex(allocator, "(2 + 3");

    try std.testing.expectError(
        ParseError.ExpectedRightParen,
        parse(allocator, tokens),
    );
}
