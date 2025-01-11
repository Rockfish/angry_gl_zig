const std = @import("std");
const core = @import("core");
const gl = @import("zopengl").bindings;
const Texture = core.texture.Texture;
const Shader = core.Shader;
const utils = core.utils;
const math = @import("math");

const Material = @import("material.zig").Material;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;


pub const ModelMesh = struct {
    allocator: Allocator,
    name: []const u8,
    primitives: *ArrayList(MeshPrimitive),
    // weights
    // extensions
    // extras
};

pub const PrimitiveVertex = extern struct {
    position: Vec3,
    normal: Vec3,
    uv: Vec2,
    tangent: Vec3,
    bi_tangent: Vec3,
    bone_ids: [4]u16,
    bone_weights: [4]f32,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .position = undefined,
            .normal = undefined,
            .uv = undefined,
            .tangent = undefined,
            .bi_tangent = undefined,
            .bone_ids = [_]u32{ 0, 0, 0, 0 },
            .bone_weights = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        };
    }
};

const OFFSET_OF_POSITION = 0;
const OFFSET_OF_NORMAL = @offsetOf(PrimitiveVertex, "normal");
const OFFSET_OF_TEXCOORDS = @offsetOf(PrimitiveVertex, "uv");
const OFFSET_OF_TANGENT = @offsetOf(PrimitiveVertex, "tangent");
const OFFSET_OF_BITANGENT = @offsetOf(PrimitiveVertex, "bi_tangent");
const OFFSET_OF_BONE_IDS = @offsetOf(PrimitiveVertex, "bone_ids");
const OFFSET_OF_WEIGHTS = @offsetOf(PrimitiveVertex, "bone_weights");

pub const MeshColor = struct {
    uniform: [:0]const u8,
    color: Vec4,
};

pub const MeshPrimitive = struct {
    allocator: Allocator,
    id: i32,
    name: []const u8,
    vertices: *ArrayList(PrimitiveVertex),
    indices: ?[]u32,
    material: Material,
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    const Self = @This();

    pub fn deinit(self: *MeshPrimitive) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
        self.vertices.deinit();
        self.allocator.destroy(self.vertices);
        // self.indices.deinit();
        // self.allocator.destroy(self.indices);
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }

    pub fn init(
        allocator: Allocator,
        id: i32,
        name: []const u8,
        vertices: *ArrayList(PrimitiveVertex),
        indices: *ArrayList(u32),
    ) !*MeshPrimitive {
        const model_mesh = try allocator.create(MeshPrimitive);
        model_mesh.* = MeshPrimitive{
            .allocator = allocator,
            .id = id,
            .name = try allocator.dupe(u8, name),
            .vertices = vertices,
            .indices = indices,
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

        // std.debug.print("MeshPrimitive: setting up mesh, name: {s}\n", .{name});
        model_mesh.setupMesh();
        // print_model_mesh(model_mesh);
        return model_mesh;
    }

    pub fn render(self: *MeshPrimitive, shader: *const Shader) void {
        // TODO: replace with material
        // const has_texture = self.*.textures.items.len > 0;
        // shader.set_bool("has_texture", has_texture);
        // for (self.*.textures.items, 0..) |texture, i| {
        //     const texture_unit: u32 = @intCast(i);
        //
        //     gl.activeTexture(gl.TEXTURE0 + texture_unit);
        //     gl.bindTexture(gl.TEXTURE_2D, texture.id);
        //
        //     const uniform = texture.texture_type.toString();
        //     shader.set_int(uniform, @as(i32, @intCast(texture_unit)));
        //     // std.debug.print("has_texture: {any} texture id: {d}  name: {s}\n", .{has_texture, i, texture.texture_path});
        // }
        // const has_color = self.*.colors.items.len > 0;
        // shader.set_bool("has_color", has_color);
        // for (self.*.colors.items) |mesh_color| {
        //     shader.set_vec4(mesh_color.uniform, &mesh_color.color);
        //     // std.debug.print("rendering color: {any}\n", .{mesh_color.color});
        // }

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

    pub fn renderNoTextures(self: *MeshPrimitive) void {
        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.indices.items.len,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
    }

    pub fn setupMesh(self: *MeshPrimitive) void {
        // std.debug.print("MeshPrimitive: calling opengl\n", .{});

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
            @intCast(self.vertices.items.len * @sizeOf(PrimitiveVertex)),
            self.vertices.items.ptr,
            gl.STATIC_DRAW,
        );

        // load index data into indices element buffer
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(self.indices.items.len * @sizeOf(u32)),
            self.indices.items.ptr,
            gl.STATIC_DRAW,
        );

        // set the vertex attribute pointers vertex Positions
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer( 0,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_POSITION),
        );

        // vertex normals
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(
            1,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_NORMAL),
        );

        // vertex texture coordinates
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(
            2,
            2,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_TEXCOORDS),
        );

        // vertex tangent
        gl.enableVertexAttribArray(3);
        gl.vertexAttribPointer(
            3,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_TANGENT),
        );

        // vertex bitangent
        gl.enableVertexAttribArray(4);
        gl.vertexAttribPointer(
            4,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_BITANGENT),
        );

        // bone ids
        gl.enableVertexAttribArray(5);
        gl.vertexAttribIPointer(
            5,
            4,
            gl.INT,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_BONE_IDS),
        );

        // weights
        gl.enableVertexAttribArray(6);
        gl.vertexAttribPointer(
            6,
            4,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(PrimitiveVertex),
            @ptrFromInt(OFFSET_OF_WEIGHTS),
        );

        gl.bindVertexArray(0);
    }

    pub fn printMeshVertices(self: *const MeshPrimitive) void {
        std.debug.print("mesh: {s}\n", .{self.name});
        for (self.vertices.items) |v| {
            std.debug.print("vert: {{{d}, {d}, {d}}} bone_ids: [{d}, {d}, {d}, {d}], bone_weights: [{d}, {d}, {d}, {d}]\n", .{
                v.position.x,      v.position.y,      v.position.z, 
                v.bone_ids[0],     v.bone_ids[1],     v.bone_ids[2], v.bone_ids[3],
                v.bone_weights[0], v.bone_weights[1], v.bone_weights[2], v.bone_weights[3],
            });
        }
    }
};

pub fn printMeshPrimitive(mesh: *MeshPrimitive) void {
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

    std.debug.print("size vertex: {d}\n", .{@sizeOf(PrimitiveVertex)});
    std.debug.print("size of vertex parts: {d}\n", .{@sizeOf(Vec3) * 4 + @sizeOf(Vec2) + @sizeOf([4]i32) + @sizeOf([4]f32)});

    std.debug.print("mesh.id: {any}\n", .{mesh.id});
    std.debug.print("mesh.vertex[0]: {any}\n", .{mesh.vertices.items[0]});
    std.debug.print("mesh.indices[0]: {any}\n", .{mesh.indices.items[0]});
    std.debug.print("\n", .{});
}
