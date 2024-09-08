const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");

const shape = @import("shape.zig");
const AABB = @import("../aabb.zig").AABB;

const Vec3 = math.Vec3;
const vec3 = math.vec3;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

pub const CubeConfig = struct {
    width: f32 = 1.0,
    height: f32 = 1.0,
    depth: f32 = 1.0,
    num_tiles_x: f32 = 1.0,
    num_tiles_y: f32 = 1.0,
    num_tiles_z: f32 = 1.0,
};

pub const Cubeboid = struct {

    pub fn init(allocator: std.mem.Allocator, config: CubeConfig) !shape.Shape {
        var builder = shape.ShapeBuilder.init(allocator, .Cube);
        defer builder.deinit();

        const max = vec3(config.width / 2.0, config.height / 2.0, config.depth / 2.0);
        const min = max.mulScalar(-1.0);

        const wraps_x: f32 = config.num_tiles_x;
        const wraps_y: f32 = config.num_tiles_y;
        const wraps_z: f32 = config.num_tiles_z;

        // position, normal, texcoords
        const vertices = [_][8]f32{
            // Front
            .{min.x, min.y, max.z, 0.0,  0.0,  1.0,  0.0,     0.0,},
            .{max.x, min.y, max.z, 0.0,  0.0,  1.0,  wraps_x, 0.0,},
            .{max.x, max.y, max.z, 0.0,  0.0,  1.0,  wraps_x, wraps_y,},
            .{min.x, max.y, max.z, 0.0,  0.0,  1.0,  0.0,     wraps_y,},
            // Back,
            .{min.x, max.y, min.z, 0.0,  0.0,  -1.0, wraps_x, 0.0,},
            .{max.x, max.y, min.z, 0.0,  0.0,  -1.0, 0.0,     0.0,},
            .{max.x, min.y, min.z, 0.0,  0.0,  -1.0, 0.0,     wraps_y,},
            .{min.x, min.y, min.z, 0.0,  0.0,  -1.0, wraps_x, wraps_y,},
            // Right,
            .{max.x, min.y, min.z, 1.0,  0.0,  0.0,  0.0,     0.0,},
            .{max.x, max.y, min.z, 1.0,  0.0,  0.0,  wraps_y, 0.0,},
            .{max.x, max.y, max.z, 1.0,  0.0,  0.0,  wraps_y, wraps_z,},
            .{max.x, min.y, max.z, 1.0,  0.0,  0.0,  0.0,     wraps_z,},
            // Left,
            .{min.x, min.y, max.z, -1.0, 0.0,  0.0,  wraps_y, 0.0,},
            .{min.x, max.y, max.z, -1.0, 0.0,  0.0,  0.0,     0.0,},
            .{min.x, max.y, min.z, -1.0, 0.0,  0.0,  0.0,     wraps_z,},
            .{min.x, min.y, min.z, -1.0, 0.0,  0.0,  wraps_y, wraps_z,},
            // Top,
            .{max.x, max.y, min.z, 0.0,  1.0,  0.0,  wraps_x, 0.0,},
            .{min.x, max.y, min.z, 0.0,  1.0,  0.0,  0.0,     0.0,},
            .{min.x, max.y, max.z, 0.0,  1.0,  0.0,  0.0,     wraps_z,},
            .{max.x, max.y, max.z, 0.0,  1.0,  0.0,  wraps_x, wraps_z,},
            // Bottom,
            .{max.x, min.y, max.z, 0.0,  -1.0, 0.0,  0.0,     0.0,},
            .{min.x, min.y, max.z, 0.0,  -1.0, 0.0,  wraps_x, 0.0,},
            .{min.x, min.y, min.z, 0.0,  -1.0, 0.0,  wraps_x, wraps_z,},
            .{max.x, min.y, min.z, 0.0,  -1.0, 0.0,  0.0,     wraps_z,},
        };

        for (vertices) |v| {
            const vert = shape.Vertex.init(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7]);
            try builder.vertices.append(vert);
            builder.aabb.expand_to_include(vec3(v[0], v[1], v[2]));
        }

        const indices = [_]u32{
            0, 1, 2, 2, 3, 0, // front
            4, 5, 6, 6, 7, 4, // back
            8, 9, 10, 10, 11, 8, // right
            12, 13, 14, 14, 15, 12, // left
            16, 17, 18, 18, 19, 16, // top
            20, 21, 22, 22, 23, 20, // bottom
        };

        try builder.indices.appendSlice(indices[0..]);

        return shape.initGLBuffers(&builder);
    }
};
