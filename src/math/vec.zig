const std = @import("std");
const cglm = @import("cglm.zig").CGLM;

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn new(x: f32, y: f32) Vec2 {
        return .{ .x = x, .y = y };
    }

    pub fn default() Vec2 {
        return .{ .x = 0.0, .y = 0.0 };
    }

    pub fn asArray(self: *const Vec2) [2]f32 {
        return @as(*[2]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec2) *[2]f32 {
        return @as(*[2]f32, @ptrCast(@constCast(self)));
    }

    pub fn lengthSquared(v: *const Vec2) f32 {
        return v.dot(v);
    }

    pub fn dot(lhs: *const Vec2, rhs: *const Vec2) f32 {
        return (lhs.x * rhs.x) + (lhs.y * rhs.y);
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

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn default() Vec3 {
        return .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    pub fn splat(v: f32) Vec3 {
        return .{ .x = v, .y = v, .z = v };
    }

    pub fn fromArray(value: [3]f32) Vec3 {
        return @as(*Vec3, @ptrCast(@constCast(&value))).*;
    }

    pub fn asArray(self: *const Vec3) [3]f32 {
        return @as(*[3]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec3) *[3]f32 {
        return @as(*[3]f32, @ptrCast(@constCast(self)));
    }

    pub fn normalize(v: *const Vec3) Vec3 {
        var result: [3]f32 = undefined;
        cglm.glm_vec3_normalize_to(@as([*c]f32, @ptrCast(@constCast(v))), &result);
        return @as(*Vec3, @ptrCast(&result)).*;
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
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn mul(a: *const Vec3, b: *const Vec3) Vec3 {
        return .{ .x = a.x * b.x, .y = a.y * b.y, .z = a.z * b.z };
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

    pub fn cross(a: *const Vec3, rhs: *const Vec3) Vec3 {
        return Vec3{
            .x = a.y * rhs.z - a.z * rhs.y,
            .y = a.z * rhs.x - a.x * rhs.z,
            .z = a.x * rhs.y - a.y * rhs.x,
        };
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
        var result: [3]f32 = undefined;
        cglm.glm_vec3_lerp(
            @as([*c]f32, @ptrCast(@constCast(from))),
            @as([*c]f32, @ptrCast(@constCast(to))),
            t,
            &result,
        );
        return @as(*Vec3, @ptrCast(&result)).*;
    }

    /// add max of two vectors to result/dest
    pub fn max_add_to(self: *Self, a: Vec3, b: Vec3) void {
        self.x = self.x + @max(a.x, b.x);
        self.y = self.y + @max(a.y, b.y);
        self.z = self.z + @max(a.z, b.z);
    }

    /// add min of two vectors to result/dest
    pub fn min_add_to(self: *Self, a: Vec3, b: Vec3) void {
        self.x = @min(a.x, b.x);
        self.y = @min(a.y, b.y);
        self.z = @min(a.z, b.z);
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

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }

    pub fn asArray(self: *const Vec4) [4]f32 {
        return @as(*[4]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn asArrayPtr(self: *const Vec4) *[4]f32 {
        return @as(*[4]f32, @ptrCast(@constCast(self)));
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

    pub fn lerp(from: *const Vec4, to: *const Vec4, t: f32) Vec4 {
        var result: [4]f32 = undefined;
        cglm.glmc_vec4_lerp(
            @as([*c]f32, @ptrCast(@constCast(from))),
            @as([*c]f32, @ptrCast(@constCast(to))),
            t,
            &result,
        );
        return @as(*Vec4, @ptrCast(&result)).*;
    }

    pub fn normalize(v: *Vec4) void {
        cglm.glmc_vec4_normalize(v);
    }

    pub fn normalizeTo(v: *const Vec4) Vec4 {
        var result: [4]f32 = undefined;
        cglm.glmc_vec4_normalize_to(
            @as([*c]f32, @ptrCast(@constCast(v))),
            &result,
        );
        return @as(*Vec4, @ptrCast(&result)).*;
    }
};

pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return .{ .x = x, .y = y, .z = z, .w = w };
}
