const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const _vec = @import("vec.zig");
const _quat = @import("quat.zig");

const Vec3 = _vec.Vec3;
const Vec4 = _vec.Vec4;
const Quat = _quat.Quat;

pub fn mat4(x_axis: Vec4, y_axis: Vec4, z_axis: Vec4, w_axis: Vec4) Mat4 {
    return Mat4.from_cols(x_axis, y_axis, z_axis, w_axis);
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

    pub fn from_cols(x_axis: Vec4, y_axis: Vec4, z_axis: Vec4, w_axis: Vec4) Self {
        return Mat4 {
            .data = .{
                x_axis.asArray(),
                y_axis.asArray(),
                z_axis.asArray(),
                w_axis.asArray(),
            }
        };
    }

    pub fn toArray(self: *const Self) [16]f32 {
        return @as(*[16]f32, @ptrCast(@alignCast(@constCast(self)))).*;
        // return .{
        //     self.data[0][0],
        //     self.data[0][1],
        //     self.data[0][2],
        //     self.data[0][3],
        //     self.data[1][0],
        //     self.data[1][1],
        //     self.data[1][2],
        //     self.data[1][3],
        //     self.data[2][0],
        //     self.data[2][1],
        //     self.data[2][2],
        //     self.data[2][3],
        //     self.data[3][0],
        //     self.data[3][1],
        //     self.data[3][2],
        //     self.data[3][3],
        // };
    }

    pub fn toArrayPtr(self: *const Self) *[16]f32 {
        return @as(*[16]f32, @ptrCast(@alignCast(@constCast(self))));
    }

    pub fn getInverse(m: *const Mat4) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_inv(@constCast(&m.data), &result);
        return Mat4 { .data = result, };
    }

    pub fn fromTranslation(translationVec3: *const Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_translate_make(&result, @as(*[3]f32, @ptrCast(@alignCast(@constCast(&translationVec3)))));
        return Mat4 { .data = result, };
    }

    pub fn fromScale(scaleVec3: *const Vec3) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_scale_make(&result, @as(*[3]f32, @ptrCast(@alignCast(@constCast(&scaleVec3)))));
        return Mat4 { .data = result, };
    }

    pub fn fromRotationX(angle: f32) Mat4 {
        var result: [4][4]f32 align(16) = undefined;
        const axis: [3]f32 = .{1.0, 0.0, 0.0};
        cglm.glmc_rotate_make(&result, angle, @as(*[3]f32, @ptrCast(@alignCast(@constCast(&axis)))));
        return Mat4 { .data = result, };
    }

    pub fn fromRotationY(angle: f32) Mat4 {
        var result: [4][4]f32 align(16) = undefined;
        const axis: [3]f32 = .{0.0, 1.0, 0.0};
        cglm.glmc_rotate_make(&result, angle, @as(*[3]f32, @ptrCast(@alignCast(@constCast(&axis)))));
        return Mat4 { .data = result, };
    }

    pub fn fromRotationZ(angle: f32) Mat4 {
        var result: [4][4]f32 align(16) = undefined;
        const axis: [3]f32 = .{0.0, 0.0, 1.0};
        cglm.glmc_rotate_make(&result, angle, @as(*[3]f32, @ptrCast(@alignCast(@constCast(&axis)))));
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

    pub fn lookAtRhGl(eye: *const Vec3, center: *const Vec3, up: *const Vec3) Self {
        var view: [4][4]f32 align(16) = undefined;
        cglm.glmc_lookat_rh_no(@as([*c]f32, @ptrCast(@alignCast(@constCast(eye)))), @as([*c]f32, @ptrCast(@alignCast(@constCast(center)))), @as([*c]f32, @ptrCast(@alignCast(@constCast(up)))), &view);
        return Mat4 { .data = view, };
    }

    pub fn lookRhGl(eye: *const Vec3, direction: *const Vec3, up: *const Vec3) Self {
        var view: [4][4]f32 align(16) = undefined;
        cglm.glmc_look_rh_no(@as([*c]f32, @ptrCast(@alignCast(@constCast(eye)))), @as([*c]f32, @ptrCast(@alignCast(@constCast(direction)))), @as([*c]f32, @ptrCast(@alignCast(@constCast(up)))), &view);
        return Mat4 { .data = view, };
    }

    pub fn translate(self: *Self, translationVec3: *const Vec3) void {
        cglm.glmc_translate(@constCast(&self.data), @as([*c]f32, @ptrCast(@alignCast(@constCast(translationVec3)))));
    }

    pub fn scale(self: *Self, scaleVec3: *const Vec3) void {
        cglm.glmc_scale(@constCast(&self.data), @as([*c]f32, @ptrCast(@alignCast(@constCast(scaleVec3)))));
    }

    pub fn mulMat4(self: *const Self, other: *const Mat4) Self {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_mul(@constCast(&self.data), @constCast(&other.data), &result);
        return Mat4 { .data = result, };
    }

    pub fn mulByMat4(self: *Self, other: *const Mat4) void {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_mat4_mul(@constCast(&self.data), @constCast(&other.data), &result);
        self.data = result;
    }

    pub fn mulVec4(self: *const Self, vec: *const Vec4) Vec4 {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_mulv(@constCast(&self.data), @as(*[4]f32, @ptrCast(@alignCast(@constCast(vec)))), &result);
        return @as(*Vec4, @ptrCast(&result)).*;
    }

    pub fn toQuat(self: *const Self) Quat {
        var result: [4]f32 align(16) = undefined;
        cglm.glmc_mat4_quat(@constCast(&self.data), &result);
        return Quat { .data = result, };
    }

    // @brief creates NEW rotation matrix by angle and axis
    //
    // axis will be normalized so you don't need to normalize it
    //
    // @param[out] m     affine transform
    // @param[in]  angle angle (radians)
    // @param[in]  axis  axis
    pub fn fromAxisAngle(axis: *const Vec3, angle: f32) Mat4 {
        var result: [4][4]f32 align(16) = undefined;
        cglm.glmc_rotate_make(&result, angle,  @as([*c]f32, @ptrCast(@alignCast(@constCast(axis)))));
        return Mat4 { .data = result, };
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
                axis[0].scale(scal.x).asArray(),
                axis[1].scale(scal.y).asArray(),
                axis[2].scale(scal.z).asArray(),
                .{tran.x, tran.y, tran.z, 1.0},
            },
        };
        return mat;
    }



    // pub fn to_scale_rotation_translation(&self) (Vec3, Quat, Vec3) {
    //         const det = self.determinant();
    //         glam_assert!(det != 0.0);
    //
    //         const scale = Vec3.new(
    //             self.x_axis.length() * math.signum(det),
    //             self.y_axis.length(),
    //             self.z_axis.length(),
    //         );
    //
    //         glam_assert!(scale.cmpne(Vec3.ZERO).all());
    //
    //         const inv_scale = scale.recip();
    //
    //         const rotation = Quat.from_rotation_axes(
    //             self.x_axis.mul(inv_scale.x).xyz(),
    //             self.y_axis.mul(inv_scale.y).xyz(),
    //             self.z_axis.mul(inv_scale.z).xyz(),
    //         );
    //
    //         const translation = self.w_axis.xyz();
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

