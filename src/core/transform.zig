const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

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

    pub fn init() Transform {
        return from_matrix(&Mat4.identity());
    }

    pub fn clear(self: *Self) void {
        self.translation = Vec3.zero();
        self.rotation = Quat.identity();
        self.scale = Vec3.one();
    }

    pub fn mul_transform_weighted(self: *const Self, transform: Transform, weight: f32) Self {
        const translation = self.translation.lerp( &transform.translation, weight);
        const rotation = self.rotation.slerp(&transform.rotation, weight);
        const scale = self.scale.lerp(&transform.scale, weight);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn mul_transform(self: *const Self, transform: Transform) Self {
        const translation = self.transform_point(transform.translation);
        const rotation = Quat.mulQuat(&self.rotation, &transform.rotation);
        const scale = self.scale.mul(&transform.scale);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn transform_point(self: *const Self, point: Vec3) Vec3 {
        var _point = self.scale.mul(&point);
        _point = self.rotation.rotateVec(&_point);
        _point = self.translation.add(&_point);
        return _point;
    }

    pub fn get_matrix(self: *const Self) Mat4 {
        return  Mat4.from_scale_rotation_translation(&self.scale, &self.rotation, &self.translation);
    }

    pub fn asString(self: *Self, buf: []u8) std.fmt.BufPrintError![:0]u8 {
        return std.fmt.bufPrintZ(buf, "{{.translation={{{d}, {d}, {d}}} .rotation={{{d}, {d}, {d}, {d}}} .scale={{{d}, {d}, {d}}}}}",
            .{self.translation.x, self.translation.y, self.translation.z,
              self.rotation.data[0], self.rotation.data[1], self.rotation.data[2], self.rotation.data[3],
              self.scale.x, self.scale.y, self.scale.z},
        );
    }
};

