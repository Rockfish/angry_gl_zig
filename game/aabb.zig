const std = @import("std");
const math = @import("math");

const Vec3 = math.Vec3;
const vec3 = math.vec3;

pub const Aabb = struct {
    x_min: f32,
    x_max: f32,
    y_min: f32,
    y_max: f32,
    z_min: f32,
    z_max: f32,
    is_initialize: bool,

    const Self = @This();

    pub fn new() Self {
        return .{
            .x_min = std.math.maxInt,
            .x_max = std.math.minInt,
            .y_min = std.math.maxInt,
            .y_max = std.math.minInt,
            .z_min = std.math.maxInt,
            .z_max = std.math.minInt,
            .is_initialize = false,
        };
    }

    pub fn expand_to_include(self: *Self, v: Vec3) void {
        self.x_min = self.x_min.min(v.x);
        self.x_max = self.x_max.max(v.x);
        self.y_min = self.y_min.min(v.y);
        self.y_max = self.y_max.max(v.y);
        self.z_min = self.z_min.min(v.z);
        self.z_max = self.z_max.max(v.z);
        self.is_initialize = true;
    }

    pub fn expand_by(self: *Self, f: f32) void {
        if (self.is_initialize) {
            self.x_min -= f;
            self.x_max += f;
            self.y_min -= f;
            self.y_max += f;
            self.z_min -= f;
            self.z_max += f;
        }
    }

    pub fn contains_point(self: *Self, point: Vec3) bool {
        return point.x >= self.x_min
            and point.x <= self.x_max
            and point.y >= self.y_min
            and point.y <= self.y_max
            and point.z >= self.z_min
            and point.z <= self.z_max;
    }
};

pub fn aabbs_intersect(a: *Aabb, b: *Aabb) bool {
    return a.contains_point(vec3(b.x_min, b.y_min, b.z_min))
        or a.contains_point(vec3(b.x_min, b.y_min, b.z_max))
        or a.contains_point(vec3(b.x_min, b.y_max, b.z_min))
        or a.contains_point(vec3(b.x_min, b.y_max, b.z_max))
        or a.contains_point(vec3(b.x_max, b.y_min, b.z_min))
        or a.contains_point(vec3(b.x_max, b.y_min, b.z_max))
        or a.contains_point(vec3(b.x_max, b.y_max, b.z_min))
        or a.contains_point(vec3(b.x_max, b.y_max, b.z_max));
}
