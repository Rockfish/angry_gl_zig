const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const _vec = @import("vec.zig");
const _quat = @import("quat.zig");

const Vec3 = _vec.Vec3;
const Vec4 = _vec.Vec4;
const Quat = _quat.Quat;

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

    pub fn toArray(self: *const Self) [16]f32 {
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

    pub fn getInverse(m: *const Mat4) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_inv(@constCast(&m.data), &result);
        return Mat4 { .data = result, };
    }

    pub fn translation(translationVec3: *const Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_translate_make(&result, @constCast(&translationVec3.data));
        return Mat4 { .data = result, };
    }

    pub fn scaling(scaleVec3: *const Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_scale_make(&result, @constCast(&scaleVec3.data));
        return Mat4 { .data = result, };
    }

    pub fn perspectiveRhGl(fov: f32, aspect: f32, near: f32, far: f32) Self {
        var projection: [4][4]f32 align(16) = undefined;
        cglm.glmc_perspective_rh_no(fov, aspect, near, far, &projection);
        return Mat4 { .data = projection, };
    }

    pub fn orthographicRhGl(left: f32, right: f32, top: f32, bottom: f32, near: f32, far: f32) Self {
        var ortho: [4][4]f32 align(16) = undefined;
        cglm.glmc_ortho_rh_no(left, right, bottom, top, near, far, &ortho);
        return Mat4 { .data = ortho, };
    }

    pub fn lookRhGl(position: *const Vec3, front: *const Vec3, up: *const Vec3) Self {
        var view: [4][4]f32 align(16) = undefined;
        cglm.glmc_look_rh_no(@constCast(&position.data), @constCast(&front.data), @constCast(&up.data), &view);
        return Mat4 { .data = view, };
    }

    pub fn translate(self: *Self, translationVec3: *const Vec3) void {
        cglm.glmc_translate(&self.data, @constCast(&translationVec3.data));
    }

    pub fn scale(self: *Self, scaleVec3: *const Vec3) void {
        cglm.glmc_scale(&self.data, @constCast(&scaleVec3.data));
    }

    pub fn mulMat4(self: *Self, other: *const Mat4) void {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_mul(&self.data, @constCast(&other.data), &result);
        self.data = result;
    }

    pub fn mulVec4(self: *Self, vec: *const Vec4) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_mulv(&self.data, @constCast(&vec.data), &result);
        return Vec4 { .data = result };
    }

    pub fn toQuat(self: *Self) Quat {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(&self.data, &result);
        return Quat { .data = result, };
    }

    pub const TrnRotScl = struct {
        translation: Vec3,
        rotation: Quat,
        scale: Vec3,
        };

    pub fn to_scale_rotation_translation(self: *const Self) TrnRotScl {
        var tran: [4]f32 align(16) = undefined;
        var rota: [4][4]f32 align(16) = undefined;
        var scal: [3]f32 align(16) = undefined;

        cglm.glmc_decompose(@constCast(&self.data), &tran, &rota, &scal);

        var quat: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(@constCast(&self.data), &quat);

        return TrnRotScl{
            .translation = Vec3.new(tran[0], tran[1], tran[2]),
            .rotation = Quat { .data = quat, },
            .scale = Vec3.fromArray(scal),
        };
    }

    pub fn from_scale_rotation_translation(scal: *const Vec3, rota: *const Quat, tran: *const Vec3) Mat4 {
        const axis = Quat.to_axes(rota);

        const mat = Mat4{
            .data = .{
                axis[0].scale(scal.data[0]).data,
                axis[1].scale(scal.data[1]).data,
                axis[2].scale(scal.data[2]).data,
                .{tran.data[0], tran.data[1], tran.data[2], 1.0},
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

