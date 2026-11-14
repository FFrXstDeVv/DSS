const std = @import("std");
const dss = @import("dss_core");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const args = try init.minimal.args.toSlice(allocator);

    if (args.len < 2) {
        std.debug.print(
            \\DSS — Decisive Solution Seeker
            \\Expression Engine
            \\
            \\Usage:
            \\  dss "<expression>"
            \\
            \\Examples:
            \\  dss "2 + 2"
            \\  dss "2 + 3 * 4"
            \\  dss "(10 - 4) / 2"
            \\
        , .{});
        return;
    }

    if (args.len > 2) {
        std.debug.print(
            "ERROR: Wrap the expression in quotation marks.\n",
            .{},
        );
        return;
    }

    const source = args[1];

    std.debug.print(
        "DSS / Expression Engine\nINPUT: {s}\n\n",
        .{source},
    );

    // hi
    const tokens = dss.expression.lexer.lex(
        allocator,
        source,
    ) catch |err| {
        std.debug.print(
            "STATUS: ERR\nLexer: {s}\n",
            .{@errorName(err)},
        );
        return;
    };

    const root = dss.expression.parser.parse(
        allocator,
        tokens,
    ) catch |err| {
        std.debug.print(
            "STATUS: ERR\nParser: {s}\n",
            .{@errorName(err)},
        );
        return;
    };

    const result = dss.expression.evaluator.evaluate(
        root,
        &.{},
    ) catch |err| {
        switch (err) {
            error.DivisionByZero => {
                std.debug.print(
                    "STATUS: ERR\nDivision by zero.\n",
                    .{},
                );
            },

            error.UnboundVariable => {
                std.debug.print(
                    \\STATUS: WARN
                    \\No numerical bindings provided.
                    \\Symbolic simplification is not connected yet.
                    \\
                , .{});
            },
        }

        return;
    };

    std.debug.print(
        "STATUS: READY\nRESULT: {d}\n",
        .{result},
    );
}
