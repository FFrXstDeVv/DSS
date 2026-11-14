const std = @import("std");

pub const Dimension = struct {
    exponents: [7]i16 = .{ 0, 0, 0, 0, 0, 0, 0 },

    pub fn eql(a: Dimension, b: Dimension) bool {
        for (0..7) |i| {
            if (a.exponents[i] != b.exponents[i]) return false;
        }
        return true;
    }

    fn multiplied(a: Dimension, b: Dimension) Dimension {
        var result = a;
        for (0..7) |i| result.exponents[i] += b.exponents[i];
        return result;
    }

    fn divided(a: Dimension, b: Dimension) Dimension {
        var result = a;
        for (0..7) |i| result.exponents[i] -= b.exponents[i];
        return result;
    }

    fn raised(a: Dimension, exponent: i8) Dimension {
        var result = a;
        for (0..7) |i| result.exponents[i] *= @as(i16, exponent);
        return result;
    }
};

pub const Dimensions = struct {
    pub const dimensionless = Dimension{};
    pub const length = Dimension{ .exponents = .{ 1, 0, 0, 0, 0, 0, 0 } };
    pub const area = Dimension{ .exponents = .{ 2, 0, 0, 0, 0, 0, 0 } };
    pub const velocity = Dimension{ .exponents = .{ 1, 0, -1, 0, 0, 0, 0 } };
    pub const density = Dimension{ .exponents = .{ -3, 1, 0, 0, 0, 0, 0 } };
    pub const dynamic_viscosity = Dimension{ .exponents = .{ -1, 1, -1, 0, 0, 0, 0 } };
    pub const pressure = Dimension{ .exponents = .{ -1, 1, -2, 0, 0, 0, 0 } };
    pub const force = Dimension{ .exponents = .{ 1, 1, -2, 0, 0, 0, 0 } };
};

pub const Quantity = struct {
    value: f64,
    dimension: Dimension = Dimensions.dimensionless,

    pub fn add(a: Quantity, b: Quantity) EvalError!Quantity {
        if (!a.dimension.eql(b.dimension)) return error.DimensionMismatch;
        return .{ .value = a.value + b.value, .dimension = a.dimension };
    }

    pub fn subtract(a: Quantity, b: Quantity) EvalError!Quantity {
        if (!a.dimension.eql(b.dimension)) return error.DimensionMismatch;
        return .{ .value = a.value - b.value, .dimension = a.dimension };
    }

    pub fn multiply(a: Quantity, b: Quantity) Quantity {
        return .{
            .value = a.value * b.value,
            .dimension = a.dimension.multiplied(b.dimension),
        };
    }

    pub fn divide(a: Quantity, b: Quantity) EvalError!Quantity {
        if (b.value == 0.0) return error.DivisionByZero;
        return .{
            .value = a.value / b.value,
            .dimension = a.dimension.divided(b.dimension),
        };
    }

    pub fn powerInteger(base: Quantity, exponent: i8) EvalError!Quantity {
        if (exponent < 0 and base.value == 0.0) return error.DivisionByZero;

        const magnitude: u8 = if (exponent < 0)
            @intCast(-@as(i16, exponent))
        else
            @intCast(exponent);

        var result: f64 = 1.0;
        var factor = base.value;
        var remaining = magnitude;
        while (remaining > 0) : (remaining >>= 1) {
            if ((remaining & 1) != 0) result *= factor;
            factor *= factor;
        }
        if (exponent < 0) result = 1.0 / result;

        return .{
            .value = result,
            .dimension = base.dimension.raised(exponent),
        };
    }
};

pub const Symbol = enum {
    density,
    velocity,
    area,
    drag_coefficient,
    dynamic_viscosity,
    characteristic_length,
    lift_coefficient,
};

pub const Binding = struct {
    symbol: Symbol,
    quantity: Quantity,
};

pub const Instruction = union(enum) {
    constant: Quantity,
    variable: Symbol,
    add: void,
    subtract: void,
    multiply: void,
    divide: void,
    power_integer: i8,
};

pub const EvalError = error{
    MissingVariable,
    DuplicateBinding,
    DimensionMismatch,
    DivisionByZero,
    InvalidProgram,
    StackOverflow,
    OutputDimensionMismatch,
};

const stack_capacity = 64;

fn findBinding(bindings: []const Binding, symbol: Symbol) EvalError!Quantity {
    var found: ?Quantity = null;
    for (bindings) |binding| {
        if (binding.symbol != symbol) continue;
        if (found != null) return error.DuplicateBinding;
        found = binding.quantity;
    }
    return found orelse error.MissingVariable;
}

const BinaryOperation = enum { add, subtract, multiply, divide };

fn applyBinary(
    stack: *[stack_capacity]Quantity,
    stack_len: *usize,
    operation: BinaryOperation,
) EvalError!void {
    if (stack_len.* < 2) return error.InvalidProgram;
    const rhs = stack[stack_len.* - 1];
    const lhs = stack[stack_len.* - 2];
    stack_len.* -= 2;
    const result = switch (operation) {
        .add => try lhs.add(rhs),
        .subtract => try lhs.subtract(rhs),
        .multiply => lhs.multiply(rhs),
        .divide => try lhs.divide(rhs),
    };
    stack[stack_len.*] = result;
    stack_len.* += 1;
}

pub fn evaluateProgram(program: []const Instruction, bindings: []const Binding) EvalError!Quantity {
    var stack: [stack_capacity]Quantity = undefined;
    var stack_len: usize = 0;

    for (program) |instruction| {
        switch (instruction) {
            .constant => |quantity| {
                if (stack_len == stack.len) return error.StackOverflow;
                stack[stack_len] = quantity;
                stack_len += 1;
            },
            .variable => |symbol| {
                if (stack_len == stack.len) return error.StackOverflow;
                stack[stack_len] = try findBinding(bindings, symbol);
                stack_len += 1;
            },
            .add => try applyBinary(&stack, &stack_len, .add),
            .subtract => try applyBinary(&stack, &stack_len, .subtract),
            .multiply => try applyBinary(&stack, &stack_len, .multiply),
            .divide => try applyBinary(&stack, &stack_len, .divide),
            .power_integer => |exponent| {
                if (stack_len < 1) return error.InvalidProgram;
                stack[stack_len - 1] = try Quantity.powerInteger(stack[stack_len - 1], exponent);
            },
        }
    }

    if (stack_len != 1) return error.InvalidProgram;
    return stack[0];
}

pub const VariableInfo = struct {
    symbol: Symbol,
    notation: []const u8,
    name: []const u8,
    description: []const u8,
    dimension: Dimension,
};

pub const Formula = struct {
    id: []const u8,
    title: []const u8,
    topic: []const u8,
    equation: []const u8,
    assumptions: []const u8,
    variables: []const VariableInfo,
    program: []const Instruction,
    output_dimension: Dimension,
};

const dynamic_pressure_variables = [_]VariableInfo{
    .{ .symbol = .density, .notation = "rho", .name = "Density", .description = "Fluid density", .dimension = Dimensions.density },
    .{ .symbol = .velocity, .notation = "v", .name = "Flow velocity", .description = "Fluid speed relative to the body", .dimension = Dimensions.velocity },
};

const drag_variables = [_]VariableInfo{
    .{ .symbol = .density, .notation = "rho", .name = "Density", .description = "Fluid density", .dimension = Dimensions.density },
    .{ .symbol = .velocity, .notation = "v", .name = "Flow velocity", .description = "Fluid speed relative to the body", .dimension = Dimensions.velocity },
    .{ .symbol = .drag_coefficient, .notation = "Cd", .name = "Drag coefficient", .description = "Dimensionless drag coefficient for the chosen body and flow regime", .dimension = Dimensions.dimensionless },
    .{ .symbol = .area, .notation = "A", .name = "Reference area", .description = "Reference area used by the coefficient definition", .dimension = Dimensions.area },
};

const reynolds_variables = [_]VariableInfo{
    .{ .symbol = .density, .notation = "rho", .name = "Density", .description = "Fluid density", .dimension = Dimensions.density },
    .{ .symbol = .velocity, .notation = "v", .name = "Flow velocity", .description = "Characteristic flow speed", .dimension = Dimensions.velocity },
    .{ .symbol = .characteristic_length, .notation = "L", .name = "Characteristic length", .description = "Length scale of the body or flow", .dimension = Dimensions.length },
    .{ .symbol = .dynamic_viscosity, .notation = "mu", .name = "Dynamic viscosity", .description = "Dynamic (not kinematic) viscosity", .dimension = Dimensions.dynamic_viscosity },
};

const lift_variables = [_]VariableInfo{
    .{ .symbol = .density, .notation = "rho", .name = "Density", .description = "Fluid density", .dimension = Dimensions.density },
    .{ .symbol = .velocity, .notation = "v", .name = "Flow velocity", .description = "Fluid speed relative to the body", .dimension = Dimensions.velocity },
    .{ .symbol = .lift_coefficient, .notation = "Cl", .name = "Lift coefficient", .description = "Dimensionless lift coefficient for the chosen configuration", .dimension = Dimensions.dimensionless },
    .{ .symbol = .area, .notation = "A", .name = "Reference area", .description = "Reference area used by the coefficient definition", .dimension = Dimensions.area },
};

const dynamic_pressure_program = [_]Instruction{
    .{ .constant = .{ .value = 0.5 } },
    .{ .variable = .density },
    .{ .multiply = {} },
    .{ .variable = .velocity },
    .{ .power_integer = 2 },
    .{ .multiply = {} },
};

const drag_program = [_]Instruction{
    .{ .constant = .{ .value = 0.5 } },
    .{ .variable = .density },
    .{ .multiply = {} },
    .{ .variable = .velocity },
    .{ .power_integer = 2 },
    .{ .multiply = {} },
    .{ .variable = .drag_coefficient },
    .{ .multiply = {} },
    .{ .variable = .area },
    .{ .multiply = {} },
};

const reynolds_program = [_]Instruction{
    .{ .variable = .density },
    .{ .variable = .velocity },
    .{ .multiply = {} },
    .{ .variable = .characteristic_length },
    .{ .multiply = {} },
    .{ .variable = .dynamic_viscosity },
    .{ .divide = {} },
};

const lift_program = [_]Instruction{
    .{ .constant = .{ .value = 0.5 } },
    .{ .variable = .density },
    .{ .multiply = {} },
    .{ .variable = .velocity },
    .{ .power_integer = 2 },
    .{ .multiply = {} },
    .{ .variable = .lift_coefficient },
    .{ .multiply = {} },
    .{ .variable = .area },
    .{ .multiply = {} },
};

pub const catalog = [_]Formula{
    .{
        .id = "aero.dynamic_pressure",
        .title = "Dynamic pressure",
        .topic = "Aerodynamics / Fluid mechanics",
        .equation = "q = 1/2 * rho * v^2",
        .assumptions = "Incompressible-flow dynamic-pressure expression; rho is in kg/m^3 and v is in m/s.",
        .variables = dynamic_pressure_variables[0..],
        .program = dynamic_pressure_program[0..],
        .output_dimension = Dimensions.pressure,
    },
    .{
        .id = "aero.drag_force",
        .title = "Drag force",
        .topic = "Aerodynamics",
        .equation = "D = 1/2 * rho * v^2 * Cd * A",
        .assumptions = "Uses a dimensionless drag coefficient and its matching reference area. Cd depends on shape, orientation and flow conditions.",
        .variables = drag_variables[0..],
        .program = drag_program[0..],
        .output_dimension = Dimensions.force,
    },
    .{
        .id = "aero.reynolds_number",
        .title = "Reynolds number",
        .topic = "Fluid mechanics",
        .equation = "Re = rho * v * L / mu",
        .assumptions = "Uses dynamic viscosity mu, not kinematic viscosity. Re is dimensionless.",
        .variables = reynolds_variables[0..],
        .program = reynolds_program[0..],
        .output_dimension = Dimensions.dimensionless,
    },
    .{
        .id = "aero.lift_force",
        .title = "Lift force",
        .topic = "Aerodynamics",
        .equation = "L = 1/2 * rho * v^2 * Cl * A",
        .assumptions = "Uses a dimensionless lift coefficient and its matching reference area. Cl depends on geometry, orientation and flow conditions.",
        .variables = lift_variables[0..],
        .program = lift_program[0..],
        .output_dimension = Dimensions.force,
    },
};

pub fn findFormula(id: []const u8) ?*const Formula {
    for (&catalog) |*formula| {
        if (std.mem.eql(u8, formula.id, id)) return formula;
    }
    return null;
}

pub fn evaluateFormula(formula: *const Formula, bindings: []const Binding) EvalError!Quantity {
    for (formula.variables) |variable| {
        const supplied = try findBinding(bindings, variable.symbol);
        if (!supplied.dimension.eql(variable.dimension)) return error.DimensionMismatch;
    }

    const result = try evaluateProgram(formula.program, bindings);
    if (!result.dimension.eql(formula.output_dimension)) return error.OutputDimensionMismatch;
    return result;
}

test "dynamic pressure formula evaluates and retains SI dimensions" {
    const formula = findFormula("aero.dynamic_pressure").?;
    const inputs = [_]Binding{
        .{ .symbol = .density, .quantity = .{ .value = 1.225, .dimension = Dimensions.density } },
        .{ .symbol = .velocity, .quantity = .{ .value = 10.0, .dimension = Dimensions.velocity } },
    };

    const result = try evaluateFormula(formula, &inputs);
    try std.testing.expect(@abs(result.value - 61.25) < 1e-10);
    try std.testing.expect(result.dimension.eql(Dimensions.pressure));
}

test "drag force formula evaluates" {
    const formula = findFormula("aero.drag_force").?;
    const inputs = [_]Binding{
        .{ .symbol = .density, .quantity = .{ .value = 1.225, .dimension = Dimensions.density } },
        .{ .symbol = .velocity, .quantity = .{ .value = 10.0, .dimension = Dimensions.velocity } },
        .{ .symbol = .drag_coefficient, .quantity = .{ .value = 1.2 } },
        .{ .symbol = .area, .quantity = .{ .value = 2.0, .dimension = Dimensions.area } },
    };

    const result = try evaluateFormula(formula, &inputs);
    try std.testing.expect(@abs(result.value - 147.0) < 1e-10);
    try std.testing.expect(result.dimension.eql(Dimensions.force));
}

test "Reynolds number is dimensionless" {
    const formula = findFormula("aero.reynolds_number").?;
    const inputs = [_]Binding{
        .{ .symbol = .density, .quantity = .{ .value = 1.225, .dimension = Dimensions.density } },
        .{ .symbol = .velocity, .quantity = .{ .value = 10.0, .dimension = Dimensions.velocity } },
        .{ .symbol = .characteristic_length, .quantity = .{ .value = 0.5, .dimension = Dimensions.length } },
        .{ .symbol = .dynamic_viscosity, .quantity = .{ .value = 1.81e-5, .dimension = Dimensions.dynamic_viscosity } },
    };

    const result = try evaluateFormula(formula, &inputs);
    try std.testing.expect(@abs(result.value - 338397.7900552486) < 1e-6);
    try std.testing.expect(result.dimension.eql(Dimensions.dimensionless));
}

test "addition rejects incompatible dimensions" {
    const length_quantity = Quantity{ .value = 2.0, .dimension = Dimensions.length };
    const time_quantity = Quantity{ .value = 3.0, .dimension = .{ .exponents = .{ 0, 0, 1, 0, 0, 0, 0 } } };
    try std.testing.expectError(error.DimensionMismatch, length_quantity.add(time_quantity));
}

test "missing and duplicate bindings are reported" {
    const one_variable_program = [_]Instruction{.{ .variable = .density }};
    try std.testing.expectError(error.MissingVariable, evaluateProgram(&one_variable_program, &.{}));

    const duplicate_inputs = [_]Binding{
        .{ .symbol = .density, .quantity = .{ .value = 1.0, .dimension = Dimensions.density } },
        .{ .symbol = .density, .quantity = .{ .value = 2.0, .dimension = Dimensions.density } },
    };
    try std.testing.expectError(error.DuplicateBinding, evaluateProgram(&one_variable_program, &duplicate_inputs));
}
