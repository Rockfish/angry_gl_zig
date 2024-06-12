const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const vec = @import("vec.zig");
const mat = @import("mat.zig");
const quat = @import("quat.zig");

pub const Versor = cglm.versor;

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

pub const vec2 = vec.vec2;
pub const vec3 = vec.vec3;
pub const vec4 = vec.vec4;

pub const Mat4 = mat.Mat4;
pub const Quat = quat.Quat;
