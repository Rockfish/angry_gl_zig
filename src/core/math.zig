const std = @import("std");
const cglm = @import("cglm.zig").CGLM;

pub const Vec2 = cglm.vec2;
pub const Vec3 = cglm.vec3;
pub const Vec4 = cglm.vec4;
pub const Versor = cglm.versor;

pub fn vec4_scale(v: Vec4, s: f32) Vec4 {
    return .{
        v[0] * s,
        v[1] * s,
        v[2] * s,
        v[3] * s,
    };
}

pub fn vec3_lerp(from: *Vec3, to: *Vec3, t: f32) Vec3 {
    var result: [3]f32 align(16) = undefined;
    cglm.glmc_vec3_lerp(@constCast(from), @constCast(to),  t, &result);
    return result;
}

pub fn vec4_lerp(from: *Vec4, to: *Vec4, t: f32) Vec4 {
    var result: [4]f32 align(16) = undefined;
    cglm.glmc_vec4_lerp(@constCast(from), @constCast(to),  t, &result);
    return result;
}

pub fn vec4_normalize(v: *Vec4) void {
    cglm.glmc_vec4_normalize(@constCast(v));
}

pub fn vec4_normalize_to(v: *const Vec4) Vec4 {
    var result: [4]f32 align(16) = undefined;
    cglm.glmc_vec4_normalize_to(@constCast(v), &result);
    return result;
}

pub const Mat4 = struct {
    data: [4][4]f32 align(16),

    const Self = @This();

    pub fn identity() Self {
        return Mat4 {
            .data = .{
                .{1.0, 0.0, 0.0, 0.0},
                .{0.0, 1.0, 0.0, 0.0},
                .{0.0, 0.0, 1.0, 0.0},
                .{0.0, 0.0, 0.0, 1.0},
            }
        };
    }

    pub fn zero() Self {
        return Mat4 {
            .data = .{
                .{0.0, 0.0, 0.0, 0.0},
                .{0.0, 0.0, 0.0, 0.0},
                .{0.0, 0.0, 0.0, 0.0},
                .{0.0, 0.0, 0.0, 0.0},
            }
        };
    }

    pub fn toArray(self: *Self) [16]f32 {
        return .{
            self.data[0][0],
            self.data[0][1],
            self.data[0][2],
            self.data[0][3],
            self.data[1][0],
            self.data[1][1],
            self.data[1][2],
            self.data[1][3],
            self.data[2][0],
            self.data[2][1],
            self.data[2][2],
            self.data[2][3],
            self.data[3][0],
            self.data[3][1],
            self.data[3][2],
            self.data[3][3],
        };
    }

    pub fn translation(translationVec3: Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_translate_make(&result, @constCast(&translationVec3));
        return Mat4 { .data = result, };
    }

    pub fn scaling(scaleVec3: Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_scale_make(&result, @constCast(&scaleVec3));
        return Mat4 { .data = result, };
    }

    pub fn perspectiveRhGl(fov: f32, aspect: f32, near: f32, far: f32) Self {
        var projection: [4][4]f32 align(16) = undefined;
        cglm.glmc_perspective_rh_no(fov, aspect, near, far, &projection);
        return Mat4 { .data = projection, };
    }

    pub fn lookRhGl(position: Vec3, front: Vec3, up: Vec3) Self {
        var view: [4][4]f32 align(16) = undefined;
        cglm.glmc_look_rh_no(@constCast(&position), @constCast(&front), @constCast(&up), &view);
        return Mat4 { .data = view, };
    }

    pub fn translate(self: *Self, translationVec3: Vec3) void {
        cglm.glmc_translate(&self.data, @constCast(&translationVec3));
    }

    pub fn scale(self: *Self, scaleVec3: Vec3) void {
        cglm.glmc_scale(&self.data, @constCast(&scaleVec3));
    }

    pub fn mulMat4(self: *Self, other: Mat4) void {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_mul(&self.data, @constCast(&other.data), &result);
        self.data = result;
    }

    pub fn mulVec4(self: *Self, vec: Vec4) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_mulv(&self.data, @constCast(&vec), &result);
        return result;
    }

    pub fn toQuat(self: *Self) Quat {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(&self.data, &result);
        return Quat { .data = result, };
    }

    pub fn rotateVec(self: *Self, v: *const Vec4) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_quat_rotatev(&self.data, @constCast(v), &result);
        return result;
    }

    pub const TrnRotScl = struct {
        translation: Vec4,
        rotation: Quat,
        scale: Vec3,
        };

    pub fn to_scale_rotation_translation(self: *Self) TrnRotScl {
        var tran: [4]f32 align(16) = undefined;
        var rota: [4][4]f32 align(16) = undefined;
        var scal: [3]f32 align(16) = undefined;

        cglm.glmc_decompose(&self.data, &tran, &rota, &scal);
        var quat: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(&self.data, &quat);

        return TrnRotScl{
            .translation = tran,
            .rotation = Quat { .data = quat, },
            .scale = scal,
        };
    }

    pub fn from_scale_rotation_translation(scal: Vec3, rota: Quat, tran: Vec4) Mat4 {
        const axis = Quat.to_axes(rota);

        const mat = Mat4{
            .data = .{
                vec4_scale(axis[0], scal[0]),
                vec4_scale(axis[1], scal[1]),
                vec4_scale(axis[2], scal[2]),
                tran,
            },
        };
        return mat;
    }
    // pub fn to_scale_rotation_translation(&self) -> (Vec3, Quat, Vec3) {
    //         let det = self.determinant();
    //         glam_assert!(det != 0.0);
    //
    //         let scale = Vec3::new(
    //             self.x_axis.length() * math::signum(det),
    //             self.y_axis.length(),
    //             self.z_axis.length(),
    //         );
    //
    //         glam_assert!(scale.cmpne(Vec3::ZERO).all());
    //
    //         let inv_scale = scale.recip();
    //
    //         let rotation = Quat::from_rotation_axes(
    //             self.x_axis.mul(inv_scale.x).xyz(),
    //             self.y_axis.mul(inv_scale.y).xyz(),
    //             self.z_axis.mul(inv_scale.z).xyz(),
    //         );
    //
    //         let translation = self.w_axis.xyz();
    //
    //         (scale, rotation, translation)
    //     }

    // pub fn lookToRh(eyepos: Vec4, eyedir: Vec4, updir: Vec4) Mat4 {
    //     return lookToLh(eyepos, -eyedir, updir);
    // }
    //
    // pub fn lookAtLh(eyepos: Vec4, focuspos: Vec4, updir: Vec4) Mat4 {
    //     return lookToLh(eyepos, focuspos - eyepos, updir);
    // }
    //
    // pub fn lookAtRh(eyepos: Vec4, focuspos: Vec4, updir: Vec4) Mat4 {
    //     return lookToLh(eyepos, eyepos - focuspos, updir);
    // }
};

pub const Quat = struct {
    data: Versor, // is a Vec4

    const Self = @This();

    pub fn identity() Self {
        return Quat { .data = .{0.0, 0.0, 0.0, 1.0} };
    }

    pub fn init(x: f32, y: f32, z: f32, w: f32) Self {
        return Quat { .data = .{x, y, z, w} };
    }

    pub fn fromMat4(mat4: Mat4) Self {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(@constCast(&mat4.data), &result);
        return Quat { .data = result, };
    }

    pub fn mulQuats(p: *const Quat, q: *const Quat) Self {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_quat_mul(@constCast(&p.data), @constCast(&q.data), &result);
        return Quat { .data = result };
    }

    pub fn mulByQuat(self: *Self, other: *const Quat) void {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_quat_mul(&self.data, @constCast(&other.data), &result);
        self.data = result;
    }

    pub fn slerp(self: *Self, rot: *const Quat, t: f32) Quat {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_quat_slerp(&self.data, @constCast(&rot.data), t, &result);
        return Quat { .data = result };
    }

    fn to_axes(rotation: Quat) [3]Vec4 {
        // glam_assert!(rotation.is_normalized());
        const x = rotation.data[0];
        const y = rotation.data[1];
        const z = rotation.data[2];
        const w = rotation.data[3];
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

        const x_axis: Vec4 = .{1.0 - (yy + zz), xy + wz, xz - wy, 0.0};
        const y_axis: Vec4 = .{xy - wz, 1.0 - (xx + zz), yz + wx, 0.0};
        const z_axis: Vec4 = .{xz + wy, yz - wx, 1.0 - (xx + yy), 0.0};
        return .{ x_axis, y_axis, z_axis };
    }
};
