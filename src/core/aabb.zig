const std = @import("std");
const math = @import("math");

const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

pub const AxisXYZ = enum {
    x,
    y,
    z,
};

const axis_xyz = [_]AxisXYZ{ AxisXYZ.x, AxisXYZ.y, AxisXYZ.z };

pub const Ray = struct {
    origin: Vec3,
    direction: Vec3,
};

pub const AABB = extern struct {
    min: Vec3,
    max: Vec3,

    const Self = @This();

    pub fn init() Self {
        return .{
            .min = vec3(math.maxFloat, math.maxFloat, math.maxFloat),
            .max = vec3(math.minFloat, math.minFloat, math.minFloat),
        };
    }

    // pub fn from_mesh() void {}

    pub fn expand_to_include(self: *Self, v: Vec3) void {
        self.min.x = @min(self.min.x, v.x);
        self.min.y = @min(self.min.y, v.y);
        self.min.z = @min(self.min.z, v.z);
        self.max.x = @max(self.max.x, v.x);
        self.max.y = @max(self.max.y, v.y);
        self.max.z = @max(self.max.z, v.z);
    }

    pub fn expand_by(self: *Self, f: f32) void {
        self.min.x -= f;
        self.max.x += f;
        self.min.y -= f;
        self.max.y += f;
        self.min.z -= f;
        self.max.z += f;
    }

    /// check if AABB constains point
    pub fn contains_point(self: *Self, point: Vec3) bool {
        // zig fmt: off
        return point.x >= self.min.x and point.x <= self.max.x
           and point.y >= self.min.y and point.y <= self.max.y
           and point.z >= self.min.z and point.z <= self.max.z;
        // zig fmt: on
    }

    /// check if two AABB intersects
    pub fn aabb_intersects(a: *const Self, b: *const Self) bool {
        // zig fmt: off
        return a.min.x <= b.max.x and a.max.x >= b.min.x
           and a.min.y <= b.max.y and a.max.y >= b.min.y
           and a.min.z <= b.max.z and a.max.z >= b.min.z;
        // zig fmt: on
    }

    /// old way: check if two AABB intersects
    // pub fn aabbs_intersect(a: *Self, b: *Self) bool {
    //     // zig fmt: off
    //     return a.contains_point(vec3(b.min.x, b.min.y, b.min.z))
    //         or a.contains_point(vec3(b.min.x, b.min.y, b.max.z))
    //         or a.contains_point(vec3(b.min.x, b.max.y, b.min.z))
    //         or a.contains_point(vec3(b.min.x, b.max.y, b.max.z))
    //         or a.contains_point(vec3(b.max.x, b.min.y, b.min.z))
    //         or a.contains_point(vec3(b.max.x, b.min.y, b.max.z))
    //         or a.contains_point(vec3(b.max.x, b.max.y, b.min.z))
    //         or a.contains_point(vec3(b.max.x, b.max.y, b.max.z));
    //     // zig fmt: on
    // }

    pub fn transform(self: *const Self, t: *const Mat4) AABB {
        const m0 = t.data[0];
        const m1 = t.data[1];
        const m2 = t.data[2];
        const m3 = t.data[3];

        const xa = vec3(m0[0], m0[1], m0[2]).mulScalar(self.min.x);
        const xb = vec3(m0[0], m0[1], m0[2]).mulScalar(self.max.x);
        const ya = vec3(m1[0], m1[1], m1[2]).mulScalar(self.min.y);
        const yb = vec3(m1[0], m1[1], m1[2]).mulScalar(self.max.y);
        const za = vec3(m2[0], m2[1], m2[2]).mulScalar(self.min.z);
        const zb = vec3(m2[0], m2[1], m2[2]).mulScalar(self.max.z);

        var aabb: AABB = .{
            .min = vec3(m3[0], m3[1], m3[2]),
            .max = vec3(m3[0], m3[1], m3[2]),
        };

        aabb.min.min_add_to(xa, xb);
        aabb.min.min_add_to(ya, yb);
        aabb.min.min_add_to(za, zb);
        aabb.max.max_add_to(xa, xb);
        aabb.max.max_add_to(ya, yb);
        aabb.max.max_add_to(za, zb);

        return aabb;
    }

    pub fn rayIntersects(self: AABB, ray: Ray) ?f32 {
        var t_min: f32 = math.inf(f32) * -1.0;
        var t_max: f32 = math.inf(f32);

        for (axis_xyz) |axis| {
            const origin_axis = switch (axis) {
                .x => ray.origin.x,
                .y => ray.origin.y,
                .z => ray.origin.z,
            };
            const direction_axis = switch (axis) {
                .x => ray.direction.x,
                .y => ray.direction.y,
                .z => ray.direction.z,
            };
            const min_axis = switch (axis) {
                .x => self.min.x,
                .y => self.min.y,
                .z => self.min.z,
            };
            const max_axis = switch (axis) {
                .x => self.max.x,
                .y => self.max.y,
                .z => self.max.z,
            };

            if (direction_axis != 0) {
                const t1 = (min_axis - origin_axis) / direction_axis;
                const t2 = (max_axis - origin_axis) / direction_axis;

                const t_enter = @min(t1, t2);
                const t_exit = @max(t1, t2);

                t_min = @max(t_min, t_enter);
                t_max = @min(t_max, t_exit);
            } else if (origin_axis < min_axis or origin_axis > max_axis) {
                return null; // Ray is parallel and outside the slab
            }
        }

        if (t_min <= t_max and t_max >= 0) {
            if (t_min >= 0) {
                return t_min; // Intersection point is in front of the ray origin
            } else {
                return t_max; // Ray starts inside the AABB, return distance to the farthest intersection
            }
        }

        return null; // No intersection
    }
};
