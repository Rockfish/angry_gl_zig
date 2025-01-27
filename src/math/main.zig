const std = @import("std");
pub const cglm = @import("cglm.zig").CGLM;
const vec = @import("vec.zig");
const mat3_ = @import("mat3.zig");
const mat4_ = @import("mat4.zig");
const quat_ = @import("quat.zig");
const ray_ = @import("ray.zig");
const utils = @import("utils.zig");

pub const Versor = cglm.versor;

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

pub const vec2 = vec.vec2;
pub const vec3 = vec.vec3;
pub const vec4 = vec.vec4;
pub const quat = quat_.quat;

pub const Mat3 = mat3_.Mat3;
pub const Mat4 = mat4_.Mat4;
pub const Quat = quat_.Quat;

pub const mat3 = mat3_.mat3;
pub const mat4 = mat4_.mat4;

pub const getWorldRayFromMouse = utils.getWorldRayFromMouse;
pub const screenToModelGlam = utils.screenToModelGlam;
pub const getRayPlaneIntersection = utils.getRayPlaneIntersection;
pub const getRayTriangleIntersection = ray_.getRayTriangleIntersection;
pub const getRaySphereIntersection = ray_.getRaySphereIntersection;
pub const calculateNormal = utils.calculateNormal;

// @abs
pub const inf = std.math.inf;
pub const sqrt = std.math.sqrt;
pub const pow = std.math.pow;
pub const sin = std.math.sin;
pub const cos = std.math.cos;
pub const acos = std.math.acos;
pub const tan = std.math.tan;
pub const atan = std.math.atan;
pub const isNan = std.math.isNan;
pub const isInf = std.math.isInf;
pub const clamp = std.math.clamp;
pub const log10 = std.math.log10;
pub const degreesToRadians = std.math.degreesToRadians;
pub const radiansToDegrees = std.math.radiansToDegrees;
pub const lerp = std.math.lerp;

pub const pi: f32 = @as(f32, std.math.pi);
pub const tau: f32 = @as(f32, std.math.tau);
pub const reciprocal_pi = 1.0 / pi;

pub const minFloat: f32 = std.math.floatMin(f32);
pub const maxFloat: f32 = std.math.floatMax(f32);

/// 2/sqrt(π)
pub const two_sqrtpi = std.math.two_sqrtpi;

/// sqrt(2)
pub const sqrt2 = std.math.sqrt2;

/// 1/sqrt(2)
pub const sqrt1_2 = std.math.sqrt1_2;

// This is the difference between 1.0 and the next larger representable number. copied from rust.
pub const epsilon: f32 = 1.19209290e-07;

pub fn truncate(v: Vec2, max: f32) Vec2 {
    if (v.length() > max) {
        const v2 = v.normalize_or_zero();
        return v2.mul(max);
    }
    return v;
}

pub fn wrapAround(pos: *Vec2, max_x: i32, max_y: i32) void {
    const max_x_f32: f32 = @floatCast(max_x);
    const max_y_f32: f32 = @floatCast(max_y);
    if (pos.x > max_x_f32) {
        pos.x -= max_x_f32;
    }

    if (pos.x < 0.0) {
        pos.x += max_x_f32;
    }

    if (pos.y < 0.0) {
        pos.y += max_y_f32;
    }

    if (pos.y > max_y_f32) {
        pos.y -= max_y_f32;
    }
}
