pub const UnaryOp = enum {
    plus,
    minus,
};

pub const BinaryOp = enum {
    add,
    subtract,
    multiply,
    divide,
};

pub const Unary = struct {
    op: UnaryOp,
    operand: *const Node,
};

pub const Binary = struct {
    op: BinaryOp,
    left: *const Node,
    right: *const Node,
};

pub const Node = union(enum) {
    number: f64,
    variable: []const u8,
    unary: Unary,
    binary: Binary,
};
