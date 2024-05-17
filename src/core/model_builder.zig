const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const ModelVertex = @import("model_mesh.zig").ModelVertex;
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Model = @import("model.zig").Model;
const Animator = @import("animator.zig").Animator;
const Assimp = @import("assimp.zig").Assimp;
const BoneData = @import("model_animation.zig").BoneData;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Path = std.fs.path;

pub const ModelBuilder = struct {
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    texture_cache: *ArrayList(*Texture),
    added_textures: ArrayList(AddedTexture),
    bone_data_map: *StringHashMap(BoneData),
    bone_count: i32,
    filepath: []const u8,
    directory: []const u8,
    gamma_correction: bool,
    flip_v: bool,
    flip_h: bool,
    load_textures: bool,
    mesh_count: i32,
    allocator: Allocator,

    const Self = @This();

    const AddedTexture = struct {
        mesh_name: []const u8,
        texture_type: Texture.TextureType,
        texture_filename: []const u8,
    };

    pub fn init(allocator: Allocator, texture_cache: *ArrayList(*Texture), name: []const u8, path: []const u8) !*Self {
        const meshes = try allocator.create(ArrayList(*ModelMesh));
        meshes.* = ArrayList(*ModelMesh).init(allocator);

        const bone_data_map = try allocator.create(StringHashMap(BoneData));
        bone_data_map.* = StringHashMap(BoneData).init(allocator);

        const builder = try allocator.create(Self);
        builder.* = ModelBuilder{
            .name = try allocator.dupe(u8, name),
            .filepath = try allocator.dupe(u8, path),
            .directory = try allocator.dupe(u8, Path.dirname(path) orelse ""),
            .texture_cache = texture_cache,
            .added_textures = ArrayList(AddedTexture).init(allocator),
            .meshes = meshes,
            .mesh_count = 0,
            .bone_data_map = bone_data_map,
            .bone_count = 0,
            .gamma_correction = false,
            .flip_v = false,
            .flip_h = false,
            .load_textures = true,
            .allocator = allocator,
        };

        return builder;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.free(self.filepath);
        self.allocator.free(self.directory);
        self.added_textures.deinit();
        self.allocator.destroy(self);
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

    pub fn build(self: *Self) !*Model {
        const aiScene = try self.loadScene(self.filepath);

        try self.load_model(aiScene);
        const animator = try Animator.init(self.allocator, aiScene, self.bone_data_map);

        const model = try self.allocator.create(Model);
        model.* = Model{
            .allocator = self.allocator,
            .name = try self.allocator.dupe(u8, self.name),
            .meshes = self.meshes,
            .animator = animator,
        };

        std.debug.print("Builder: finishing up\n", .{});
        return model;
    }

    fn loadScene(self: *Self, file_path: []const u8) ![*c]const Assimp.aiScene {
        const c_path: [:0]const u8 = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(c_path);

        const aiScene: [*c]const Assimp.aiScene = Assimp.aiImportFile(c_path, Assimp.aiProcess_CalcTangentSpace |
            Assimp.aiProcess_Triangulate |
            Assimp.aiProcess_JoinIdenticalVertices |
            Assimp.aiProcess_SortByPType);

        printSceneInfo(aiScene[0]);
        return aiScene;
    }

    fn load_model(self: *Self, aiScene: [*]const Assimp.aiScene) !void {
        try self.processNode(aiScene[0].mRootNode, aiScene);
    }

    fn processNode(self: *Self, node: *const Assimp.aiNode, aiScene: [*c]const Assimp.aiScene) !void {
        // std.debug.print("Builder: processing node: {any}\n", .{node});
        if (node.mName.length < 1024) {
            const c_name = node.mName.data[0..@min(1024, node.mName.length + 1)];
            std.debug.print("Builder: node name: '{s}'  num children: {d}\n", .{ c_name, node.mNumChildren });
        } else {
            std.debug.print("Builder: node error\n", .{});
        }

        const num_mesh: u32 = node.mNumMeshes;
        for (0..num_mesh) |i| {
            const aiMesh = aiScene[0].mMeshes[node.mMeshes[i]][0];
            const model_mesh = try self.processMesh(aiMesh, aiScene);
            try self.meshes.append(model_mesh);
        }

        const c_name = node.mName.data[0..@min(1024, node.mName.length + 1)];

        const num_children: u32 = node.mNumChildren;
        for (node.mChildren[0..num_children]) |child| {
            std.debug.print("Builder: parent calling child, parent name: '{s}'\n", .{c_name});
            try self.processNode(child, aiScene);
        }
        std.debug.print("Builder: finished node name: '{s}'  num chidern: {d}\n", .{ c_name, node.mNumChildren });
    }

    fn processMesh(self: *Self, aiMesh: Assimp.aiMesh, aiScene: [*c]const Assimp.aiScene) !*ModelMesh {
        var vertices = ArrayList(ModelVertex).init(self.allocator);
        var indices = ArrayList(u32).init(self.allocator);
        var textures = ArrayList(*Texture).init(self.allocator);

        for (0..aiMesh.mNumVertices) |i| {
            var model_vertex = ModelVertex.init();
            model_vertex.position = vec3FromVector3D(aiMesh.mVertices[i]);

            if (aiMesh.mNormals != null) {
                model_vertex.normal = vec3FromVector3D(aiMesh.mNormals[i]);
            }

            if (aiMesh.mTextureCoords[0] != null) {
                const tex_coords = aiMesh.mTextureCoords[0];
                model_vertex.uv = .{ tex_coords[i].x, tex_coords[i].y };
                model_vertex.tangent = vec3FromVector3D(aiMesh.mTangents[i]);
                model_vertex.bi_tangent = vec3FromVector3D(aiMesh.mBitangents[i]);
            }
            try vertices.append(model_vertex);
        }

        for (0..aiMesh.mNumFaces) |i| {
            const face = aiMesh.mFaces[i];
            for (0..face.mNumIndices) |j| {
                try indices.append(face.mIndices[j]);
            }
        }

        var material = aiScene[0].mMaterials[aiMesh.mMaterialIndex][0];
        // std.debug.print("processMesh material: {any}\n", .{material});

        const material_textures = try self.loadMaterialTextures(&material, Texture.TextureType.Diffuse);
        // std.debug.print("processMesh material_textures: {any}\n", .{material_textures});

        try textures.appendSlice(material_textures.items);
        material_textures.deinit();

        const c_name = aiMesh.mName.data[0 .. aiMesh.mName.length + 1];
        std.debug.print("Builder: creating a mesh with name: {s}\n", .{c_name});
        const model_mesh = try ModelMesh.init(self.allocator, self.mesh_count, c_name, vertices, indices, textures);
        std.debug.print("Builder: meshed created. name: {s}\n", .{c_name});
        self.mesh_count += 1;
        return model_mesh;
    }

    fn loadMaterialTextures(self: *Self, material: *Assimp.aiMaterial, texture_type: Texture.TextureType) !ArrayList(*Texture) {
        var material_textures = ArrayList(*Texture).init(self.allocator);
        const texture_count = Assimp.aiGetMaterialTextureCount(material, @intFromEnum(texture_type));

        for (0..texture_count) |i| {
            const ai_str = try self.allocator.create(Assimp.aiString);
            defer self.allocator.destroy(ai_str);
            // Assimp.aiGetMaterialTexture

            const ai_return = GetMaterialTexture(material, texture_type, @intCast(i), ai_str);
            if (ai_return == Assimp.AI_SUCCESS) {
                const path: []const u8 = ai_str.data[0 .. ai_str.length + 1];
                const full_path = try Path.join(self.allocator, &.{ self.directory, path });
                defer self.allocator.free(full_path);
                // std.debug.print("full path path: {s}\n", .{full_path});
                const texture = try self.loadTexture(texture_type, full_path);
                try material_textures.append(texture);
            }
        }
        return material_textures;
    }

    fn loadTexture(self: *Self, texture_type: Texture.TextureType, file_path: []u8) !*Texture {
        for (self.texture_cache.items) |cached_texture| {
            if (std.mem.eql(u8, cached_texture.texture_path, file_path)) {
                return cached_texture;
            }
        }

        const texture_config: Texture.TextureConfig = .{ .texture_type = texture_type, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Repeat };

        const texture = try self.allocator.create(Texture);
        texture.* = try Texture.new(self.allocator, file_path, texture_config);
        try self.texture_cache.append(texture);
        std.debug.print("Builder: created a new texture: {s}\n", .{texture.texture_path});
        return texture;
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

inline fn vec2FromVector2D(aiVec: Assimp.aiVector2D) zm.Vec2 {
    return .{ aiVec.x, aiVec.y };
}

inline fn vec3FromVector3D(aiVec: Assimp.aiVector3D) zm.Vec3 {
    return .{ aiVec.x, aiVec.y, aiVec.z };
}

inline fn GetMaterialTexture(
    material: *Assimp.aiMaterial,
    texture_type: Texture.TextureType,
    index: u32,
    path: *Assimp.aiString,
) Assimp.aiReturn {
    return Assimp.aiGetMaterialTexture(material, @intFromEnum(texture_type), index, path, null, null, null, null, null, null);
}
