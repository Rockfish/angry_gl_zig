const std = @import("std");
const zm = @import("zmath");

pub const Vec2 = zm.Vec2;
pub const Vec3 = zm.Vec3;
pub const Vec4 = zm.Vec4;
pub const vec2 = zm.vec2;
pub const vec3 = zm.vec3;
pub const Mat4 = zm.Mat4;

pub const Matrix = struct {
    data: zm.Mat4,

    const Self = @This();

    pub fn identity() Self {
        return Matrix {
            .data = zm.identity(),
        };
    }

    pub fn asPtr(self: *const Self) [*]const f32 {
        return @as([*]const f32, @ptrCast(&self.data));
    }

    pub fn translate(self: *Self, translation: zm.Vec3) void {
        const _t = zm.translationV(zm.loadArr3(translation));
        self.data = zm.mul(self.data, _t);
    }

    pub fn scale(self: *Self, scaling: zm.Vec3) void {
        const _s = zm.scalingV(zm.loadArr3(scaling));
        self.data = zm.mul(self.data, _s);
    }

    pub fn multiplyWithVec3(self: *Self, vec: zm.Vec3) void {
        const result = zm.matMulVec(self.data, vec);
        self.data = result;
    }

    pub fn multiplyWithMatrix(self: *Self, mat: Matrix) void {
        const result = zm.mul(self.data, mat.data);
        self.data = result;
    }

    pub fn multiplyWithMat(self: *Self, mat: zm.Mat4) void {
        const result = zm.mul(self.data, mat);
        self.data = result;
    }

    pub fn perspectiveFovRhGl(fovy: f32, aspect: f32, near: f32, far: f32) Self {
        const result = zm.perspectiveFovRhGl(fovy, aspect, near, far);
        return Matrix {
            .data = result
        };
    }

    pub fn lookToLh(eyepos: Vec3, eyedir: Vec3, updir: Vec3) Self {
        const result = zm.lookToRh(zm.loadArr3(eyepos), zm.loadArr3(eyedir), zm.loadArr3(updir));
        return Matrix {
            .data = result
        };
    }

    pub fn lookToRh(eyepos: Vec3, eyedir: Vec3, updir: Vec3) Self {
        const result = zm.lookToRh(zm.loadArr3(eyepos), zm.loadArr3(eyedir), zm.loadArr3(updir));
        return Matrix {
            .data = result
        };
    }

    pub fn lookAtLh(eyepos: Vec3, target: Vec3, updir: Vec3) Self {
        const result = zm.lookAtLh(zm.loadArr3(eyepos), zm.loadArr3(target), zm.loadArr3(updir));
        return Matrix {
            .data = result
        };
    }

    pub fn lookAtRh(eyepos: Vec3, target: Vec3, updir: Vec3) Self {
        const result = zm.lookAtRh(zm.loadArr3(eyepos), zm.loadArr3(target), zm.loadArr3(updir));
        return Matrix {
            .data = result
        };
    }

};

// qmul(q0: Quat, q1: Quat) Quat
// qidentity() Quat
// conjugate(quat: Quat) Quat
// inverse(q: Quat) Quat
// rotate(q: Quat, v: Vec) Vec
// slerp(q0: Quat, q1: Quat, t: f32) Quat
// slerpV(q0: Quat, q1: Quat, t: F32x4) Quat
// quatToMat(quat: Quat) Mat
// quatToAxisAngle(quat: Quat, axis: *Vec, angle: *f32) void
// quatFromMat(m: Mat) Quat
// quatFromAxisAngle(axis: Vec, angle: f32) Quat
// quatFromNormAxisAngle(axis: Vec, angle: f32) Quat
// quatFromRollPitchYaw(pitch: f32, yaw: f32, roll: f32) Quat
// quatFromRollPitchYawV(angles: Vec) Quat
pub const Quaternion = struct {
    data: zm.Quat,

    const Self = @This();

    pub fn identity() Self {
        return Quaternion {
            .data = zm.qidentity(),
        };
    }

    pub fn fromMatrix(mat: Matrix) Self {
        return zm.quatFromMat(mat.data);
    }

    // add dual to vec
    pub fn rotate(self: *Self, axis: zm.Vec4) zm.Vec4 {
        return zm.rotate(self.data, axis);
    }

};


