const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");

const Vec2 = math.Vec2;
const vec2 = math.vec2;
const Vec3 = math.Vec3;
const vec3 = math.vec3;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

const Builder = struct {
    allocator: Allocator,
    vertices: ArrayList(Vertex),
    indices: ArrayList(u32),
};

pub const Vertex = extern struct {
    position: Vec3,
    normal: Vec3,
    texcoord: Vec2,
};

pub const Cylinder = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,
    num_indices: i32,

    const Self = @This();

    pub fn init(allocator: Allocator, radius: f32, height: f32, sides: u32) !Self {
        const builder = try allocator.create(Builder);
        builder.* = Builder{
            .allocator = allocator,
            .vertices = ArrayList(Vertex).init(allocator),
            .indices = ArrayList(u32).init(allocator),
        };
        defer {
            builder.vertices.deinit();
            builder.indices.deinit();
            allocator.destroy(builder);
        }

        // Top of cylinder
        try add_disk_mesh(
            builder,
            vec3(0.0, height, 0.0),
            radius / 2.0,
            sides,
        );

        // // Bottom of cylinder
        try add_disk_mesh(
            builder,
            vec3(0.0, 0.0, 0.0),
            radius / 2.0,
            sides,
        );

        // // Tube - cylinder wall
        try add_tube_mesh(
            builder,
            vec3(0.0, 0.0, 0.0),
            height,
            radius / 2.0,
            sides,
        );

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

    fn add_disk_mesh(builder: *Builder, position: Vec3, radius: f32, sides: u32) !void {
        const intial_count: u32 = @intCast(builder.vertices.items.len);
        // Start with adding the center vertex in the center of the disk.
        try builder.vertices.append(Vertex{
            .position = Vec3{
                .x = position.x,
                .y = position.y,
                .z = position.z,
            },
            .normal = vec3(0.0, 0.0, 0.0),
            .texcoord = Vec2{ .x = 0.5, .y = 0.5 },
        });

        // Add vertices on the edge of the face. The disk is on the x,z plane. Y is up.
        for (0..sides) |i| {
            const angle: f32 = math.tau * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sides));
            const sin = math.sin(angle);
            const cos = math.cos(angle);
            // uv's are in percentages of the texture
            const u = 0.5 + 0.5 * cos;
            const v = 0.5 + 0.5 * sin;
            try builder.vertices.append(Vertex{
                .position = Vec3{
                    .x = position.x + radius * cos,
                    .y = position.y,
                    .z = position.z + radius * sin,
                },
                .normal = vec3(0.0, 0.0, 0.0),
                .texcoord = Vec2{ .x = u, .y = v },
            });
        }

        // Tie three vertices together at a time to form triangle indices.
        const num_vertices: u32 = @as(u32, @intCast(builder.vertices.items.len));

        for ((intial_count + 1)..num_vertices - 1) |i| {
            try builder.indices.append(intial_count);
            try builder.indices.append(@as(u32, @intCast(i)));
            try builder.indices.append(@as(u32, @intCast(i + 1)));
        }

        try builder.indices.append(intial_count);
        try builder.indices.append(intial_count + 1);
        try builder.indices.append(num_vertices - 1);
    }

    pub fn add_tube_mesh(builder: *Builder, position: Vec3, height: f32, radius: f32, sides: u32) !void {
        const intial_count: u32 = @intCast(builder.vertices.items.len);
        // Top ring of vertices. Add 1 to sides to close the loop.
        // Set uv's to wrap texture around the tube
        for (0..sides + 1) |i| {
            const angle: f32 = @as(f32, @floatFromInt(i)) * math.tau / @as(f32, @floatFromInt(sides));
            const sin = math.sin(angle);
            const cos = math.cos(angle);
            // uv's are percentages of the texture size
            const u: f32 = 1.0 - 1.0 / @as(f32, @floatFromInt(sides)) * @as(f32, @floatFromInt(i));
            try builder.vertices.append(Vertex{
                .position = Vec3{
                    .x = position.x + radius * cos,
                    .y = position.y,
                    .z = position.z + radius * sin,
                },
                .normal = vec3(0.0, 0.0, 0.0),
                .texcoord = Vec2{ .x = u, .y = 1.0 },
            });
        }

        // Bottom ring of vertices
        for (0..sides + 1) |i| {
            const angle: f32 = @as(f32, @floatFromInt(i)) * math.tau / @as(f32, @floatFromInt(sides));
            const sin = math.sin(angle);
            const cos = math.cos(angle);
            // uv's are percentages of the texture size
            const u: f32 = 1.0 - 1.0 / @as(f32, @floatFromInt(sides)) * @as(f32, @floatFromInt(i));
            try builder.vertices.append(Vertex{
                .position = Vec3{
                    .x = position.x + radius * cos,
                    .y = position.y + height,
                    .z = position.z + radius * sin,
                },
                .normal = vec3(0.0, 0.0, 0.0),
                .texcoord = Vec2{ .x = u, .y = 0.0 },
            });
        }

        // Each side is a quad which is two triangles
        for (intial_count..(intial_count + sides)) |i| {
            const i_u32: u32 = @intCast(i);
            try builder.indices.append(i_u32);
            try builder.indices.append(i_u32 + 1);
            try builder.indices.append(i_u32 + sides + 1);

            try builder.indices.append(i_u32 + 1);
            try builder.indices.append(i_u32 + sides + 1);
            try builder.indices.append(i_u32 + sides + 2);
        }
    }
};
