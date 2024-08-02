const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const _vec = @import("vec.zig");
// const _quat = @import("quat.zig");

const Vec3 = _vec.Vec3;
const Vec4 = _vec.Vec4;
// const Quat = _quat.Quat;

pub fn mat3(x_axis: Vec3, y_axis: Vec3, z_axis: Vec3) Mat3 {
    return Mat3.from_cols(x_axis, y_axis, z_axis);
}

pub const Mat3 = extern struct {
    data: [3][3]f32,

    const Self = @This();

    pub fn from_cols(x_axis: Vec3, y_axis: Vec3, z_axis: Vec3) Self {
        return Mat3{ .data = .{ x_axis.asArray(), y_axis.asArray(), z_axis.asArray() } };
    }

    pub fn toArray(self: *const Self) [9]f32 {
        return @as(*[9]f32, @ptrCast(@constCast(self))).*;
    }

    pub fn toArrayPtr(self: *const Self) *[9]f32 {
        return @as(*[9]f32, @ptrCast(@constCast(self)));
    }

    pub fn determinant(self: *const Self) f32 {
        const x_axis = Vec3.fromArray(self.data[0]);
        const y_axis = Vec3.fromArray(self.data[1]);
        const z_axis = Vec3.fromArray(self.data[2]);
        return z_axis.dot(&x_axis.cross(&y_axis));
    }
};
