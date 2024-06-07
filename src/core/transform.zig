const std = @import("std");
const zm = @import("zmath");

const Allocator = std.mem.Allocator;

const Vec2 = zm.Vec2;
const Vec3 = zm.Vec3;
const Vec4 = zm.Vec4;
const vec2 = zm.vec2;
const vec3 = zm.vec3;
const vec4 = zm.vec4;
const Mat4 = zm.Mat4;
const Quat = zm.Quat;

pub const Transform = struct {
    translation: zm.Vec4,
    rotation: zm.Quat,
    scale: zm.Vec4,

    const Self = @This();

    pub fn from_matrix(m: zm.Mat4) Transform {
        var transform = Transform{
            .translation = zm.util.getTranslationVec(m),
            .rotation = zm.util.getRotationQuat(m),
            .scale = zm.util.getScaleVec(m),
        };
        transform.translation[3] = 1.0;
        transform.scale[3] = 1.0;
        return transform;
    }

    pub fn default() Transform {
        var transform = from_matrix(zm.identity());
        transform.translation[3] = 1.0;
        transform.scale[3] = 1.0;
        return transform;
    }

    pub fn mul_transform_weighted(self: *const Self, transform: Transform, weight: f32) Self {
        const translation = zm.lerp(self.translation, transform.translation, weight);
        const rotation = zm.slerp(self.rotation, transform.rotation, weight);
        const scale = zm.lerp(self.scale, transform.scale, weight);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn mul_transform(self: *const Self, transform: Transform) Self {
        const translation = self.transform_point(transform.translation);
        // const rotation = zm.qmul(self.rotation, transform.rotation);
        const rotation = zm.qmul(transform.rotation, self.rotation); // zm.mul requires reversed operands!!!!
        const scale = self.scale * transform.scale;
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn transform_point(self: *const Self, point: zm.Vec4) zm.Vec4 {
        var _point = self.scale * point;
        _point = zm.rotate(self.rotation, _point);
        _point += self.translation;
        return _point;
    }

    pub fn compute_matrix(self: Self) zm.Mat4 {
        return from_scale_rotation_translation(self.scale, self.rotation, self.translation);
    }
};

pub fn from_scale_rotation_translation(scale: Vec4, rotation: Quat, translation: Vec4) zm.Mat4 {
    const axis = quat_to_axes(rotation);

    const mat = Mat4{
        zm.mul(axis[0], scale[0]),
        zm.mul(axis[1], scale[1]),
        zm.mul(axis[2], scale[2]),
        translation,
    };
    return mat;
}

fn quat_to_axes(rotation: zm.Quat) [3]zm.Vec4 {
    // glam_assert!(rotation.is_normalized());
    const x = rotation[0];
    const y = rotation[1];
    const z = rotation[2];
    const w = rotation[3];
    const x2 = x + x;
    const y2 = y + y;
    const z2 = z + z;
    const xx = x * x2;
    const xy = x * y2;
    const xz = x * z2;
    const yy = y * y2;
    const yz = y * z2;
    const zz = z * z2;
    const wx = w * x2;
    const wy = w * y2;
    const wz = w * z2;

    const x_axis = vec4(1.0 - (yy + zz), xy + wz, xz - wy, 0.0);
    const y_axis = vec4(xy - wz, 1.0 - (xx + zz), yz + wx, 0.0);
    const z_axis = vec4(xz + wy, yz - wx, 1.0 - (xx + yy), 0.0);
    return .{ x_axis, y_axis, z_axis };
}
