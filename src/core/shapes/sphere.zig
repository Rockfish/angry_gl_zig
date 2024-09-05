const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");

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

pub const Vertex = extern struct {
    position: Vec3,
    normal: Vec3,
    texcoords: Vec2,
    //color: Vec4,
    //tangent: Vec4

    pub fn init(x: f32, y: f32, z: f32, nx: f32, ny: f32, nz: f32, c: Vec4, tu: f32, tv: f32) Vertex {
        _ = c;
        return .{
            .position = vec3(x, y, z),
            .normal = vec3(nx, ny, nz),
            .texcoords = vec2(tu, tv),
            // .color = c,
        };
    }

    pub fn clone(self: *Vertex) Vertex {
        return .{
            .position = self.position,
            .normal = self.normal,
            .texcoords = self.texcoords,
            //.color = self.color,
        };
    }
};

const Builder = struct {
    // allocator: Allocator,
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn deinit(self: *Builder) void {
        self.indices.deinit();
        self.vertices.deinit();
    }
};

pub const Sphere = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,
    num_indices: i32,
    // aabb: AABB,

    const Self = @This();

    pub fn init(allocator: Allocator, radius: f32, poly_countX: u32, poly_countY: u32) !Sphere {
        var builder = try build(allocator, radius, poly_countX, poly_countY);
        defer builder.deinit();
        return init_gl(&builder);
    }

    fn build(allocator: Allocator, radius: f32, poly_countX: u32, poly_countY: u32) !Builder {

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
        var indices = try std.ArrayList(u32).initCapacity(allocator, indices_size);

        const clr = math.vec4(1.0, 1.0, 1.0, 1.0);

        var level: u32 = 0;

        for (0..polyCountY - 1) |_| {
            //for (u32 p1 = 0; p1 < polyCountY-1; ++p1)
            //main quads, top to bottom
            for (0..polyCountX - 1) |p2| {
                //for (u32 p2 = 0; p2 < polyCountX - 1; ++p2)
                const curr: u32 = level + @as(u32, @intCast(p2));
                try indices.append(curr + polyCountXPitch);
                try indices.append(curr);
                try indices.append(curr + 1);
                try indices.append(curr + polyCountXPitch);
                try indices.append(curr + 1);
                try indices.append(curr + 1 + polyCountXPitch);
            }

            // the connectors from front to end
            try indices.append(level + polyCountX - 1 + polyCountXPitch);
            try indices.append(level + polyCountX - 1);
            try indices.append(level + polyCountX);

            try indices.append(level + polyCountX - 1 + polyCountXPitch);
            try indices.append(level + polyCountX);
            try indices.append(level + polyCountX + polyCountXPitch);
            level += polyCountXPitch;
        }

        const polyCountSq: u32 = polyCountXPitch * polyCountY; // top point
        const polyCountSq1: u32 = polyCountSq + 1; // bottom point
        const polyCountSqM1: u32 = (polyCountY - 1) * polyCountXPitch; // last row's first vertex

        for (0..polyCountX - 1) |p_2| {
            //for (u32 p2 = 0; p2 < polyCountX - 1; ++p2) {
            // create triangles which are at the top of the sphere

            const p2: u32 = @intCast(p_2);
            try indices.append(polyCountSq);
            try indices.append(p2 + 1);
            try indices.append(p2);

            // create triangles which are at the bottom of the sphere

            try indices.append(polyCountSqM1 + p2);
            try indices.append(polyCountSqM1 + p2 + 1);
            try indices.append(polyCountSq1);
        }

        // create final triangle which is at the top of the sphere

        try indices.append(polyCountSq);
        try indices.append(polyCountX);
        try indices.append(polyCountX - 1);

        // create final triangle which is at the bottom of the sphere

        try indices.append(polyCountSqM1 + polyCountX - 1);
        try indices.append(polyCountSqM1);
        try indices.append(polyCountSq1);

        // calculate the angle which separates all points in a circle
        const AngleX: f32 = 2.0 * math.pi / @as(f32, @floatFromInt(polyCountX));
        const AngleY: f32 = math.pi / @as(f32, @floatFromInt(polyCountY));

        var i: u32 = 0;
        var axz: f32 = 0.0;

        // we don't start at 0.

        var ay: f32 = 0; //AngleY / 2;

        const size = (polyCountXPitch * polyCountY) + 2;
        var vertices = try std.ArrayList(Vertex).initCapacity(allocator, size);
        try vertices.resize(size);

        std.debug.print("vertices len: {d} - should be > 0\n", .{vertices.items.len});

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
                    tu = vertices.items[i - polyCountXPitch].texcoords.x;
                }

                vertices.items[i] = Vertex.init(pos.x, pos.y, pos.z, normal.x, normal.y, normal.z, clr, tu, @floatCast(ay * math.reciprocal_pi));
                i += 1;
                axz += AngleX;
            }
            // This is the doubled vertex on the initial position
            vertices.items[i] = vertices.items[i - polyCountX].clone();
            vertices.items[i].texcoords.x = 1.0;
            i += 1;
        }

        // the vertex at the top of the sphere
        vertices.items[i] = Vertex.init(0.0, radius, 0.0, 0.0, 1.0, 0.0, clr, 0.5, 0.0);

        // the vertex at the bottom of the sphere
        i += 1;
        vertices.items[i] = Vertex.init(0.0, -radius, 0.0, 0.0, -1.0, 0.0, clr, 0.5, 1.0);

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
        return Builder{
            .indices = indices,
            .vertices = vertices,
        };
    }

    pub fn init_gl(builder: *const Builder) Sphere {
        var vao: u32 = undefined;
        var vbo: u32 = undefined;
        var ebo: u32 = undefined;

        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);
        gl.genBuffers(1, &ebo);

        gl.bindVertexArray(vao);

        // vertices
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            @intCast(builder.vertices.items.len * @sizeOf(Vertex)),
            builder.vertices.items.ptr,
            gl.STATIC_DRAW,
        );

        // indices
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(builder.indices.items.len * @sizeOf(u32)),
            builder.indices.items.ptr,
            gl.STATIC_DRAW,
        );

        // position
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(0),
        );
        gl.enableVertexAttribArray(0);

        // normal
        gl.vertexAttribPointer(
            1,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(SIZE_OF_FLOAT * 3),
        );
        gl.enableVertexAttribArray(1);

        // texcoords
        gl.vertexAttribPointer(
            2,
            2,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(SIZE_OF_FLOAT * 6),
        );
        gl.enableVertexAttribArray(2);

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .num_indices = @intCast(builder.indices.items.len),
        };
    }

    pub fn render(self: *const Self) void {
        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.num_indices,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
    }
};
