const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const ModelVertex = @import("model_mesh.zig").ModelVertex;
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Model = @import("model.zig").Model;
const Animator = @import("animator.zig").Animator;
const Assimp = @import("assimp.zig").Assimp;

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
    added_textures: std.ArrayList(AddedTexture),
    mesh_count: i32,
    allocator: std.mem.Allocator,

    const Self = @This();

    const AddedTexture = struct {
        mesh_name: []const u8,
        texture_type: Texture.TextureType,
        texture_filename: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) Self {
        const builder = ModelBuilder{
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
            .added_textures = std.ArrayList(AddedTexture).init(allocator),
            .textures_cache = std.ArrayList(Texture).init(allocator),
            .allocator = allocator,
        };

        return builder;
    }

    pub fn flipv(self: *Self) *Self {
        self.*.flip_v = true;
        return self;
    }

    pub fn addTexture(self: *Self, mesh_name: []const u8, texture_type: Texture.TextureType, texture_filename: []const u8) *Self {
        const added = AddedTexture{
            .mesh_name = mesh_name,
            .texture_type = texture_type,
            .texture_filename = texture_filename,
        };
        self.added_textures.append(added) catch {
            @panic("ArrayList append error\n");
        };
        return self;
    }

    pub fn skip_textures(self: *Self) *Self {
        self.load_textures = false;
    }

    pub fn build(self: *Self) void { // Model {
        // const model = Model{ .name = self.name, .meshes = self.meshes, .animator = undefined };
        // return model;
        self.loadScene(self.filepath);
        std.debug.print("number of meshes: {}\n", .{self.meshes.items.len});
    }

    fn loadScene(self: *Self, file_path: []const u8) void {
        const c_path: [:0]const u8 = self.allocator.dupeZ(u8, file_path) catch {
            @panic("Allocator dupeZ error.\n");
        };
        const aiScene = Assimp.aiImportFile(c_path, Assimp.aiProcess_CalcTangentSpace |
            Assimp.aiProcess_Triangulate |
            Assimp.aiProcess_JoinIdenticalVertices |
            Assimp.aiProcess_SortByPType);

        printSceneInfo(aiScene[0]);

        self.processNode(aiScene[0].mRootNode[0], aiScene[0]);
    }

    fn processNode(self: *Self, node: Assimp.aiNode, aiScene: Assimp.aiScene) void {
        const c_name = node.mName.data[0..node.mName.length+1];
        std.debug.print("node name: '{s}'  num meshes: {d}\n", .{ c_name, node.mNumMeshes });
        const num_mesh: u32 = node.mNumMeshes;
        for (0..num_mesh) |i| {
            const aiMesh = aiScene.mMeshes[node.mMeshes[i]][0];
            const model_mesh = self.processMesh(aiMesh, aiScene);
            self.meshes.append(model_mesh) catch {
                @panic("Allocator append error.\n");
            };
        }

        for (0..node.mNumChildren) |i| {
            self.processNode(node.mChildren[i][0], aiScene);
        }
    }

    fn processMesh(self: *Self, aiMesh: Assimp.aiMesh, aiScene: Assimp.aiScene) ModelMesh {
        _ = aiScene;
        const vertices = std.ArrayList(ModelVertex).init(self.allocator);
        const indices = std.ArrayList(u32).init(self.allocator);
        const textures = std.ArrayList(Texture).init(self.allocator);

        const c_name = aiMesh.mName.data[0..aiMesh.mName.length+1];
        const mesh = ModelMesh.init(self.mesh_count, c_name, vertices, indices, textures);
        self.mesh_count += 1;
        return mesh;
    }



    fn printSceneInfo(aiScene: Assimp.aiScene) void {
        // if (aiScene != null) {
        // std.debug.print("name: {s}\n", .{aiScene[0].mName.data});
        std.debug.print("number of meshes: {d}\n", .{aiScene.mNumMeshes});
        std.debug.print("number of materials: {d}\n", .{aiScene.mNumMaterials});
        std.debug.print("number of mNumTextures: {d}\n", .{aiScene.mNumTextures});
        std.debug.print("number of mNumAnimations: {d}\n", .{aiScene.mNumAnimations});
        std.debug.print("number of mNumLights: {d}\n", .{aiScene.mNumLights});
        std.debug.print("number of mNumCameras: {d}\n", .{aiScene.mNumCameras});
        std.debug.print("number of mNumSkeletons: {d}\n", .{aiScene.mNumSkeletons});
        // } else {
        // std.debug.print("aiScene is null.\n", .{});
        // const error_string = assimp.aiGetErrorString();
        // std.debug.print("Import error: {s}\n", .{error_string});
        // }
    }
};
