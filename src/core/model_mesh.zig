const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const Shader = @import("shader.zig").Shader;

const MAX_BONE_INFLUENCE: usize = 4;

// const OFFSET_OF_POSITION = @as(?*anyopaque, @ptrFromInt(0));
// const OFFSET_OF_NORMAL = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "normal")));
// const OFFSET_OF_TEXCOORDS = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "uv")));
// const OFFSET_OF_TANGENT = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "tangent")));
// const OFFSET_OF_BITANGENT = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "bi_tangent")));
// const OFFSET_OF_BONE_IDS = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "bone_ids")));
// const OFFSET_OF_WEIGHTS = @as(?*anyopaque, @ptrFromInt(@offsetOf(ModelVertex, "bone_weights")));

pub const ModelVertex = extern struct {
    position: zm.Vec3,
    normal: zm.Vec3,
    uv: zm.Vec2,
    tangent: zm.Vec3,
    bi_tangent: zm.Vec3,
    bone_ids: [MAX_BONE_INFLUENCE]i32, //  align(1),
    bone_weights: [MAX_BONE_INFLUENCE]f32,
};

const OFFSET_OF_POSITION = 0;
const OFFSET_OF_NORMAL = @offsetOf(ModelVertex, "normal");
const OFFSET_OF_TEXCOORDS = @offsetOf(ModelVertex, "uv");
const OFFSET_OF_TANGENT = @offsetOf(ModelVertex, "tangent");
const OFFSET_OF_BITANGENT = @offsetOf(ModelVertex, "bi_tangent");
const OFFSET_OF_BONE_IDS = @offsetOf(ModelVertex, "bone_ids");
const OFFSET_OF_WEIGHTS = @offsetOf(ModelVertex, "bone_weights");

pub const ModelMesh = struct {
    id: i32,
    name: []const u8,
    vertices: std.ArrayList(ModelVertex),
    indices: std.ArrayList(u32),
    textures: std.ArrayList(Texture),
    vao: c_uint,
    vbo: c_uint,
    ebo: c_uint,

    pub fn init(id: i32, name: []const u8, vertices: std.ArrayList(ModelVertex), indices: std.ArrayList(u32), textures: std.ArrayList(Texture)) ModelMesh {
        var model_mesh = ModelMesh{
            .id = id,
            .name = name,
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

        setupMesh(&model_mesh);
        return model_mesh;
    }

    pub fn render(self: *ModelMesh, shader: *Shader) void {
        for (self.*.textures, 0..) |texture, i| {
            const texture_unit = @as(i32, @intCast(i));
            gl.ActiveTexture(gl.TEXTURE0 + texture_unit);
            gl.BindTexture(gl.TEXTURE_2D, texture.id);

            const uniform_name = texture.texture_type.to_string();
            shader.set_int(&uniform_name, texture_unit);
        }

        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.indices.items.len,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
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

    fn setupMesh(self: *ModelMesh) void {
        var vao: gl.Uint = undefined;
        // var vbo: gl.Uint = undefined;
        // var ebo: gl.Uint = undefined;
        _ = self;

        gl.genVertexArrays(1, &vao);
        // gl.genBuffers(1, &vbo);
        // gl.genBuffers(1, &ebo);
        // self.vao = vao;
        // self.vbo = vbo;
        // self.ebo = ebo;
        

        // // load vertex data into vertex buffers
        // gl.bindVertexArray(self.vao);
        // gl.bindBuffer(gl.ARRAY_BUFFER, self.vbo);
        // gl.bufferData(
        //     gl.ARRAY_BUFFER,
        //     @intCast(self.vertices.items.len * @sizeOf(ModelVertex)),
        //     self.vertices.items.ptr,
        //     gl.STATIC_DRAW,
        // );

        // // load index data into element buffer
        // gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ebo);
        // gl.bufferData(
        //     gl.ELEMENT_ARRAY_BUFFER,
        //     @intCast(self.indices.items.len * @sizeOf(u32)),
        //     self.indices.items.ptr,
        //     gl.STATIC_DRAW,
        // );

        // // set the vertex attribute pointers vertex Positions
        // gl.enableVertexAttribArray(0);
        // gl.vertexAttribPointer(
        //     0,
        //     3,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_POSITION)),
        // );

        // // vertex normals
        // gl.enableVertexAttribArray(1);
        // gl.vertexAttribPointer(
        //     1,
        //     3,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_NORMAL)),
        // );

        // // vertex texture coordinates
        // gl.enableVertexAttribArray(2);
        // gl.vertexAttribPointer(
        //     2,
        //     2,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_TEXCOORDS)),
        // );

        // // vertex tangent
        // gl.enableVertexAttribArray(3);
        // gl.vertexAttribPointer(
        //     3,
        //     3,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_TANGENT)),
        // );

        // // vertex bitangent
        // gl.enableVertexAttribArray(4);
        // gl.vertexAttribPointer(
        //     4,
        //     3,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_BITANGENT)),
        // );

        // // bone ids
        // gl.enableVertexAttribArray(5);
        // gl.vertexAttribIPointer(
        //     5,
        //     4,
        //     gl.INT,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_BONE_IDS)),
        // );

        // // weights
        // gl.enableVertexAttribArray(6);
        // gl.vertexAttribPointer(
        //     6,
        //     4,
        //     gl.FLOAT,
        //     gl.FALSE,
        //     @sizeOf(ModelVertex),
        //     @as(?*anyopaque, @ptrFromInt(OFFSET_OF_WEIGHTS)),
        // );

        // gl.bindVertexArray(0);
    }

    pub fn deinit(self: ModelMesh) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ebo);
    }
};

pub fn print_model_mesh(mesh: ModelVertex) void {
    _ = mesh;
    // std.debug.print("mesh: {:#?}", mesh);

    std.debug.print("size vertex: {d}\n", .{@sizeOf(ModelVertex)});
    std.debug.print("OFFSET_OF_POSITION: {any}\n", .{OFFSET_OF_POSITION});
    std.debug.print("OFFSET_OF_NORMAL: {any}\n", .{OFFSET_OF_NORMAL});
    std.debug.print("OFFSET_OF_TEXCOORDS: {any}\n", .{OFFSET_OF_TEXCOORDS});
    std.debug.print("OFFSET_OF_TANGENT: {any}\n", .{OFFSET_OF_TANGENT});
    std.debug.print("OFFSET_OF_BITANGENT: {any}\n", .{OFFSET_OF_BITANGENT});
    std.debug.print("OFFSET_OF_BONE_IDS: {any}\n", .{OFFSET_OF_BONE_IDS});
    std.debug.print("OFFSET_OF_WEIGHTS: {any}\n", .{OFFSET_OF_WEIGHTS});

    std.debug.print("size of Vec2: {d}\n", .{@sizeOf(zm.Vec2)});
    std.debug.print("size of Vec3: {d}\n", .{@sizeOf(zm.Vec3)});
    std.debug.print("size of [4]i32: {d}\n", .{@sizeOf([4]i32)});
    std.debug.print("size of [4]f32: {d}\n", .{@sizeOf([4]f32)});

    std.debug.print("size of vertex parts: {d}\n", .{@sizeOf(zm.Vec3) * 4 + @sizeOf(zm.Vec2) + @sizeOf([4]i32) + @sizeOf([4]f32)});
}
