const std = @import("std");
const ast = @import("ast.zig");

pub const Binding = struct {
    name: []const u8,
    value: f64,
};

pub const EvalError = error{
    DivisionByZero,
    UnboundVariable,
};

pub fn evaluate(
    node: *const ast.Node,
    bindings: []const Binding,
) EvalError!f64 {
    switch (node.*) {
        .number => |value| return value,

        .variable => |name| {
            for (bindings) |binding| {
                if (std.mem.eql(u8, name, binding.name)) {
                    return binding.value;
                }
            }

            return EvalError.UnboundVariable;
        },

        .unary => |unary| {
            const value = try evaluate(unary.operand, bindings);

            return switch (unary.op) {
                .plus => value,
                .minus => -value,
            };
        },

        .binary => |binary| {
            const left = try evaluate(binary.left, bindings);
            const right = try evaluate(binary.right, bindings);

            return switch (binary.op) {
                .add => left + right,
                .subtract => left - right,
                .multiply => left * right,

                .divide => blk: {
                    if (right == 0.0) {
                        return EvalError.DivisionByZero;
                    }

                    break :blk left / right;
                },
            };
        },
    }
}

fn evaluateSource(
    allocator: std.mem.Allocator,
    source: []const u8,
) !f64 {
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");

    const tokens = try lexer.lex(allocator, source);
    const root = try parser.parse(allocator, tokens);

    return try evaluate(root, &.{});
}

test "basic arithmetic" {
    const allocator = std.testing.allocator;

    try std.testing.expectApproxEqAbs(
        4.0,
        try evaluateSource(allocator, "2 + 2"),
        0.000001,
    );

    try std.testing.expectApproxEqAbs(
        -5.0,
        try evaluateSource(allocator, "10 - 15"),
        0.000001,
    );

    try std.testing.expectApproxEqAbs(
        42.0,
        try evaluateSource(allocator, "6 * 7"),
        0.000001,
    );

    try std.testing.expectApproxEqAbs(
        5.0,
        try evaluateSource(allocator, "20 / 4"),
        0.000001,
    );
}

test "operator precedence" {
    const allocator = std.testing.allocator;

    try std.testing.expectApproxEqAbs(
        14.0,
        try evaluateSource(allocator, "2 + 3 * 4"),
        0.000001,
    );
}

test "parentheses" {
    const allocator = std.testing.allocator;

    try std.testing.expectApproxEqAbs(
        20.0,
        try evaluateSource(allocator, "(2 + 3) * 4"),
        0.000001,
    );
}

test "unary minus" {
    const allocator = std.testing.allocator;

    try std.testing.expectApproxEqAbs(
        -3.0,
        try evaluateSource(allocator, "-5 + 2"),
        0.000001,
    );
}

test "division by zero" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(
        EvalError.DivisionByZero,
        evaluateSource(allocator, "10 / 0"),
    );
}

test "variable binding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");

    const tokens = try lexer.lex(allocator, "a * b + 2");
    const root = try parser.parse(allocator, tokens);

    const bindings = [_]Binding{
        .{ .name = "a", .value = 5 },
        .{ .name = "b", .value = 3 },
    };

    const result = try evaluate(root, &bindings);

    try std.testing.expectApproxEqAbs(
        17.0,
        result,
        0.000001,
    );
}
