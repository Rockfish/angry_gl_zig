const std = @import("std");
const gl = @import("zopengl").bindings;
const panic = @import("std").debug.panic;
const core = @import("core");
const math = @import("math");

// const Model = @import("model.zig").Model;
// const ModelNode = @import("model_animation.zig").ModelNode;
// const ModelAnimation = @import("model_animation.zig").ModelAnimation;
// const NodeKeyframes = @import("model_node_keyframes.zig").NodeKeyframes;
// const ModelBone = @import("model_animation.zig").ModelBone;
// const Animator = @import("animator.zig").Animator;
// const Transform = @import("transform.zig").Transform;
// const String = @import("string.zig").String;
// const utils = @import("utils/main.zig");

const Gltf = @import("zgltf/src/main.zig");
const Model = @import("model.zig").Model;
const ModelMesh = @import("mesh.zig").ModelMesh;
const Animator = @import("animator.zig").Animator;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Path = std.fs.path;

const texture_ = core.texture;
const Texture = texture_.Texture;
const TextureType = texture_.TextureType;
const TextureConfig = texture_.TextureConfig;
const TextureFilter = texture_.TextureFilter;
const TextureWrap = texture_.TextureWrap;
//const MeshColor = core.MeshColor;
const Transform = core.Transform;
const String = core.String;
const utils = core.utils;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

pub const GltfBuilder = struct {
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    texture_cache: *ArrayList(*Texture),
    added_textures: ArrayList(AddedTexture),
    //model_bone_map: *StringHashMap(*ModelBone),
    bone_count: u32,
    filepath: [:0]const u8,
    directory: []const u8,
    gamma_correction: bool,
    flip_v: bool,
    flip_h: bool,
    load_textures: bool,
    mesh_count: i32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.filepath);
        self.allocator.free(self.directory);
        for (self.added_textures.items) |added| {
            self.allocator.free(added.mesh_name);
            self.allocator.free(added.texture_filename);
        }
        self.added_textures.deinit();
        self.allocator.destroy(self);
    }

    const AddedTexture = struct {
        mesh_name: []const u8,
        texture_config: TextureConfig,
        texture_filename: []const u8,
    };

    pub fn init(allocator: Allocator, texture_cache: *ArrayList(*Texture), name: []const u8, path: []const u8) !*Self {
        const meshes = try allocator.create(ArrayList(*ModelMesh));
        meshes.* = ArrayList(*ModelMesh).init(allocator);

        // const model_bone_map = try allocator.create(StringHashMap(*ModelBone));
        // model_bone_map.* = StringHashMap(*ModelBone).init(allocator);

        const builder = try allocator.create(Self);
        builder.* = GltfBuilder{
            .name = try allocator.dupe(u8, name),
            .filepath = try allocator.dupeZ(u8, path),
            .directory = try allocator.dupe(u8, Path.dirname(path) orelse ""),
            .texture_cache = texture_cache,
            .added_textures = ArrayList(AddedTexture).init(allocator),
            .meshes = meshes,
            .mesh_count = 0,
            //.model_bone_map = model_bone_map,
            .bone_count = 0,
            .gamma_correction = false,
            .flip_v = false,
            .flip_h = false,
            .load_textures = true,
            .allocator = allocator,
        };

        return builder;
    }

    pub fn flipv(self: *Self) *Self {
        self.*.flip_v = true;
        return self;
    }

    pub fn addTexture(self: *Self, mesh_name: []const u8, texture_config: TextureConfig, texture_filename: []const u8) !void { // !*Self {
        const added = AddedTexture{
            .mesh_name = try self.allocator.dupe(u8, mesh_name),
            .texture_config = texture_config,
            .texture_filename = try self.allocator.dupe(u8, texture_filename),
        };
        try self.added_textures.append(added);
    }

    pub fn skipModelTextures(self: *Self) void {
        self.load_textures = false;
    }

    pub fn build(self: *Self) !*Model {
        const buf = std.fs.cwd().readFileAllocOptions(
            self.allocator,
            self.filepath,
            512_000,
            null,
            4,
            null,
        ) catch |err| std.debug.panic("error: {any}\n", .{err});

        defer self.allocator.free(buf);

        var gltf = Gltf.init(self.allocator);
        defer gltf.deinit();

        try gltf.parse(buf);

        const data = gltf.data;
        std.debug.print("meshes count: {d}\n", .{data.meshes.items.len});

        const animator = try Animator.init(self.allocator);

        const model = try self.allocator.create(Model);
        model.* = Model{
            .allocator = self.allocator,
            .name = try self.allocator.dupe(u8, self.name),
            .meshes = self.meshes,
            .animator = animator,
        };

        return model;
    }
};
