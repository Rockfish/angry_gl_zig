const std = @import("std");
const zm = @import("zmath");
const Texture = @import("texture.zig").Texture;

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
};
