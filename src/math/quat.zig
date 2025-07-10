const std = @import("std");
const vec = @import("vec.zig");
const mat4_ = @import("mat4.zig");
const utils = @import("utils.zig");

const Vec3 = vec.Vec3;
const Vec4 = vec.Vec4;
const Mat4 = mat4_.Mat4;
pub const Versor = [4]f32;

pub const asCF32 = utils.asCF32;

pub fn quat(x: f32, y: f32, z: f32, w: f32) Quat {
    return Quat{ .data = .{ x, y, z, w } };
}

pub const Quat = extern struct {
    data: [4]f32,

    const Self = @This();

    pub fn identity() Self {
        return Quat{ .data = .{ 0.0, 0.0, 0.0, 1.0 } };
    }

    pub fn default() Self {
        return Quat{ .data = .{ 0.0, 0.0, 0.0, 1.0 } };
    }

    pub fn init(x: f32, y: f32, z: f32, w: f32) Self {
        return Quat{ .data = .{ x, y, z, w } };
    }

    pub fn clone(self: *const Self) Quat {
        return Quat{ .data = self.data };
    }

    pub fn fromArray(val: [4]f32) Self {
        return Quat{ .data = .{ val[0], val[1], val[2], val[3] } };
    }

    pub fn fromMat4(mat4: Mat4) Quat {
        // Use the Mat4.toQuat() method which we've already implemented
        return mat4.toQuat();
    }

    pub fn fromAxisAngle(axis: *const Vec3, angle: f32) Quat {
        // glam_assert!(axis.is_normalized());
        const normalized_axis = axis.normalizeTo();
        const s = std.math.sin(angle * 0.5);
        const c = std.math.cos(angle * 0.5);
        const v = normalized_axis.mulScalar(s);
        return init(v.x, v.y, v.z, c);
    }

    pub inline fn asCPtrF32(q: *const Quat) [*c]f32 {
        return @as([*c]f32, @ptrCast(@constCast(q)));
    }

    pub fn normalize(self: *Self) void {
        const length_squared = self.data[0] * self.data[0] + self.data[1] * self.data[1] + self.data[2] * self.data[2] + self.data[3] * self.data[3];

        if (length_squared == 0.0) {
            // Set to identity quaternion if zero length
            self.data = .{ 0.0, 0.0, 0.0, 1.0 };
            return;
        }

        const inv_length = 1.0 / std.math.sqrt(length_squared);
        self.data[0] *= inv_length;
        self.data[1] *= inv_length;
        self.data[2] *= inv_length;
        self.data[3] *= inv_length;
    }

    pub fn normalizeTo(q: *const Quat) Quat {
        const length_squared = q.data[0] * q.data[0] + q.data[1] * q.data[1] + q.data[2] * q.data[2] + q.data[3] * q.data[3];

        if (length_squared == 0.0) {
            // Return identity quaternion if zero length
            return Quat{ .data = .{ 0.0, 0.0, 0.0, 1.0 } };
        }

        const inv_length = 1.0 / std.math.sqrt(length_squared);
        return Quat{ .data = .{
            q.data[0] * inv_length,
            q.data[1] * inv_length,
            q.data[2] * inv_length,
            q.data[3] * inv_length,
        } };
    }

    pub fn mulQuat(p: *const Quat, q: *const Quat) Quat {
        // Quaternion multiplication: (p * q)
        // Formula: result = [pw*qx + px*qw + py*qz - pz*qy,
        //                   pw*qy - px*qz + py*qw + pz*qx,
        //                   pw*qz + px*qy - py*qx + pz*qw,
        //                   pw*qw - px*qx - py*qy - pz*qz]
        // Where p = [px, py, pz, pw] and q = [qx, qy, qz, qw]
        const px = p.data[0];
        const py = p.data[1];
        const pz = p.data[2];
        const pw = p.data[3];
        const qx = q.data[0];
        const qy = q.data[1];
        const qz = q.data[2];
        const qw = q.data[3];

        return Quat{
            .data = .{
                pw * qx + px * qw + py * qz - pz * qy, // x
                pw * qy - px * qz + py * qw + pz * qx, // y
                pw * qz + px * qy - py * qx + pz * qw, // z
                pw * qw - px * qx - py * qy - pz * qz, // w
            },
        };
    }

    pub fn mulByQuat(self: *Self, other: *const Quat) void {
        const temp = self.mulQuat(other);
        self.data = temp.data;
    }

    pub fn rotateVec(self: *const Self, v: *const Vec3) Vec3 {
        // Rotate vector v by quaternion self using the formula:
        // v' = q * (0, v) * q^-1
        // Optimized version: v' = v + 2 * cross(q.xyz, cross(q.xyz, v) + q.w * v)
        const qx = self.data[0];
        const qy = self.data[1];
        const qz = self.data[2];
        const qw = self.data[3];
        const vx = v.x;
        const vy = v.y;
        const vz = v.z;

        // First cross product: cross(q.xyz, v) + q.w * v
        const cx1 = qy * vz - qz * vy + qw * vx;
        const cy1 = qz * vx - qx * vz + qw * vy;
        const cz1 = qx * vy - qy * vx + qw * vz;

        // Second cross product: cross(q.xyz, cross(q.xyz, v) + q.w * v)
        const cx2 = qy * cz1 - qz * cy1;
        const cy2 = qz * cx1 - qx * cz1;
        const cz2 = qx * cy1 - qy * cx1;

        // Final result: v + 2 * cross(q.xyz, cross(q.xyz, v) + q.w * v)
        return Vec3{
            .x = vx + 2.0 * cx2,
            .y = vy + 2.0 * cy2,
            .z = vz + 2.0 * cz2,
        };
    }

    pub fn slerp(self: *const Self, rot: *const Quat, t: f32) Quat {
        const clamped_t = @max(0.0, @min(1.0, t));

        // Compute dot product
        var dot = self.data[0] * rot.data[0] + self.data[1] * rot.data[1] + self.data[2] * rot.data[2] + self.data[3] * rot.data[3];

        // Take the shorter path by flipping one quaternion if dot product is negative
        var q2 = rot.*;
        if (dot < 0.0) {
            q2.data[0] = -q2.data[0];
            q2.data[1] = -q2.data[1];
            q2.data[2] = -q2.data[2];
            q2.data[3] = -q2.data[3];
            dot = -dot;
        }

        // If quaternions are very close, use linear interpolation to avoid division by zero
        if (dot > 0.9995) {
            const lerp_result = Quat{ .data = .{
                self.data[0] + clamped_t * (q2.data[0] - self.data[0]),
                self.data[1] + clamped_t * (q2.data[1] - self.data[1]),
                self.data[2] + clamped_t * (q2.data[2] - self.data[2]),
                self.data[3] + clamped_t * (q2.data[3] - self.data[3]),
            } };
            return lerp_result.normalizeTo();
        }

        // Spherical interpolation
        const theta_0 = std.math.acos(@max(-1.0, @min(1.0, dot)));
        const sin_theta_0 = std.math.sin(theta_0);
        const theta = theta_0 * clamped_t;
        const sin_theta = std.math.sin(theta);

        const s0 = std.math.cos(theta) - dot * sin_theta / sin_theta_0;
        const s1 = sin_theta / sin_theta_0;

        return Quat{ .data = .{
            s0 * self.data[0] + s1 * q2.data[0],
            s0 * self.data[1] + s1 * q2.data[1],
            s0 * self.data[2] + s1 * q2.data[2],
            s0 * self.data[3] + s1 * q2.data[3],
        } };
    }

    pub fn toAxes(rotation: *const Quat) [3]Vec4 {
        // glam_assert!(rotation.is_normalized());
        const normalized_rotation = rotation.normalizeTo();
        const x = normalized_rotation.data[0];
        const y = normalized_rotation.data[1];
        const z = normalized_rotation.data[2];
        const w = normalized_rotation.data[3];
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

        const x_axis: Vec4 = Vec4.init(1.0 - (yy + zz), xy + wz, xz - wy, 0.0);
        const y_axis: Vec4 = Vec4.init(xy - wz, 1.0 - (xx + zz), yz + wx, 0.0);
        const z_axis: Vec4 = Vec4.init(xz + wy, yz - wx, 1.0 - (xx + yy), 0.0);
        return .{ x_axis, y_axis, z_axis };
    }

    pub fn lookAtOrientation(position: Vec3, target: Vec3, up: Vec3) Quat {
        // Calculate direction vector
        var dir = target.sub(&position);
        if (dir.lengthSquared() == 0.0) {
            return Quat.identity();
        }
        dir.normalize();

        // Normalize up vector
        var up_normalized = up;
        up_normalized.normalize();

        // Calculate right vector (cross product of forward and up)
        const right = dir.crossNormalized(&up_normalized);

        // Recalculate up vector to ensure orthogonality
        const new_up = right.crossNormalized(&dir);

        // Create rotation matrix from basis vectors
        const rotation_matrix = Mat4{ .data = .{
            .{ right.x, right.y, right.z, 0.0 },
            .{ new_up.x, new_up.y, new_up.z, 0.0 },
            .{ dir.x, dir.y, dir.z, 0.0 },
            .{ 0.0, 0.0, 0.0, 1.0 },
        } };

        // Convert rotation matrix to quaternion
        return rotation_matrix.toQuat();
    }
};
