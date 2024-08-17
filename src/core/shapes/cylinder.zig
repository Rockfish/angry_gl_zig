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

        // Bottom of cylinder
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
            .normal = vec3(0.0, 1.0, 0.0),
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
                .normal = vec3(0.0, 1.0, 0.0),
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
        //        const initial_indice_count: u32 = @intCast(builder.indices.items.len);

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
                .normal = vec3(cos, 0.0, sin),
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
                .normal = vec3(cos, 0.0, sin),
                .texcoord = Vec2{ .x = u, .y = 0.0 },
            });
        }

        // Each side is a quad which is two triangles
        for (intial_count..(intial_count + sides)) |c| {
            const i: u32 = @intCast(c);

            try builder.indices.append(i + sides + 1);
            try builder.indices.append(i);
            try builder.indices.append(i + 1);

            try builder.indices.append(i + 1);
            try builder.indices.append(i + sides + 2);
            try builder.indices.append(i + sides + 1);
        }

        // std.debug.print("num verts: {d}\n", .{builder.vertices.items.len});
        // std.debug.print("num indices: {d}\n", .{builder.indices.items.len});
        // std.debug.print("indices: {any}\n", .{builder.indices.items});
        // const c = builder.indices.items.len / 3;
        // for (0..c) |n| {
        //     const i = n * 3;
        //     std.debug.print("{d}, {d}, {d}\n", .{ builder.indices.items[i], builder.indices.items[i + 1], builder.indices.items[i + 2] });
        // }

        // const num_faces = (builder.indices.items.len - initial_indice_count) / 3;
        // // std.debug.print("num indices: {d}  num_faces: {d}\n", .{ builder.indices.items.len, num_faces });
        //
        // // calculating the normals manually to learn how to do it.
        // for (0..num_faces) |i| {
        //     const f = initial_indice_count + i * 3;
        //     const v1 = builder.indices.items[f];
        //     const v2 = builder.indices.items[f + 1];
        //     const v3 = builder.indices.items[f + 2];
        //
        //     // std.debug.print("face: {d}  indice index: {d}\n", .{ i, f });
        //     // std.debug.print("i: {d}  v1: {any}\n", .{ f, v1 });
        //     // std.debug.print("i: {d}  v2: {any}\n", .{ f + 1, v2 });
        //     // std.debug.print("i: {d}  v3: {any}\n", .{ f + 2, v3 });
        //
        //     const normal = math.calculate_normal(
        //         builder.vertices.items[v3].position,
        //         builder.vertices.items[v2].position,
        //         builder.vertices.items[v1].position,
        //     );
        //     //std.debug.print("normal: {d}, {d}, {d}\n", .{ normal.x, normal.y, normal.z });
        //     builder.vertices.items[v1].normal.addTo(&normal);
        //     builder.vertices.items[v2].normal.addTo(&normal);
        //     builder.vertices.items[v3].normal.addTo(&normal);
        // }
        //
        // std.debug.print("\n", .{});
        //
        // for (intial_count..builder.vertices.items.len) |i| {
        //     builder.vertices.items[i].normal = builder.vertices.items[i].normal.normalize();
        //     // const normal = builder.vertices.items[i].normal;
        //     //std.debug.print("normal: {d}, {d}, {d}\n", .{ normal.x, normal.y, normal.z });
        // }
    }
};
