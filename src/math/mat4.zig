const std = @import("std");
const _vec = @import("vec.zig");
const _quat = @import("quat.zig");

const Vec3 = _vec.Vec3;
const Vec4 = _vec.Vec4;
const Quat = _quat.Quat;

pub fn mat4(x_axis: Vec4, y_axis: Vec4, z_axis: Vec4, w_axis: Vec4) Mat4 {
    return Mat4.fromColumns(x_axis, y_axis, z_axis, w_axis);
}

/// 4x4 matrix with column-major storage and operations.
///
/// The data is stored as data[column][row], where:
/// - data[0] = first column (x-axis for transforms)
/// - data[1] = second column (y-axis for transforms)
/// - data[2] = third column (z-axis for transforms)
/// - data[3] = fourth column (translation for transforms)
///
/// This follows OpenGL and CGLM conventions for matrix storage and multiplication.
/// Matrix-vector multiplication assumes column vectors: result = matrix * vector.
pub const Mat4 = extern struct {
    data: [4][4]f32,

    const Self = @This();

    pub fn identity() Self {
        return Mat4{ .data = .{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };
    }

    pub fn zero() Self {
        return Mat4{ .data = .{
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
        } };
    }

    pub fn fromColumns(x_axis: Vec4, y_axis: Vec4, z_axis: Vec4, w_axis: Vec4) Self {
        return Mat4{ .data = .{
            x_axis.asArray(),
            y_axis.asArray(),
            z_axis.asArray(),
            w_axis.asArray(),
        } };
    }

    pub fn fromAxes(axes: [3]Vec4) Self {
        // axes[0]: right, axes[1]: up, axes[2]: forward
        const right = axes[0];
        const up = axes[1];
        const forward = axes[2];

        // Construct 4x4 matrix:
        // [ right.x   up.x   forward.x   0 ]
        // [ right.y   up.y   forward.y   0 ]
        // [ right.z   up.z   forward.z   0 ]
        // [    0       0        0        1 ]
        var result: [4][4]f32 = undefined;
        result[0][0] = right.x;
        result[1][0] = right.y;
        result[2][0] = right.z;
        result[3][0] = 0.0;

        result[0][1] = up.x;
        result[1][1] = up.y;
        result[2][1] = up.z;
        result[3][1] = 0.0;

        result[0][2] = forward.x;
        result[1][2] = forward.y;
        result[2][2] = forward.z;
        result[3][2] = 0.0;

        result[0][3] = 0.0;
        result[1][3] = 0.0;
        result[2][3] = 0.0;
        result[3][3] = 1.0;

        return .{ .data = result };
    }

    pub fn toArray(self: *const Self) [16]f32 {
        return @as(*[16]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn toArrayPtr(self: *const Self) *[16]f32 {
        return @as(*[16]f32, @ptrCast(@constCast(self)));
    }

    pub fn getTranspose(m: *const Mat4) Mat4 {
        // Unrolled matrix transpose: result[i][j] = m[j][i]
        return Mat4{ .data = .{
            .{ m.data[0][0], m.data[1][0], m.data[2][0], m.data[3][0] },
            .{ m.data[0][1], m.data[1][1], m.data[2][1], m.data[3][1] },
            .{ m.data[0][2], m.data[1][2], m.data[2][2], m.data[3][2] },
            .{ m.data[0][3], m.data[1][3], m.data[2][3], m.data[3][3] },
        } };
    }

    pub fn getInverse(m: *const Mat4) Self {
        // Calculate matrix inverse using cofactor expansion
        // This is optimized for 4x4 matrices commonly used in 3D graphics
        const d = m.data;

        // Calculate 2x2 subdeterminants for 3x3 cofactors
        const sub_00 = d[2][2] * d[3][3] - d[3][2] * d[2][3];
        const sub_01 = d[2][1] * d[3][3] - d[3][1] * d[2][3];
        const sub_02 = d[2][1] * d[3][2] - d[3][1] * d[2][2];
        const sub_03 = d[2][0] * d[3][3] - d[3][0] * d[2][3];
        const sub_04 = d[2][0] * d[3][2] - d[3][0] * d[2][2];
        const sub_05 = d[2][0] * d[3][1] - d[3][0] * d[2][1];
        const sub_06 = d[1][2] * d[3][3] - d[3][2] * d[1][3];
        const sub_07 = d[1][1] * d[3][3] - d[3][1] * d[1][3];
        const sub_08 = d[1][1] * d[3][2] - d[3][1] * d[1][2];
        const sub_09 = d[1][0] * d[3][3] - d[3][0] * d[1][3];
        const sub_10 = d[1][0] * d[3][2] - d[3][0] * d[1][2];
        const sub_11 = d[1][1] * d[3][3] - d[3][1] * d[1][3];
        const sub_12 = d[1][0] * d[3][1] - d[3][0] * d[1][1];
        const sub_13 = d[1][2] * d[2][3] - d[2][2] * d[1][3];
        const sub_14 = d[1][1] * d[2][3] - d[2][1] * d[1][3];
        const sub_15 = d[1][1] * d[2][2] - d[2][1] * d[1][2];
        const sub_16 = d[1][0] * d[2][3] - d[2][0] * d[1][3];
        const sub_17 = d[1][0] * d[2][2] - d[2][0] * d[1][2];
        const sub_18 = d[1][0] * d[2][1] - d[2][0] * d[1][1];

        // Calculate 3x3 cofactors
        const cof_00 = (d[1][1] * sub_00 - d[1][2] * sub_01 + d[1][3] * sub_02);
        const cof_01 = -(d[1][0] * sub_00 - d[1][2] * sub_03 + d[1][3] * sub_04);
        const cof_02 = (d[1][0] * sub_01 - d[1][1] * sub_03 + d[1][3] * sub_05);
        const cof_03 = -(d[1][0] * sub_02 - d[1][1] * sub_04 + d[1][2] * sub_05);

        // Calculate determinant
        const det = d[0][0] * cof_00 + d[0][1] * cof_01 + d[0][2] * cof_02 + d[0][3] * cof_03;

        // Check for singular matrix
        if (@abs(det) < 1e-8) {
            // Return identity matrix for singular matrices
            return Mat4.identity();
        }

        const inv_det = 1.0 / det;

        // Calculate remaining cofactors and build result matrix
        const cof_10 = -(d[0][1] * sub_00 - d[0][2] * sub_01 + d[0][3] * sub_02);
        const cof_11 = (d[0][0] * sub_00 - d[0][2] * sub_03 + d[0][3] * sub_04);
        const cof_12 = -(d[0][0] * sub_01 - d[0][1] * sub_03 + d[0][3] * sub_05);
        const cof_13 = (d[0][0] * sub_02 - d[0][1] * sub_04 + d[0][2] * sub_05);

        const cof_20 = (d[0][1] * sub_06 - d[0][2] * sub_07 + d[0][3] * sub_08);
        const cof_21 = -(d[0][0] * sub_06 - d[0][2] * sub_09 + d[0][3] * sub_10);
        const cof_22 = (d[0][0] * sub_11 - d[0][1] * sub_09 + d[0][3] * sub_12);
        const cof_23 = -(d[0][0] * sub_08 - d[0][1] * sub_10 + d[0][2] * sub_12);

        const cof_30 = -(d[0][1] * sub_13 - d[0][2] * sub_14 + d[0][3] * sub_15);
        const cof_31 = (d[0][0] * sub_13 - d[0][2] * sub_16 + d[0][3] * sub_17);
        const cof_32 = -(d[0][0] * sub_14 - d[0][1] * sub_16 + d[0][3] * sub_18);
        const cof_33 = (d[0][0] * sub_15 - d[0][1] * sub_17 + d[0][2] * sub_18);

        return Mat4{ .data = .{
            .{ cof_00 * inv_det, cof_10 * inv_det, cof_20 * inv_det, cof_30 * inv_det },
            .{ cof_01 * inv_det, cof_11 * inv_det, cof_21 * inv_det, cof_31 * inv_det },
            .{ cof_02 * inv_det, cof_12 * inv_det, cof_22 * inv_det, cof_32 * inv_det },
            .{ cof_03 * inv_det, cof_13 * inv_det, cof_23 * inv_det, cof_33 * inv_det },
        } };
    }

    pub fn fromTranslation(t: *const Vec3) Self {
        return Mat4{ .data = .{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ t.x, t.y, t.z, 1.0 },
        } };
    }

    pub fn fromScale(s: *const Vec3) Self {
        return Mat4{ .data = .{
            .{ s.x, 0.0, 0.0, 0.0 },
            .{ 0.0, s.y, 0.0, 0.0 },
            .{ 0.0, 0.0, s.z, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };
    }

    pub fn fromRotationX(angle: f32) Mat4 {
        // X-axis rotation matrix - matches cglm glm_rotate_x implementation
        const cos_a = std.math.cos(angle);
        const sin_a = std.math.sin(angle);

        return Mat4{ .data = .{
            .{ 1.0, 0.0, 0.0, 0.0 },
            .{ 0.0, cos_a, sin_a, 0.0 },
            .{ 0.0, -sin_a, cos_a, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };
    }

    pub fn fromRotationY(angle: f32) Mat4 {
        // Y-axis rotation matrix - matches cglm glm_rotate_y implementation
        const cos_a = std.math.cos(angle);
        const sin_a = std.math.sin(angle);

        return Mat4{ .data = .{
            .{ cos_a, 0.0, -sin_a, 0.0 },
            .{ 0.0, 1.0, 0.0, 0.0 },
            .{ sin_a, 0.0, cos_a, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };
    }

    pub fn fromRotationZ(angle: f32) Mat4 {
        // Z-axis rotation matrix - matches cglm glm_rotate_z implementation
        const cos_a = std.math.cos(angle);
        const sin_a = std.math.sin(angle);

        return Mat4{ .data = .{
            .{ cos_a, sin_a, 0.0, 0.0 },
            .{ -sin_a, cos_a, 0.0, 0.0 },
            .{ 0.0, 0.0, 1.0, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };
    }

    pub fn fromAxisAngle(axis: *const Vec3, angleRadians: f32) Mat4 {
        // Rodrigues' rotation formula for creating rotation matrix from axis-angle
        const normalized_axis = axis.normalizeTo();
        const x = normalized_axis.x;
        const y = normalized_axis.y;
        const z = normalized_axis.z;

        const cos_a = std.math.cos(angleRadians);
        const sin_a = std.math.sin(angleRadians);
        const one_minus_cos = 1.0 - cos_a;

        return Mat4{ .data = .{ .{ cos_a + x * x * one_minus_cos, y * x * one_minus_cos + z * sin_a, z * x * one_minus_cos - y * sin_a, 0.0 }, .{ x * y * one_minus_cos - z * sin_a, cos_a + y * y * one_minus_cos, z * y * one_minus_cos + x * sin_a, 0.0 }, .{ x * z * one_minus_cos + y * sin_a, y * z * one_minus_cos - x * sin_a, cos_a + z * z * one_minus_cos, 0.0 }, .{ 0.0, 0.0, 0.0, 1.0 } } };
    }

    pub fn translate(self: *Self, translationVec3: *const Vec3) void {
        const translation_matrix = Mat4.fromTranslation(translationVec3);
        self.mulByMat4(&translation_matrix);
    }

    pub fn scale(self: *Self, scaleVec3: *const Vec3) void {
        const scale_matrix = Mat4.fromScale(scaleVec3);
        self.mulByMat4(&scale_matrix);
    }

    pub fn rotateByDegrees(self: *Self, axis: *const Vec3, angleDegrees: f32) void {
        const angleRadians = std.math.degreesToRadians(angleDegrees);
        const rotation_matrix = Mat4.fromAxisAngle(axis, angleRadians);
        self.mulByMat4(&rotation_matrix);
    }

    pub fn mulMat4(self: *const Self, other: *const Mat4) Self {
        var result: [4][4]f32 = undefined;

        // Column-major matrix multiplication following cglm convention
        // Matches glm_mat4_mul implementation in cglm/mat4.h
        // dest[col][row] = Σ(m1[col][k] * m2[k][row])

        const m1 = &self.data;
        const m2 = &other.data;

        // Column 0 of result
        result[0][0] = m1[0][0] * m2[0][0] + m1[1][0] * m2[0][1] + m1[2][0] * m2[0][2] + m1[3][0] * m2[0][3];
        result[0][1] = m1[0][1] * m2[0][0] + m1[1][1] * m2[0][1] + m1[2][1] * m2[0][2] + m1[3][1] * m2[0][3];
        result[0][2] = m1[0][2] * m2[0][0] + m1[1][2] * m2[0][1] + m1[2][2] * m2[0][2] + m1[3][2] * m2[0][3];
        result[0][3] = m1[0][3] * m2[0][0] + m1[1][3] * m2[0][1] + m1[2][3] * m2[0][2] + m1[3][3] * m2[0][3];

        // Column 1 of result
        result[1][0] = m1[0][0] * m2[1][0] + m1[1][0] * m2[1][1] + m1[2][0] * m2[1][2] + m1[3][0] * m2[1][3];
        result[1][1] = m1[0][1] * m2[1][0] + m1[1][1] * m2[1][1] + m1[2][1] * m2[1][2] + m1[3][1] * m2[1][3];
        result[1][2] = m1[0][2] * m2[1][0] + m1[1][2] * m2[1][1] + m1[2][2] * m2[1][2] + m1[3][2] * m2[1][3];
        result[1][3] = m1[0][3] * m2[1][0] + m1[1][3] * m2[1][1] + m1[2][3] * m2[1][2] + m1[3][3] * m2[1][3];

        // Column 2 of result
        result[2][0] = m1[0][0] * m2[2][0] + m1[1][0] * m2[2][1] + m1[2][0] * m2[2][2] + m1[3][0] * m2[2][3];
        result[2][1] = m1[0][1] * m2[2][0] + m1[1][1] * m2[2][1] + m1[2][1] * m2[2][2] + m1[3][1] * m2[2][3];
        result[2][2] = m1[0][2] * m2[2][0] + m1[1][2] * m2[2][1] + m1[2][2] * m2[2][2] + m1[3][2] * m2[2][3];
        result[2][3] = m1[0][3] * m2[2][0] + m1[1][3] * m2[2][1] + m1[2][3] * m2[2][2] + m1[3][3] * m2[2][3];

        // Column 3 of result
        result[3][0] = m1[0][0] * m2[3][0] + m1[1][0] * m2[3][1] + m1[2][0] * m2[3][2] + m1[3][0] * m2[3][3];
        result[3][1] = m1[0][1] * m2[3][0] + m1[1][1] * m2[3][1] + m1[2][1] * m2[3][2] + m1[3][1] * m2[3][3];
        result[3][2] = m1[0][2] * m2[3][0] + m1[1][2] * m2[3][1] + m1[2][2] * m2[3][2] + m1[3][2] * m2[3][3];
        result[3][3] = m1[0][3] * m2[3][0] + m1[1][3] * m2[3][1] + m1[2][3] * m2[3][2] + m1[3][3] * m2[3][3];

        return Mat4{ .data = result };
    }

    pub fn mulByMat4(self: *Self, other: *const Mat4) void {
        const temp = self.mulMat4(other);
        self.data = temp.data;
    }

    pub fn mulVec4(self: *const Self, vec: *const Vec4) Vec4 {
        // Column-major matrix-vector multiplication following cglm convention
        // Matches glm_mat4_mulv implementation in cglm/mat4.h
        // result[i] = Σ(matrix[j][i] * vec[j]) - sum across columns
        return Vec4{
            .x = self.data[0][0] * vec.x + self.data[1][0] * vec.y + self.data[2][0] * vec.z + self.data[3][0] * vec.w,
            .y = self.data[0][1] * vec.x + self.data[1][1] * vec.y + self.data[2][1] * vec.z + self.data[3][1] * vec.w,
            .z = self.data[0][2] * vec.x + self.data[1][2] * vec.y + self.data[2][2] * vec.z + self.data[3][2] * vec.w,
            .w = self.data[0][3] * vec.x + self.data[1][3] * vec.y + self.data[2][3] * vec.z + self.data[3][3] * vec.w,
        };
    }

    pub fn toQuat(self: *const Self) Quat {
        // Convert 4x4 rotation matrix to quaternion using Shepperd's method
        const m = &self.data;

        // Calculate trace
        const trace = m[0][0] + m[1][1] + m[2][2];

        if (trace > 0.0) {
            // Standard case
            const s = std.math.sqrt(trace + 1.0) * 2.0; // s = 4 * qw
            const qw = 0.25 * s;
            const qx = (m[2][1] - m[1][2]) / s;
            const qy = (m[0][2] - m[2][0]) / s;
            const qz = (m[1][0] - m[0][1]) / s;
            return Quat{ .data = .{ qx, qy, qz, qw } };
        } else if (m[0][0] > m[1][1] and m[0][0] > m[2][2]) {
            // m[0][0] is largest
            const s = std.math.sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0; // s = 4 * qx
            const qw = (m[2][1] - m[1][2]) / s;
            const qx = 0.25 * s;
            const qy = (m[0][1] + m[1][0]) / s;
            const qz = (m[0][2] + m[2][0]) / s;
            return Quat{ .data = .{ qx, qy, qz, qw } };
        } else if (m[1][1] > m[2][2]) {
            // m[1][1] is largest
            const s = std.math.sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0; // s = 4 * qy
            const qw = (m[0][2] - m[2][0]) / s;
            const qx = (m[0][1] + m[1][0]) / s;
            const qy = 0.25 * s;
            const qz = (m[1][2] + m[2][1]) / s;
            return Quat{ .data = .{ qx, qy, qz, qw } };
        } else {
            // m[2][2] is largest
            const s = std.math.sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0; // s = 4 * qz
            const qw = (m[1][0] - m[0][1]) / s;
            const qx = (m[0][2] + m[2][0]) / s;
            const qy = (m[1][2] + m[2][1]) / s;
            const qz = 0.25 * s;
            return Quat{ .data = .{ qx, qy, qz, qw } };
        }
    }

    pub fn perspectiveRhGl(fov: f32, aspect: f32, near: f32, far: f32) Self {
        // Right-handed perspective projection matrix for OpenGL (Z from -1 to 1)
        const f = 1.0 / std.math.tan(fov * 0.5);
        const range_inv = 1.0 / (near - far);

        return Mat4{ .data = .{
            .{ f / aspect, 0.0, 0.0, 0.0 },
            .{ 0.0, f, 0.0, 0.0 },
            .{ 0.0, 0.0, (far + near) * range_inv, -1.0 },
            .{ 0.0, 0.0, 2.0 * far * near * range_inv, 0.0 },
        } };
    }

    pub fn orthographicRhGl(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Self {
        // Right-handed orthographic projection matrix for OpenGL (Z from -1 to 1)
        const width_inv = 1.0 / (right - left);
        const height_inv = 1.0 / (top - bottom);
        const depth_inv = 1.0 / (near - far);

        return Mat4{ .data = .{
            .{ 2.0 * width_inv, 0.0, 0.0, 0.0 },
            .{ 0.0, 2.0 * height_inv, 0.0, 0.0 },
            .{ 0.0, 0.0, 2.0 * depth_inv, 0.0 },
            .{ -(right + left) * width_inv, -(top + bottom) * height_inv, (far + near) * depth_inv, 1.0 },
        } };
    }

    pub fn lookAtRhGl(eye: *const Vec3, center: *const Vec3, up: *const Vec3) Self {
        // CGLM-compatible right-handed look-at implementation
        // Forward vector: center - eye (direction from eye TO center)
        const f = center.sub(eye).normalizeTo();

        // Right vector: cross(forward, up) - note the order!
        const s = f.crossNormalized(up);

        // Up vector: cross(right, forward)
        const u = s.crossNormalized(&f);

        // Direct matrix construction matching CGLM exactly
        return Mat4{
            .data = .{
                .{ s.x, u.x, -f.x, 0.0 }, // Column 0: right.x, up.x, -forward.x
                .{ s.y, u.y, -f.y, 0.0 }, // Column 1: right.y, up.y, -forward.y
                .{ s.z, u.z, -f.z, 0.0 }, // Column 2: right.z, up.z, -forward.z
                .{ -s.dot(eye), -u.dot(eye), f.dot(eye), 1.0 }, // Column 3: translation
            },
        };
    }

    pub fn lookToRhGl(eye: *const Vec3, direction: *const Vec3, up: *const Vec3) Self {
        // CGLM-compatible: target = eye + direction, then use lookAt
        const target = eye.add(direction);
        return lookAtRhGl(eye, &target, up);
    }

    pub fn removeTranslation(self: *const Self) Mat4 {
        return Mat4{ .data = .{
            .{ self.data[0][0], self.data[0][1], self.data[0][2], 0.0 },
            .{ self.data[1][0], self.data[1][1], self.data[1][2], 0.0 },
            .{ self.data[2][0], self.data[2][1], self.data[2][2], 0.0 },
            .{ 0.0, 0.0, 0.0, 0.0 },
        } };
    }

    pub fn fromTranslationRotationScale(tran: *const Vec3, rota: *const Quat, scal: *const Vec3) Mat4 {
        const axis = Quat.toAxes(rota);

        const mat = Mat4{
            .data = .{
                axis[0].scale(scal.x).asArray(),
                axis[1].scale(scal.y).asArray(),
                axis[2].scale(scal.z).asArray(),
                .{ tran.x, tran.y, tran.z, 1.0 },
            },
        };
        return mat;
    }

    pub fn asString(self: *const Self, buf: []u8) []u8 {
        return std.fmt.bufPrint(
            buf,
            "Mat4{{[{d:.3}, {d:.3}, {d:.3}, {d:.3}], [{d:.3}, {d:.3}, {d:.3}, {d:.3}], [{d:.3}, {d:.3}, {d:.3}, {d:.3}], [{d:.3}, {d:.3}, {d:.3}, {d:.3}]}}",
            .{
                self.data[0][0], self.data[0][1], self.data[0][2], self.data[0][3],
                self.data[1][0], self.data[1][1], self.data[1][2], self.data[1][3],
                self.data[2][0], self.data[2][1], self.data[2][2], self.data[2][3],
                self.data[3][0], self.data[3][1], self.data[3][2], self.data[3][3],
            },
        ) catch |err| std.debug.panic("{any}", .{err});
    }
};
