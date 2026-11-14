const std = @import("std");

pub const Mode = enum {
    interactive,
    help,
    formulas,
    version,
    evaluate,
};

pub const ParsedArgs = struct {
    mode: Mode = .interactive,
    expression: ?[]const u8 = null,
    assignments: []const []const u8 = &.{},
};

pub const ParseError = error{
    UnknownOption,
    MissingAssignment,
    InvalidAssignment,
    MultipleExpressions,
    ConflictingOptions,
};

pub fn parse(
    allocator: std.mem.Allocator,
    args: []const []const u8,
) !ParsedArgs {
    var result = ParsedArgs{};
    var assignment_count: usize = 0;
    var selected_mode: ?Mode = null;

    var i: usize = 0;
    while (i < args.len) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-v") or
            std.mem.eql(u8, arg, "-h") or
            std.mem.eql(u8, arg, "--help"))
        {
            try selectMode(&selected_mode, .help);
        } else if (std.mem.eql(u8, arg, "-vf")) {
            try selectMode(&selected_mode, .formulas);
        } else if (std.mem.eql(u8, arg, "--version")) {
            try selectMode(&selected_mode, .version);
        } else if (std.mem.eql(u8, arg, "--set")) {
            if (i + 1 >= args.len) {
                return ParseError.MissingAssignment;
            }

            try validateAssignment(args[i + 1]);
            assignment_count += 1;
            i += 1;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return ParseError.UnknownOption;
        } else {
            if (result.expression != null) {
                return ParseError.MultipleExpressions;
            }

            result.expression = arg;
        }

        i += 1;
    }

    if (selected_mode) |mode| {
        if (result.expression != null or assignment_count != 0) {
            return ParseError.ConflictingOptions;
        }

        result.mode = mode;
        return result;
    }

    const assignments = try allocator.alloc([]const u8, assignment_count);

    i = 0;
    var assignment_index: usize = 0;

    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--set")) {
            assignments[assignment_index] = args[i + 1];
            assignment_index += 1;
            i += 1;
        }
    }

    result.assignments = assignments;

    if (result.expression != null) {
        result.mode = .evaluate;
    }

    return result;
}

fn selectMode(
    selected: *?Mode,
    mode: Mode,
) ParseError!void {
    if (selected.* != null) {
        return ParseError.ConflictingOptions;
    }

    selected.* = mode;
}

fn validateAssignment(assignment: []const u8) ParseError!void {
    const separator = std.mem.indexOfScalar(u8, assignment, '=') orelse {
        return ParseError.InvalidAssignment;
    };

    if (separator == 0 or separator + 1 >= assignment.len) {
        return ParseError.InvalidAssignment;
    }
}

test "help option" {
    const args = [_][]const u8{"-v"};
    const parsed = try parse(std.testing.allocator, &args);

    try std.testing.expectEqual(Mode.help, parsed.mode);
}

test "expression with assignments" {
    const args = [_][]const u8{
        "a*b",
        "--set",
        "a=5",
        "--set",
        "b=3",
    };

    const parsed = try parse(std.testing.allocator, &args);
    defer std.testing.allocator.free(parsed.assignments);

    try std.testing.expectEqual(Mode.evaluate, parsed.mode);
    try std.testing.expectEqualStrings("a*b", parsed.expression.?);
    try std.testing.expectEqual(@as(usize, 2), parsed.assignments.len);
}

test "invalid assignment" {
    const args = [_][]const u8{
        "a*b",
        "--set",
        "invalid",
    };

    try std.testing.expectError(
        ParseError.InvalidAssignment,
        parse(std.testing.allocator, &args),
    );
}

test "formula catalog option" {
    const args = [_][]const u8{"-vf"};
    const parsed = try parse(std.testing.allocator, &args);

    try std.testing.expectEqual(Mode.formulas, parsed.mode);
}
