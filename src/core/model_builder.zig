const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Animator = @import("animator.zig").Animator;

pub const ModelBuilder = struct {
    name: []const u8,
    meshes: std.ArrayList(ModelMesh),
    // bone_data_map: RefCell<HashMap<BoneName, BoneData>>,
    bone_count: i32,
    filepath: []const u8,
    directory: []const u8,
    gamma_correction: bool,
    flip_v: bool,
    flip_h: bool,
    load_textures: bool,
    textures_cache: std.ArrayList(Texture),
    // added_textures: std.ArrayList(AddedTextures),
    mesh_count: i32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) Self {

        const builder = ModelBuilder {
            .name = name,
            .meshes = std.ArrayList(ModelMesh).init(allocator),
            .mesh_count = 0,
            .bone_count = 0,
            .filepath = path,
            .directory = path, // todo: fix, get parent
            .gamma_correction = false,
            .flip_v = false,
            .flip_h = false,
            .load_textures = true,
            // .added_textures
            .textures_cache = std.ArrayList(Texture).init(allocator),
            .allocator = allocator,
        };

        return builder;
    }

};
