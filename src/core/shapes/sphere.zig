const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");
const shape = @import("shape.zig");

const Allocator = std.mem.Allocator;
const ModelVertex = @import("../model_mesh.zig").ModelVertex;

const AABB = @import("../aabb.zig").AABB;

const Vec2 = math.Vec2;
const vec2 = math.vec2;
const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Vec4 = math.Vec4;
const vec4 = math.vec4;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

pub const Sphere = struct {

    const Self = @This();

    pub fn init(allocator: Allocator, radius: f32, poly_countX: u32, poly_countY: u32) !shape.Shape {
        var builder = try build(allocator, radius, poly_countX, poly_countY);
        defer builder.deinit();
        return shape.initGLBuffers(&builder);
    }

    fn build(allocator: Allocator, radius: f32, poly_countX: u32, poly_countY: u32) !shape.ShapeBuilder {
        var builder = shape.ShapeBuilder.init(allocator, .Cylinder);

        // we are creating the sphere mesh here.
        var polyCountX = poly_countX;
        var polyCountY = poly_countY;

        if (polyCountX < 2)
            polyCountX = 2;
        if (polyCountY < 2)
            polyCountY = 2;

        while (polyCountX * polyCountY > 32767) // prevent u16 overflow
        {
            polyCountX /= 2;
            polyCountY /= 2;
        }

        const polyCountXPitch: u32 = polyCountX + 1; // get to same vertex on next level

        const indices_size = (polyCountX * polyCountY) * 6;
        try builder.indices.resize(indices_size);

        //const clr = math.vec4(1.0, 1.0, 1.0, 1.0);

        var level: u32 = 0;

        for (0..polyCountY - 1) |_| {
            //for (u32 p1 = 0; p1 < polyCountY-1; ++p1)
            //main quads, top to bottom
            for (0..polyCountX - 1) |p2| {
                //for (u32 p2 = 0; p2 < polyCountX - 1; ++p2)
                const curr: u32 = level + @as(u32, @intCast(p2));
                try builder.indices.append(curr + polyCountXPitch);
                try builder.indices.append(curr);
                try builder.indices.append(curr + 1);
                try builder.indices.append(curr + polyCountXPitch);
                try builder.indices.append(curr + 1);
                try builder.indices.append(curr + 1 + polyCountXPitch);
            }

            // the connectors from front to end
            try builder.indices.append(level + polyCountX - 1 + polyCountXPitch);
            try builder.indices.append(level + polyCountX - 1);
            try builder.indices.append(level + polyCountX);

            try builder.indices.append(level + polyCountX - 1 + polyCountXPitch);
            try builder.indices.append(level + polyCountX);
            try builder.indices.append(level + polyCountX + polyCountXPitch);
            level += polyCountXPitch;
        }

        const polyCountSq: u32 = polyCountXPitch * polyCountY; // top point
        const polyCountSq1: u32 = polyCountSq + 1; // bottom point
        const polyCountSqM1: u32 = (polyCountY - 1) * polyCountXPitch; // last row's first vertex

        for (0..polyCountX - 1) |p_2| {
            //for (u32 p2 = 0; p2 < polyCountX - 1; ++p2) {
            // create triangles which are at the top of the sphere

            const p2: u32 = @intCast(p_2);
            try builder.indices.append(polyCountSq);
            try builder.indices.append(p2 + 1);
            try builder.indices.append(p2);

            // create triangles which are at the bottom of the sphere

            try builder.indices.append(polyCountSqM1 + p2);
            try builder.indices.append(polyCountSqM1 + p2 + 1);
            try builder.indices.append(polyCountSq1);
        }

        // create final triangle which is at the top of the sphere

        try builder.indices.append(polyCountSq);
        try builder.indices.append(polyCountX);
        try builder.indices.append(polyCountX - 1);

        // create final triangle which is at the bottom of the sphere

        try builder.indices.append(polyCountSqM1 + polyCountX - 1);
        try builder.indices.append(polyCountSqM1);
        try builder.indices.append(polyCountSq1);

        // calculate the angle which separates all points in a circle
        const AngleX: f32 = 2.0 * math.pi / @as(f32, @floatFromInt(polyCountX));
        const AngleY: f32 = math.pi / @as(f32, @floatFromInt(polyCountY));

        var i: u32 = 0;
        var axz: f32 = 0.0;

        // we don't start at 0.

        var ay: f32 = 0; //AngleY / 2;

        const size = (polyCountXPitch * polyCountY) + 2;
        try builder.vertices.resize(size);

        for (0..polyCountY) |y| {
            //for (u32 y = 0; y < polyCountY; ++y) {
            ay += AngleY;
            const sinay: f32 = math.sin(ay);
            axz = 0;

            // calculate the necessary vertices without the doubled one
            for (0..polyCountX) |_| {
                //for (u32 xz = 0;xz < polyCountX; ++xz) {
                // calculate points position

                const pos = vec3(
                    @floatCast(radius * math.cos(axz) * sinay),
                    @floatCast(radius * math.cos(ay)),
                    @floatCast(radius * math.sin(axz) * sinay),
                );

                // for spheres the normal is the position
                var normal = vec3(pos.x, pos.y, pos.z);
                normal = normal.normalize();

                // calculate texture coordinates via sphere mapping
                // tu is the same on each level, so only calculate once
                var tu: f32 = 0.5;
                if (y == 0) {
                    if (normal.y != -1.0 and normal.y != 1.0) {
                        tu = @floatCast(math.acos(math.clamp(normal.x / sinay, -1.0, 1.0)) * 0.5 * math.reciprocal_pi);
                    }
                    if (normal.z < 0.0) {
                        tu = 1 - tu;
                    }
                } else {
                    tu = builder.vertices.items[i - polyCountXPitch].texcoords.x;
                }

                builder.vertices.items[i] = shape.Vertex.init(pos.x, pos.y, pos.z, normal.x, normal.y, normal.z, tu, @floatCast(ay * math.reciprocal_pi));
                i += 1;
                axz += AngleX;
            }
            // This is the doubled vertex on the initial position
            builder.vertices.items[i] = builder.vertices.items[i - polyCountX].clone();
            builder.vertices.items[i].texcoords.x = 1.0;
            i += 1;
        }

        // the vertex at the top of the sphere
        builder.vertices.items[i] = shape.Vertex.init(0.0, radius, 0.0, 0.0, 1.0, 0.0, 0.5, 0.0);

        // the vertex at the bottom of the sphere
        i += 1;
        builder.vertices.items[i] = shape.Vertex.init(0.0, -radius, 0.0, 0.0, -1.0, 0.0, 0.5, 1.0);

        // recalculate bounding box

        // BoundingBox.reset(vertices[i].Pos);
        // BoundingBox.addInternalPoint(vertices[i-1].Pos);
        // BoundingBox.addInternalPoint(radius,0.0,0.0);
        // BoundingBox.addInternalPoint(-radius,0.0,0.0);
        // BoundingBox.addInternalPoint(0.0,0.0,radius);
        // BoundingBox.addInternalPoint(0.0,0.0,-radius);
        //
        // SMesh* mesh = new SMesh();
        // mesh->addMeshBuffer(buffer);
        //
        // mesh->setHardwareMappingHint(EHM_STATIC);
        // mesh->recalculateBoundingBox();

        for (builder.vertices.items) |v| {
            builder.aabb.expand_to_include(v.position);
        }

        return builder;
    }
};
