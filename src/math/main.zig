const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const vec = @import("vec.zig");
const mat = @import("mat.zig");
const quat = @import("quat.zig");
const utils = @import("utils.zig");

pub const Versor = cglm.versor;

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

pub const vec2 = vec.vec2;
pub const vec3 = vec.vec3;
pub const vec4 = vec.vec4;

pub const Mat4 = mat.Mat4;
pub const Quat = quat.Quat;

pub const get_world_ray_from_mouse = utils.get_world_ray_from_mouse;
pub const ray_plane_intersection = utils.ray_plane_intersection;
pub const screen_to_model_glam = utils.screen_to_model_glam;

pub const inf = std.math.inf;
pub const sqrt = std.math.sqrt;
pub const pow = std.math.pow;
pub const sin = std.math.sin;
pub const cos = std.math.cos;
pub const acos = std.math.acos;
pub const isNan = std.math.isNan;
pub const isInf = std.math.isInf;
pub const pi = std.math.pi;
pub const clamp = std.math.clamp;
pub const log10 = std.math.log10;
pub const degreesToRadians = std.math.degreesToRadians;
pub const radiansToDegrees = std.math.radiansToDegrees;
pub const maxInt = std.math.maxInt;
pub const lerp = std.math.lerp;

/// 2/sqrt(π)
pub const two_sqrtpi = std.math.two_sqrtpi;

/// sqrt(2)
pub const sqrt2 = std.math.sqrt2;

/// 1/sqrt(2)
pub const sqrt1_2 = std.math.sqrt1_2;

// This is the difference between 1.0 and the next larger representable number. copied from rust.
pub const epsilon: f32 = 1.19209290e-07;
