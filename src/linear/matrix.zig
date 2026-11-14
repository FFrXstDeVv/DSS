const std = @import("std");

pub const MatrixError = error{
    DimensionMismatch,
    IndexOutOfBounds,
    SizeOverflow,
};

pub const Matrix = struct {
    allocator: std.mem.Allocator,
    rows: usize,
    cols: usize,
    data: []f64,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        const count = std.math.mul(usize, rows, cols) catch return error.SizeOverflow;
        const data = try allocator.alloc(f64, count);
        @memset(data, 0.0);

        return .{
            .allocator = allocator,
            .rows = rows,
            .cols = cols,
            .data = data,
        };
    }

    pub fn deinit(self: *Matrix) void {
        self.allocator.free(self.data);
        self.data = &.{};
        self.rows = 0;
        self.cols = 0;
    }

    pub fn get(self: *const Matrix, row: usize, col: usize) MatrixError!f64 {
        if (row >= self.rows or col >= self.cols) return error.IndexOutOfBounds;
        return self.data[row * self.cols + col];
    }

    pub fn set(self: *Matrix, row: usize, col: usize, value: f64) MatrixError!void {
        if (row >= self.rows or col >= self.cols) return error.IndexOutOfBounds;
        self.data[row * self.cols + col] = value;
    }

    pub fn multiply(
        allocator: std.mem.Allocator,
        a: *const Matrix,
        b: *const Matrix,
    ) !Matrix {
        if (a.cols != b.rows) return error.DimensionMismatch;

        var result = try Matrix.init(allocator, a.rows, b.cols);
        errdefer result.deinit();

        var row: usize = 0;
        while (row < a.rows) : (row += 1) {
            var k: usize = 0;
            while (k < a.cols) : (k += 1) {
                const a_value = a.data[row * a.cols + k];
                var col: usize = 0;
                while (col < b.cols) : (col += 1) {
                    result.data[row * result.cols + col] +=
                        a_value * b.data[k * b.cols + col];
                }
            }
        }

        return result;
    }
};

test "2x2 matrix multiplication" {
    const allocator = std.testing.allocator;

    var a = try Matrix.init(allocator, 2, 2);
    defer a.deinit();
    var b = try Matrix.init(allocator, 2, 2);
    defer b.deinit();

    try a.set(0, 0, 1);
    try a.set(0, 1, 2);
    try a.set(1, 0, 3);
    try a.set(1, 1, 4);

    try b.set(0, 0, 5);
    try b.set(0, 1, 6);
    try b.set(1, 0, 7);
    try b.set(1, 1, 8);

    var product = try Matrix.multiply(allocator, &a, &b);
    defer product.deinit();

    try std.testing.expect(@abs(try product.get(0, 0) - 19.0) < 1e-12);
    try std.testing.expect(@abs(try product.get(0, 1) - 22.0) < 1e-12);
    try std.testing.expect(@abs(try product.get(1, 0) - 43.0) < 1e-12);
    try std.testing.expect(@abs(try product.get(1, 1) - 50.0) < 1e-12);
}

test "matrix multiplication rejects incompatible dimensions" {
    const allocator = std.testing.allocator;

    var a = try Matrix.init(allocator, 2, 3);
    defer a.deinit();
    var b = try Matrix.init(allocator, 2, 2);
    defer b.deinit();

    try std.testing.expectError(error.DimensionMismatch, Matrix.multiply(allocator, &a, &b));
}
