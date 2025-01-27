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

    pub fn fromMatrix(m: *const Mat4) Transform {
        const trs = m.getTranslationRotationScale();
        return Transform {
            .translation = trs.translation,
            .rotation = trs.rotation,
            .scale = trs.scale,
        };
    }

    pub fn default() Transform {
        return fromMatrix(&Mat4.identity());
    }

    pub fn init() Transform {
        return fromMatrix(&Mat4.identity());
    }

    pub fn clear(self: *Self) void {
        self.translation = Vec3.zero();
        self.rotation = Quat.identity();
        self.scale = Vec3.one();
    }

    pub fn mulTransformWeighted(self: *const Self, transform: Transform, weight: f32) Self {
        const translation = self.translation.lerp( &transform.translation, weight);
        const rotation = self.rotation.slerp(&transform.rotation, weight);
        const scale = self.scale.lerp(&transform.scale, weight);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn mulTransform(self: *const Self, transform: Transform) Self {
        const translation = self.transformPoint(transform.translation);
        const rotation = Quat.mulQuat(&self.rotation, &transform.rotation);
        const scale = self.scale.mul(&transform.scale);
        return Transform{
            .translation = translation,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn transformPoint(self: *const Self, point: Vec3) Vec3 {
        var _point = self.scale.mul(&point);
        _point = self.rotation.rotateVec(&_point);
        _point = self.translation.add(&_point);
        return _point;
    }

    pub fn getMatrix(self: *const Self) Mat4 {
        return  Mat4.fromTranslationRotationScale(&self.translation, &self.rotation, &self.scale);
    }

    pub fn asString(self: *const Self, buf: []u8) [:0]u8 {
        return std.fmt.bufPrintZ(buf, "{{.translation={{{d}, {d}, {d}}} .rotation={{{d}, {d}, {d}, {d}}} .scale={{{d}, {d}, {d}}}}}",
            .{self.translation.x, self.translation.y, self.translation.z,
              self.rotation.data[0], self.rotation.data[1], self.rotation.data[2], self.rotation.data[3],
              self.scale.x, self.scale.y, self.scale.z},
        ) catch @panic("bufPrintZ error.");
    }

    pub fn equal(self: *const Self, other: Transform) bool {
        return self.translation.x == other.translation.x
            and self.translation.y == other.translation.y
            and self.translation.z == other.translation.z
            and self.rotation.data[0] == other.rotation.data[0]
            and self.rotation.data[1] == other.rotation.data[1]
            and self.rotation.data[2] == other.rotation.data[2]
            and self.rotation.data[3] == other.rotation.data[3]
            and self.scale.x == self.scale.x
            and self.scale.y == self.scale.y
            and self.scale.z == self.scale.z;
    }
};

