const std = @import("std");
const Cube = @import("cube.zig").Cube;
const cubeboid = @import("cubeboid.zig");
const Cylinder = @import("cylinder.zig").Cylinder;
const Sphere = @import("sphere.zig").Sphere;


pub const Shape = @import("shape.zig").Shape;

pub const CubeConfig = cubeboid.CubeConfig;

pub fn createCube(allocator: std.mem.Allocator, config: cubeboid.CubeConfig) !Shape {
     return try cubeboid.Cubeboid.init(allocator, config);
}

pub fn createCylinder(allocator: std.mem.Allocator, radius: f32, height: f32, sides: u32) !Shape {
    return try Cylinder.init(allocator, radius, height, sides);
}

pub fn createSphere(allocator: std.mem.Allocator, radius: f32, poly_countX: u32, poly_countY: u32) !Shape {
    return try Sphere.init(allocator, radius, poly_countX, poly_countY);
}
