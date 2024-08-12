const std = @import("std");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const Shader = @import("shader.zig").Shader;
const utils = @import("utils/main.zig");
const math = @import("math");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

const MAX_BONE_INFLUENCE: usize = 4;

pub const ModelVertex = extern struct {
    position: Vec3,
    normal: Vec3,
    uv: Vec2,
    tangent: Vec3,
    bi_tangent: Vec3,
    bone_ids: [MAX_BONE_INFLUENCE]i32, //  align(1),
    bone_weights: [MAX_BONE_INFLUENCE]f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .position = undefined,
            .normal = undefined,
            .uv = undefined,
            .tangent = undefined,
            .bi_tangent = undefined,
            .bone_ids = [_]i32{ -1, -1, -1, -1 },
            .bone_weights = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        };
    }

    pub fn set_bone_data(self: *Self, bone_id: i32, weight: f32) void {
        //set first available free spot if there is any
        for (0..MAX_BONE_INFLUENCE) |i| {
            if (self.bone_ids[i] < 0) {
                self.bone_ids[i] = bone_id;
                self.bone_weights[i] = weight;
                break;
            }
        }
    }
};

const OFFSET_OF_POSITION = 0;
const OFFSET_OF_NORMAL = @offsetOf(ModelVertex, "normal");
const OFFSET_OF_TEXCOORDS = @offsetOf(ModelVertex, "uv");
const OFFSET_OF_TANGENT = @offsetOf(ModelVertex, "tangent");
const OFFSET_OF_BITANGENT = @offsetOf(ModelVertex, "bi_tangent");
const OFFSET_OF_BONE_IDS = @offsetOf(ModelVertex, "bone_ids");
const OFFSET_OF_WEIGHTS = @offsetOf(ModelVertex, "bone_weights");

pub const MeshColor = struct {
    uniform: [:0]const u8,
    color: Vec4,
};

pub const ModelMesh = struct {
    allocator: Allocator,
    id: i32,
    name: []const u8,
    vertices: *ArrayList(ModelVertex),
    indices: *ArrayList(u32),
    textures: *ArrayList(*Texture),
    colors: *ArrayList(*MeshColor),
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    const Self = @This();

    pub fn deinit(self: *ModelMesh) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        self.vertices.deinit();
        self.allocator.destroy(self.vertices);
        self.indices.deinit();
        self.allocator.destroy(self.indices);
        // for (self.textures.items) |texture| {
        //     texture.deinit();
        // }
        self.textures.deinit();
        for (self.colors.items) |color| {
            self.allocator.destroy(color);
        }
        self.colors.deinit();
        self.allocator.destroy(self.colors);
        self.allocator.destroy(self.textures);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    pub fn init(
        allocator: Allocator,
        id: i32,
        name: []const u8,
        vertices: *ArrayList(ModelVertex),
        indices: *ArrayList(u32),
        textures: *ArrayList(*Texture),
        colors: *ArrayList(*MeshColor),
    ) !*ModelMesh {
        const model_mesh = try allocator.create(ModelMesh);
        model_mesh.* = ModelMesh{
            .allocator = allocator,
            .id = id,
            .name = try allocator.dupe(u8, name),
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            .colors = colors,
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

        // std.debug.print("ModelMesh: setting up mesh, name: {s}\n", .{name});
        model_mesh.setupMesh();
        // print_model_mesh(model_mesh);
        return model_mesh;
    }

    pub fn render(self: *ModelMesh, shader: *const Shader) void {
        for (self.*.textures.items, 0..) |texture, i| {
            const texture_unit: u32 = @intCast(i);

            gl.activeTexture(gl.TEXTURE0 + texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, texture.id);

            const uniform = texture.texture_type.toString();
            shader.set_int(uniform, @as(i32, @intCast(texture_unit)));
        }

        const has_color = self.*.colors.items.len > 0;
        shader.set_bool("has_color", has_color);

        for (self.*.colors.items) |mesh_color| {
            shader.set_vec4(mesh_color.uniform, &mesh_color.color);
        }

        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            @intCast(self.indices.items.len),
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);

        shader.set_bool("has_color", false);
    }

    pub fn renderNoTextures(self: *ModelMesh) void {
        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.indices.items.len,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
    }

    pub fn setupMesh(self: *ModelMesh) void {
        // std.debug.print("ModelMesh: calling opengl\n", .{});

        var vao: gl.Uint = undefined;
        var vbo: gl.Uint = undefined;
        var ebo: gl.Uint = undefined;

        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);
        gl.genBuffers(1, &ebo);
        self.vao = vao;
        self.vbo = vbo;
        self.ebo = ebo;

        // load vertex data into vertex buffers
        gl.bindVertexArray(self.vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            @intCast(self.vertices.items.len * @sizeOf(ModelVertex)),
            self.vertices.items.ptr,
            gl.STATIC_DRAW,
        );

        // load index data into element buffer
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(self.indices.items.len * @sizeOf(u32)),
            self.indices.items.ptr,
            gl.STATIC_DRAW,
        );

        // set the vertex attribute pointers vertex Positions
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_POSITION),
        );

        // vertex normals
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(
            1,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_NORMAL),
        );

        // vertex texture coordinates
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(
            2,
            2,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_TEXCOORDS),
        );

        // vertex tangent
        gl.enableVertexAttribArray(3);
        gl.vertexAttribPointer(
            3,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_TANGENT),
        );

        // vertex bitangent
        gl.enableVertexAttribArray(4);
        gl.vertexAttribPointer(
            4,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_BITANGENT),
        );

        // bone ids
        gl.enableVertexAttribArray(5);
        gl.vertexAttribIPointer(
            5,
            4,
            gl.INT,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_BONE_IDS),
        );

        // weights
        gl.enableVertexAttribArray(6);
        gl.vertexAttribPointer(
            6,
            4,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(ModelVertex),
            @ptrFromInt(OFFSET_OF_WEIGHTS),
        );

        gl.bindVertexArray(0);
    }
};

pub fn print_model_mesh(mesh: *ModelMesh) void {
    // _ = mesh;

    std.debug.print("OFFSET_OF_POSITION: {any}\n", .{OFFSET_OF_POSITION});
    std.debug.print("OFFSET_OF_NORMAL: {any}\n", .{OFFSET_OF_NORMAL});
    std.debug.print("OFFSET_OF_TEXCOORDS: {any}\n", .{OFFSET_OF_TEXCOORDS});
    std.debug.print("OFFSET_OF_TANGENT: {any}\n", .{OFFSET_OF_TANGENT});
    std.debug.print("OFFSET_OF_BITANGENT: {any}\n", .{OFFSET_OF_BITANGENT});
    std.debug.print("OFFSET_OF_BONE_IDS: {any}\n", .{OFFSET_OF_BONE_IDS});
    std.debug.print("OFFSET_OF_WEIGHTS: {any}\n", .{OFFSET_OF_WEIGHTS});

    std.debug.print("size of CVec2: {d}\n", .{@sizeOf(Vec2)});
    std.debug.print("size of CVec3: {d}\n", .{@sizeOf(Vec3)});
    std.debug.print("size of [4]i32: {d}\n", .{@sizeOf([4]i32)});
    std.debug.print("size of [4]f32: {d}\n", .{@sizeOf([4]f32)});

    std.debug.print("size vertex: {d}\n", .{@sizeOf(ModelVertex)});
    std.debug.print("size of vertex parts: {d}\n", .{@sizeOf(Vec3) * 4 + @sizeOf(Vec2) + @sizeOf([4]i32) + @sizeOf([4]f32)});

    std.debug.print("mesh.id: {any}\n", .{mesh.id});
    std.debug.print("mesh.vertex[0]: {any}\n", .{mesh.vertices.items[0]});
    std.debug.print("mesh.indices[0]: {any}\n", .{mesh.indices.items[0]});
    std.debug.print("\n", .{});
}
