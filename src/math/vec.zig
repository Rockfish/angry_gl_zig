const std = @import("std");
const cglm = @import("cglm.zig").CGLM;

pub const Vec2 = struct {
    data: [2]f32,

    pub fn default() Vec2 {
        return Vec2 { .data = .{0.0, 0.0} };
    }

    pub fn new(x: f32, y: f32) Vec2 {
        return Vec2 { .data = .{x, y} };
    }
};

pub fn vec2(x: f32, y: f32) Vec2 {
    return Vec2 { .data = .{x, y} };
}

pub const Vec3 = struct {
    data: [3]f32,

    pub fn default() Vec3 {
        return Vec3 { .data = .{0.0, 0.0, 0.0} };
    }

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3 { .data = .{x, y, z} };
    }

    pub fn fromArray(value: [3]f32) Vec3 {
        return Vec3 { .data = value };
    }

    pub fn normalize(v: *const Vec3) Vec3 {
        var n: [3]f32 = undefined;
        cglm.glm_vec3_normalize_to(@constCast(&v.data), &n);
        return Vec3 { .data = n };
    }

    pub fn add(a: *const Vec3, b: *const Vec3) Vec3 {
        return Vec3 { .data = .{a.data[0] + b.data[0], a.data[1] + b.data[1], a.data[2] + b.data[2]} };
    }

    pub fn sub(a: *const Vec3, b: *const Vec3) Vec3 {
        return Vec3 { .data = .{a.data[0] - b.data[0], a.data[1] - b.data[1], a.data[2] - b.data[2]} };
    }

    pub fn mul(a: *const Vec3, b: *const Vec3) Vec3 {
        return Vec3 { .data = .{a.data[0] * b.data[0], a.data[1] * b.data[1], a.data[2] * b.data[2]} };
    }

    pub fn addScalar(a: *const Vec3, b: f32) Vec3 {
        return Vec3 { .data = .{a.data[0] + b, a.data[1] + b, a.data[2] + b} };
    }

    pub fn mulScalar(a: *const Vec3, b: f32) Vec3 {
        return Vec3 { .data = .{a.data[0] * b, a.data[1] * b, a.data[2] * b} };
    }

    pub fn dot(lhs: *const Vec3, rhs: Vec3) f32 {
        return (lhs.x * rhs.x) + (lhs.y * rhs.y) + (lhs.z * rhs.z);
    }

    pub fn cross(arg_a: *const Vec3, arg_b: *const Vec3) Vec3 {
        const _a = &arg_a.data;
        const _b = &arg_b.data;
        var c: [3]f32 = undefined;
        c[0] = _a[1] * _b[2] - _a[2] * _b[1];
        c[1] = _a[2] * _b[0] - _a[0] * _b[2];
        c[2] = _a[0] * _b[1] - _a[1] * _b[0];
        // var result: [3]f32 = undefined;
        // cglm.glmc_vec3_cross(@constCast(&a.data),@constCast(&b.data), &result);
        return Vec3 { .data = c };
    }

    pub fn lerp(from: *const Vec3, to: *const Vec3, t: f32) Vec3 {
        var result: [3]f32 align(16) = undefined;
        cglm.glm_vec3_lerp(@constCast(&from.data), @constCast(&to.data),  t, &result);
        return Vec3 { .data = result };
    }
};

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3 { .data = .{x, y, z} };
}

pub const Vec4 = struct {
    data: [4]f32,

    pub fn new(x: f32, y: f32, z: f32, w: f32) Vec4 {
        return Vec4 { .data = .{x, y, z, w} };
    }

    pub fn scale(v: *const Vec4, s: f32) Vec4 {
        return Vec4 { .data = .{ v.data[0] * s, v.data[1] * s, v.data[2] * s, v.data[3] * s, } };
    }

    pub fn lerp(from: *const Vec4, to: *const Vec4, t: f32) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glm_vec4_lerp(@constCast(from.data), @constCast(to.data),  t, &result);
        return Vec4 { .data = result };
    }

    pub fn normalize(v: *Vec4) void {
        cglm.glm_vec4_normalize(v.data);
    }

    pub fn normalizeTo(v: *const Vec4) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glm_vec4_normalize_to(@constCast(v.data), &result);
        return Vec4 { .data = result };
    }
};

pub fn vec4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return Vec4 { .data = .{x, y, z, w} };
}

