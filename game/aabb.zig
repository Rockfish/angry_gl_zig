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
            .x_min = math.maxFloat,
            .x_max = math.minFloat,
            .y_min = math.maxFloat,
            .y_max = math.minFloat,
            .z_min = math.maxFloat,
            .z_max = math.minFloat,
            .is_initialize = false,
        };
    }

    pub fn expand_to_include(self: *Self, v: Vec3) void {
        self.x_min = @min(self.x_min, v.data[0]);
        self.x_max = @max(self.x_max, v.data[0]);
        self.y_min = @min(self.y_min, v.data[1]);
        self.y_max = @max(self.y_max, v.data[1]);
        self.z_min = @min(self.z_min, v.data[2]);
        self.z_max = @max(self.z_max, v.data[2]);
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
