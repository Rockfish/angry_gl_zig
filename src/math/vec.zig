const std = @import("std");

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn default() Vec2 {
        return .{ .x = 0.0, .y = 0.0 };
    }

    pub fn fromArray(value: [2]f32) Vec2 {
        return @as(*Vec2, @ptrCast(@constCast(&value))).*;
    }

    pub fn asArray(self: *const Vec2) [2]f32 {
        return @as(*[2]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec2) *[2]f32 {
        return @as(*[2]f32, @ptrCast(@constCast(self)));
    }

    pub inline fn asCPtrF32(v: *const Vec2) [*c]f32 {
        return @as([*c]f32, @ptrCast(@constCast(v)));
    }

    pub fn lengthSquared(v: *const Vec2) f32 {
        return v.dot(v);
    }

    pub fn dot(lhs: *const Vec2, rhs: *const Vec2) f32 {
        return (lhs.x * rhs.x) + (lhs.y * rhs.y);
    }

    pub fn asString(self: *const Vec2, buf: []u8) []u8 {
        return std.fmt.bufPrint(buf, "Vec2{{ {d}, {d} }}", .{ self.x, self.y }) catch |err| std.debug.panic("{any}", .{err});
    }

    pub fn clone(self: *const Vec2) Vec2 {
        return .{ .x = self.x, .y = self.y };
    }
};

pub fn vec2(x: f32, y: f32) Vec2 {
    return .{ .x = x, .y = y };
}

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    const Self = @This();

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn default() Vec3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn zero() Vec3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn one() Vec3 {
        return .{ .x = 1.0, .y = 1.0, .z = 1.0 };
    }

    pub fn splat(v: f32) Vec3 {
        return .{ .x = v, .y = v, .z = v };
    }

    pub fn fromArray(value: [3]f32) Vec3 {
        return @as(*Vec3, @ptrCast(@constCast(&value))).*;
    }

    pub fn fromSlice(value: []const f32) Vec3 {
        return @as(*Vec3, @ptrCast(@constCast(value))).*;
    }

    pub fn asArray(self: *const Vec3) [3]f32 {
        return @as(*[3]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec3) *[3]f32 {
        return @as(*[3]f32, @ptrCast(@constCast(self)));
    }

    pub fn add(a: *const Vec3, b: *const Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn addTo(a: *Vec3, b: *const Vec3) void {
        a.x = a.x + b.x;
        a.y = a.y + b.y;
        a.z = a.z + b.z;
    }

    pub fn sub(a: *const Vec3, b: *const Vec3) Vec3 {
        return .{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
        };
    }

    pub fn mul(a: *const Vec3, b: *const Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
    }

    pub fn normalize(v: *Vec3) void {
        const length_squared = v.lengthSquared();

        if (length_squared == 0.0) return;

        const magnitude = std.math.sqrt(length_squared);

        v.x = v.x / magnitude;
        v.y = v.y / magnitude;
        v.z = v.z / magnitude;
    }

    pub fn normalizeTo(v: *const Vec3) Vec3 {
        var result: Vec3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };

        const length_squared = v.lengthSquared();

        if (length_squared == 0.0) return result;

        const magnitude = std.math.sqrt(length_squared);

        result.x = v.x / magnitude;
        result.y = v.y / magnitude;
        result.z = v.z / magnitude;

        return result;
    }

    pub fn addScalar(a: *const Vec3, b: f32) Vec3 {
        return .{ .x = a.x + b, .y = a.y + b, .z = a.z + b };
    }

    pub fn mulScalar(a: *const Vec3, b: f32) Vec3 {
        return .{ .x = a.x * b, .y = a.y * b, .z = a.z * b };
    }

    pub fn divScalar(a: *const Vec3, b: f32) Vec3 {
        return .{ .x = a.x / b, .y = a.y / b, .z = a.z / b };
    }

    pub fn dot(lhs: *const Vec3, rhs: *const Vec3) f32 {
        return (lhs.x * rhs.x) + (lhs.y * rhs.y) + (lhs.z * rhs.z);
    }

    pub fn cross(a: *const Vec3, b: *const Vec3) Vec3 {
        return Vec3{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn crossNormalized(a: *const Vec3, b: *const Vec3) Vec3 {
        var v = Vec3{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };

        const length_squared = v.lengthSquared();

        if (length_squared == 0.0) return v;

        const magnitude = std.math.sqrt(length_squared);

        v.x = v.x / magnitude;
        v.y = v.y / magnitude;
        v.z = v.z / magnitude;

        return v;
    }

    pub fn lengthSquared(v: *const Vec3) f32 {
        return v.dot(v);
    }

    pub fn length(v: *const Vec3) f32 {
        return std.math.sqrt(v.dot(v));
    }

    pub fn distance(self: *Vec3, rhs: *Vec3) f32 {
        return self.sub(rhs).length();
    }

    pub fn lerp(from: *const Vec3, to: *const Vec3, t: f32) Vec3 {
        const clamped_t = @max(0.0, @min(1.0, t));
        return Vec3{
            .x = from.x + clamped_t * (to.x - from.x),
            .y = from.y + clamped_t * (to.y - from.y),
            .z = from.z + clamped_t * (to.z - from.z),
        };
    }

    /// add max of two vectors to result/dest
    pub fn max_add_to(self: *Self, a: Vec3, b: Vec3) void {
        self.x = self.x + @max(a.x, b.x);
        self.y = self.y + @max(a.y, b.y);
        self.z = self.z + @max(a.z, b.z);
    }

    /// add min of two vectors to result/dest
    pub fn min_add_to(self: *Self, a: Vec3, b: Vec3) void {
        self.x = self.x + @min(a.x, b.x);
        self.y = self.y + @min(a.y, b.y);
        self.z = self.z + @min(a.z, b.z);
    }

    /// angle in radians between two vectors
    pub fn angle(a: *const Vec3, b: *const Vec3) f32 {
        const dot_product = a.dot(b);
        const magnitude_a = a.length();
        const magnitude_b = b.length();

        // Handle zero-length vectors
        if (magnitude_a == 0.0 or magnitude_b == 0.0) {
            return 0.0;
        }

        // Clamp dot product to prevent NaN from acos due to floating point precision
        const cos_angle = @max(-1.0, @min(1.0, dot_product / (magnitude_a * magnitude_b)));
        return std.math.acos(cos_angle);
    }

    pub inline fn asCPtrF32(v: *const Vec3) [*c]f32 {
        return @as([*c]f32, @ptrCast(@constCast(v)));
    }

    pub fn asString(self: *const Self, buf: []u8) []u8 {
        return std.fmt.bufPrint(buf, "Vec3{{ {d}, {d}, {d} }}", .{ self.x, self.y, self.z }) catch |err| std.debug.panic("{any}", .{err});
    }

    pub fn clone(self: *const Vec3) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }
};

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{ .x = x, .y = y, .z = z };
}

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn init(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn fromArray(value: [4]f32) Vec4 {
        return @as(*Vec4, @ptrCast(@constCast(&value))).*;
    }

    pub fn asArray(self: *const Vec4) [4]f32 {
        return @as(*[4]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec4) *[4]f32 {
        return @as(*[4]f32, @ptrCast(@constCast(self)));
    }

    pub inline fn asCPtrF32(v: *const Vec4) [*c]f32 {
        return @as([*c]f32, @ptrCast(@constCast(v)));
    }

    pub fn splat(v: f32) Vec4 {
        return .{ .x = v, .y = v, .z = v, .w = v };
    }

    pub fn xyz(self: *const Vec4) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    pub fn scale(v: *const Vec4, s: f32) Vec4 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s, .w = v.w * s };
    }

    pub fn dot(lhs: *const Vec4, rhs: *const Vec4) f32 {
        return (lhs.x * rhs.x) + (lhs.y * rhs.y) + (lhs.z * rhs.z) + (lhs.w * rhs.w);
    }

    pub fn lengthSquared(v: *const Vec4) f32 {
        return v.dot(v);
    }

    pub fn length(v: *const Vec4) f32 {
        return std.math.sqrt(v.lengthSquared());
    }

    pub fn lerp(from: *const Vec4, to: *const Vec4, t: f32) Vec4 {
        const clamped_t = @max(0.0, @min(1.0, t));
        return Vec4{
            .x = from.x + clamped_t * (to.x - from.x),
            .y = from.y + clamped_t * (to.y - from.y),
            .z = from.z + clamped_t * (to.z - from.z),
            .w = from.w + clamped_t * (to.w - from.w),
        };
    }

    pub fn normalize(v: *Vec4) void {
        const length_squared = v.lengthSquared();

        if (length_squared == 0.0) return;

        const magnitude = std.math.sqrt(length_squared);
        v.x = v.x / magnitude;
        v.y = v.y / magnitude;
        v.z = v.z / magnitude;
        v.w = v.w / magnitude;
    }

    pub fn normalizeTo(v: *const Vec4) Vec4 {
        var result = Vec4{ .x = 0.0, .y = 0.0, .z = 0.0, .w = 0.0 };

        const length_squared = v.lengthSquared();

        if (length_squared == 0.0) return result;

        const magnitude = std.math.sqrt(length_squared);

        result.x = v.x / magnitude;
        result.y = v.y / magnitude;
        result.z = v.z / magnitude;
        result.w = v.w / magnitude;

        return result;
    }

    pub fn clone(self: *const Vec4) Vec4 {
        return .{ .x = self.x, .y = self.y, .z = self.z, .w = self.w };
    }

    pub fn toVec3(self: *const Vec4) Vec3 {
        return .{ .x = self.x, .y = self.y, .z = self.z };
    }

    pub fn asString(self: *const Vec4, buf: []u8) []u8 {
        return std.fmt.bufPrint(buf, "Vec4{{ {d}, {d}, {d}, {d} }", .{ self.x, self.y, self.z, self.w }) catch |err| std.debug.panic("{any}", .{err});
    }

};

pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return .{ .x = x, .y = y, .z = z, .w = w };
}

test "Vec3 lerp basic functionality" {
    const from = Vec3.init(0.0, 0.0, 0.0);
    const to = Vec3.init(10.0, 20.0, 30.0);

    // Test t = 0.0 (should return 'from')
    const result_0 = Vec3.lerp(&from, &to, 0.0);
    try std.testing.expectApproxEqAbs(result_0.x, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(result_0.y, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(result_0.z, 0.0, 0.001);

    // Test t = 1.0 (should return 'to')
    const result_1 = Vec3.lerp(&from, &to, 1.0);
    try std.testing.expectApproxEqAbs(result_1.x, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(result_1.y, 20.0, 0.001);
    try std.testing.expectApproxEqAbs(result_1.z, 30.0, 0.001);

    // Test t = 0.5 (should return midpoint)
    const result_half = Vec3.lerp(&from, &to, 0.5);
    try std.testing.expectApproxEqAbs(result_half.x, 5.0, 0.001);
    try std.testing.expectApproxEqAbs(result_half.y, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(result_half.z, 15.0, 0.001);
}

test "Vec3 lerp clamping" {
    const from = Vec3.init(0.0, 0.0, 0.0);
    const to = Vec3.init(10.0, 10.0, 10.0);

    // Test t < 0.0 (should clamp to 0.0)
    const result_neg = Vec3.lerp(&from, &to, -0.5);
    try std.testing.expectApproxEqAbs(result_neg.x, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(result_neg.y, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(result_neg.z, 0.0, 0.001);

    // Test t > 1.0 (should clamp to 1.0)
    const result_over = Vec3.lerp(&from, &to, 1.5);
    try std.testing.expectApproxEqAbs(result_over.x, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(result_over.y, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(result_over.z, 10.0, 0.001);
}

test "Vec4 lerp basic functionality" {
    const from = Vec4.init(0.0, 0.0, 0.0, 0.0);
    const to = Vec4.init(10.0, 20.0, 30.0, 40.0);

    // Test t = 0.5 (should return midpoint)
    const result_half = Vec4.lerp(&from, &to, 0.5);
    try std.testing.expectApproxEqAbs(result_half.x, 5.0, 0.001);
    try std.testing.expectApproxEqAbs(result_half.y, 10.0, 0.001);
    try std.testing.expectApproxEqAbs(result_half.z, 15.0, 0.001);
    try std.testing.expectApproxEqAbs(result_half.w, 20.0, 0.001);
}

test "Vec3 angle calculation" {
    // Test angle between perpendicular unit vectors
    const vec_x = Vec3.init(1.0, 0.0, 0.0);
    const vec_y = Vec3.init(0.0, 1.0, 0.0);
    const angle_90 = Vec3.angle(&vec_x, &vec_y);
    try std.testing.expectApproxEqAbs(angle_90, std.math.pi / 2.0, 0.001);

    // Test angle between parallel vectors (should be 0)
    const vec_a = Vec3.init(1.0, 2.0, 3.0);
    const vec_b = Vec3.init(2.0, 4.0, 6.0); // parallel to vec_a
    const angle_0 = Vec3.angle(&vec_a, &vec_b);
    try std.testing.expectApproxEqAbs(angle_0, 0.0, 0.001);

    // Test angle between opposite vectors (should be π)
    const vec_pos = Vec3.init(1.0, 0.0, 0.0);
    const vec_neg = Vec3.init(-1.0, 0.0, 0.0);
    const angle_180 = Vec3.angle(&vec_pos, &vec_neg);
    try std.testing.expectApproxEqAbs(angle_180, std.math.pi, 0.001);

    // Test with zero vector (should return 0)
    const vec_zero = Vec3.init(0.0, 0.0, 0.0);
    const angle_zero = Vec3.angle(&vec_x, &vec_zero);
    try std.testing.expectApproxEqAbs(angle_zero, 0.0, 0.001);
}

test "Vec4 normalization" {
    // Test in-place normalization
    var vec = Vec4.init(3.0, 4.0, 0.0, 0.0);
    Vec4.normalize(&vec);
    const expected_length = 1.0;
    try std.testing.expectApproxEqAbs(vec.length(), expected_length, 0.001);
    try std.testing.expectApproxEqAbs(vec.x, 0.6, 0.001);
    try std.testing.expectApproxEqAbs(vec.y, 0.8, 0.001);

    // Test normalizeTo (non-mutating)
    const original = Vec4.init(1.0, 2.0, 2.0, 0.0);
    const normalized = Vec4.normalizeTo(&original);
    const original_length = original.length();
    const normalized_length = normalized.length();

    try std.testing.expectApproxEqAbs(original_length, 3.0, 0.001); // Original unchanged
    try std.testing.expectApproxEqAbs(normalized_length, 1.0, 0.001); // Normalized has unit length

    // Test zero vector handling
    var zero_vec = Vec4.init(0.0, 0.0, 0.0, 0.0);
    Vec4.normalize(&zero_vec); // Should not crash
    const zero_normalized = Vec4.normalizeTo(&zero_vec);
    try std.testing.expectApproxEqAbs(zero_normalized.length(), 0.0, 0.001);
}
