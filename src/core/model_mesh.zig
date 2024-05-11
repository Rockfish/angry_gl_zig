const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const Shader = @import("shader.zig").Shader;

const MAX_BONE_INFLUENCE: usize = 4;

pub const ModelVertex = struct {
    position: zm.Vec3,
    normal: zm.Vec3,
    uv: zm.Vec2,
    tangent: zm.Vec3,
    bi_tangent: zm.Vec3,
    bone_ids: [MAX_BONE_INFLUENCE]i32,
    bone_weights: [MAX_BONE_INFLUENCE]f32,
};

pub const ModelMesh = struct {
    id: i32,
    name: []const u8,
    vertices: std.ArrayList(ModelVertex),
    indices: std.ArrayList(u32),
    textures: std.ArrayList(Texture),
    vao: u32,
    vbo: u32,
    ebo: u32,

    pub fn new(allocator: std.mem.Allocator, id: i32, name: []const u8, vertices: std.ArrayList(ModelVertex), indices: std.ArrayList(u32), textures: std.ArrayList(Texture)) !*ModelMesh {
        const model_mesh = try allocator.create(ModelMesh);

        model_mesh.* = .{
            .id = id,
            .name = name,
            .vertices = vertices,
            .indices = indices,
            .textures = textures,
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

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

        gl.BindVertexArray(self.vao);
        gl.DrawElements(
            gl.TRIANGLES,
            self.indices.len(),
            gl.UNSIGNED_INT,
            null,
        );
        gl.BindVertexArray(0);
    }
};
