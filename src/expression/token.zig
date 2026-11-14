pub const Kind = enum {
    number,
    identifier,

    plus,
    minus,
    multiply,
    divide,
    power,

    left_paren,
    right_paren,
    equal,

    eof,
};

pub const Token = struct {
    kind: Kind,
    lexeme: []const u8,
    number_value: f64 = 0,
};
