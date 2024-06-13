const std = @import("std");

const math = @import("math");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const Allocator = std.mem.Allocator;

pub const Enemy = struct {
    position: Vec3,
    dir: Vec3,
    is_alive: bool,

    const Self = @This();

    pub fn new(position: Vec3, dir: Vec3) Self {
        return . {
            .position = position,
            .dir = dir,
            .is_alive = true
        };
    }
};

pub const EnemySystem = struct {

    const Self = @This();

    pub fn new(allocator: Allocator) Self {
        _ = allocator;
        return .{};
    }

};