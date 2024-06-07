const std = @import("std");
const math = @import("math.zig");

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const vec3_normalize = math.vec3_normalize;
const vec3_cross = math.vec3_cross;
const vec3_lerp = math.vec3_lerp;
const vec3_mul = math.vec3_mul;
const vec3_add = math.vec3_add;

pub const Transform = struct {
    translation: Vec3,
    rotation: Quat,
    scale: Vec3,

    const Self = @This();

    pub fn from_matrix(m: *const Mat4) Transform {
        const trs = m.to_scale_rotation_translation();
        return Transform {
            .translation = trs.translation,
            .rotation = trs.rotation,
            .scale = trs.scale,
        };
    }

    pub fn default() Transform {
        return from_matrix(&Mat4.identity());
    }

    pub fn mul_transform_weighted(self: *const Self, transform: Transform, weight: f32) Self {
        const translation = vec3_lerp(&self.translation, &transform.translation, weight);
        const rotation = self.rotation.slerp(&transform.rotation, weight);
        const scale = vec3_lerp(&self.scale, &transform.scale, weight);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn mul_transform(self: *const Self, transform: Transform) Self {
        const translation = self.transform_point(transform.translation);
        const rotation = Quat.mulQuats(&self.rotation, &transform.rotation);
        const scale = vec3_mul(&self.scale, &transform.scale);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn transform_point(self: *const Self, point: Vec3) Vec3 {
        var _point = vec3_mul(&self.scale, &point);
        _point = self.rotation.rotateVec(&_point);
        _point = vec3_add(&self.translation, &_point);
        return _point;
    }

    pub fn compute_matrix(self: Self) Mat4 {
        return  Mat4.from_scale_rotation_translation(&self.scale, &self.rotation, &self.translation);
    }
};

// pub fn from_scale_rotation_translation(scale: Vec4, rotation: Quat, translation: Vec4) Mat4 {
//     const axis = quat_to_axes(rotation);
//
//     const mat = Mat4{
//         zm.mul(axis[0], scale[0]),
//         zm.mul(axis[1], scale[1]),
//         zm.mul(axis[2], scale[2]),
//         translation,
//     };
//     return mat;
// }
//
// fn quat_to_axes(rotation: zm.Quat) [3]zm.Vec4 {
//     // glam_assert!(rotation.is_normalized());
//     const x = rotation[0];
//     const y = rotation[1];
//     const z = rotation[2];
//     const w = rotation[3];
//     const x2 = x + x;
//     const y2 = y + y;
//     const z2 = z + z;
//     const xx = x * x2;
//     const xy = x * y2;
//     const xz = x * z2;
//     const yy = y * y2;
//     const yz = y * z2;
//     const zz = z * z2;
//     const wx = w * x2;
//     const wy = w * y2;
//     const wz = w * z2;
//
//     const x_axis = vec4(1.0 - (yy + zz), xy + wz, xz - wy, 0.0);
//     const y_axis = vec4(xy - wz, 1.0 - (xx + zz), yz + wx, 0.0);
//     const z_axis = vec4(xz + wy, yz - wx, 1.0 - (xx + yy), 0.0);
//     return .{ x_axis, y_axis, z_axis };
// }
