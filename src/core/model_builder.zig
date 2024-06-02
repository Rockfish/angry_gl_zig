const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const ModelVertex = @import("model_mesh.zig").ModelVertex;
const Model = @import("model.zig").Model;
const Animator = @import("animator.zig").Animator;
const Assimp = @import("assimp.zig").Assimp;
const BoneData = @import("model_animation.zig").BoneData;
const Transform = @import("transform.zig").Transform;
const String = @import("string.zig").String;
const Model_Mesh = @import("model_mesh.zig");
const utils = @import("utils.zig");
const panic = @import("std").debug.panic;


const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Path = std.fs.path;
const TextureType = Texture.TextureType;
const ModelMesh = Model_Mesh.ModelMesh;
const CVec2 = Model_Mesh.CVec2;
const CVec3 = Model_Mesh.CVec3;

pub const ModelBuilder = struct {
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    texture_cache: *ArrayList(*Texture),
    added_textures: ArrayList(AddedTexture),
    bone_data_map: *StringHashMap(*BoneData),
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
        texture_config: Texture.TextureConfig,
        texture_filename: []const u8,
    };

    pub fn init(allocator: Allocator, texture_cache: *ArrayList(*Texture), name: []const u8, path: []const u8) !*Self {
        const meshes = try allocator.create(ArrayList(*ModelMesh));
        meshes.* = ArrayList(*ModelMesh).init(allocator);

        const bone_data_map = try allocator.create(StringHashMap(*BoneData));
        bone_data_map.* = StringHashMap(*BoneData).init(allocator);

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
        for (self.added_textures.items) |added| {
            self.allocator.free(added.mesh_name);
            self.allocator.free(added.texture_filename);
        }
        self.added_textures.deinit();
        self.allocator.destroy(self);
    }

    pub fn flipv(self: *Self) *Self {
        self.*.flip_v = true;
        return self;
    }

    pub fn addTexture(self: *Self, mesh_name: []const u8, texture_config: Texture.TextureConfig, texture_filename: []const u8) !void { // !*Self {
        const added = AddedTexture{
            .mesh_name = try self.allocator.dupe(u8, mesh_name),
            .texture_config = texture_config,
            .texture_filename = try self.allocator.dupe(u8, texture_filename),
        };
        try self.added_textures.append(added);
        // return self;
    }

    pub fn skip_textures(self: *Self) *Self {
        self.load_textures = false;
    }

    pub fn build(self: *Self) !*Model {
        const aiScene = try self.loadScene(self.filepath);

        try self.load_model(aiScene);
        try self.add_textures();

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
            const name = node.mName.data[0..@min(1024, node.mName.length)];
            std.debug.print("Builder: node name: '{s}'  num children: {d}\n", .{ name, node.mNumChildren });
        } else {
            std.debug.print("Builder: node error\n", .{});
        }

        const num_mesh: u32 = node.mNumMeshes;
        for (0..num_mesh) |i| {
            const aiMesh = aiScene[0].mMeshes[node.mMeshes[i]][0];
            const model_mesh = try self.processMesh(aiMesh, aiScene);
            try self.meshes.append(model_mesh);
        }

        const name = node.mName.data[0..@min(1024, node.mName.length)];

        const num_children: u32 = node.mNumChildren;
        for (node.mChildren[0..num_children]) |child| {
            std.debug.print("Builder: parent calling child, parent name: '{s}'\n", .{name});
            try self.processNode(child, aiScene);
        }
        std.debug.print("Builder: finished node name: '{s}'  num chidern: {d}\n", .{ name, node.mNumChildren });
    }

    fn processMesh(self: *Self, aiMesh: Assimp.aiMesh, aiScene: [*c]const Assimp.aiScene) !*ModelMesh {
        var vertices = try self.allocator.create(ArrayList(ModelVertex));
        vertices.* = ArrayList(ModelVertex).init(self.allocator);
        var indices = try self.allocator.create(ArrayList(u32));
        indices.* = ArrayList(u32).init(self.allocator);

        for (0..aiMesh.mNumVertices) |i| {
            var model_vertex = ModelVertex.init();
            model_vertex.position = vec3FromVector3D(aiMesh.mVertices[i]);

            if (aiMesh.mNormals != null) {
                model_vertex.normal = vec3FromVector3D(aiMesh.mNormals[i]);
            }

            if (aiMesh.mTextureCoords[0] != null) {
                const tex_coords = aiMesh.mTextureCoords[0];
                model_vertex.uv = CVec2.new(tex_coords[i].x, tex_coords[i].y);
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

        const texture_types = [_]TextureType{ TextureType.Diffuse, TextureType.Specular, TextureType.Emissive, TextureType.Normals };
        var material = aiScene[0].mMaterials[aiMesh.mMaterialIndex][0];
        const textures = try self.loadMaterialTextures(&material, texture_types[0..]);

        try self.extract_bone_weights_for_vertices(vertices, aiMesh);

        const name = aiMesh.mName.data[0 .. aiMesh.mName.length];
        const model_mesh = try ModelMesh.init(self.allocator, self.mesh_count, name, vertices, indices, textures);

        self.mesh_count += 1;
        return model_mesh;
    }

    fn loadMaterialTextures(self: *Self, material: *Assimp.aiMaterial, texture_types: []const TextureType) !*ArrayList(*Texture) {
        var material_textures = try self.allocator.create(ArrayList(*Texture));
        material_textures.* = ArrayList(*Texture).init(self.allocator);

        for (texture_types) |texture_type| {
            const texture_count = Assimp.aiGetMaterialTextureCount(material, @intFromEnum(texture_type));

            for (0..texture_count) |i| {
                const path = try self.allocator.create(Assimp.aiString);
                defer self.allocator.destroy(path);

                const ai_return = GetMaterialTexture(material, texture_type, @intCast(i), path);
                if (ai_return == Assimp.AI_SUCCESS) {
                    const full_path = try Path.join(self.allocator, &.{ self.directory, path.data[0 .. path.length] });
                    defer self.allocator.free(full_path);

                    const texture = try self.loadTexture(Texture.TextureConfig.new(texture_type), full_path);
                    try material_textures.append(texture);
                }
            }
        }
        return material_textures;
    }

    fn add_textures(self: *Self) !void {
        for (self.added_textures.items) |added_texture| {
            const mesh: *ModelMesh = for (self.meshes.items) |_mesh| {
                if (std.mem.eql(u8,_mesh.*.name, added_texture.mesh_name)) {
                    break _mesh;
                }
            } else {
                panic("add_texture mesh: {s} not found.", .{added_texture.mesh_name});
            };

            const has_texture = for (mesh.*.textures.items) |mesh_texture| {
                if (std.mem.eql(u8, mesh_texture.*.texture_path, added_texture.texture_filename)) {
                    break true;
                }
            } else false;

            if (!has_texture) {
                const texture = try self.loadTexture(added_texture.texture_config, added_texture.texture_filename);
                try mesh.*.textures.append(texture);
            }
        }
    }

    fn loadTexture(self: *Self, texture_config: Texture.TextureConfig, file_path: []const u8) !*Texture {
        for (self.texture_cache.items) |cached_texture| {
            if (std.mem.eql(u8, cached_texture.texture_path, file_path)) {
                const texture = try self.allocator.create(Texture);
                texture.* = .{
                    .id = cached_texture.id,
                    .texture_path = try cached_texture.allocator.dupe(u8, cached_texture.texture_path),
                    .texture_type = texture_config.texture_type,
                    .height = cached_texture.height,
                    .width = cached_texture.width,
                    .allocator = cached_texture.allocator,
                };
                std.debug.print("ModelBuilder loadTexture- id: {d}  type: {any}  path: {s}\n", .{texture.id, texture.texture_type, texture.texture_path});
                return texture;
            }
        }

        const texture = try self.allocator.create(Texture);
        texture.* = try Texture.new(self.allocator, file_path, texture_config);
        try self.texture_cache.append(texture);

        std.debug.print("Builder: created a new texture: {s}\n", .{texture.texture_path});
        return texture;
    }

    fn extract_bone_weights_for_vertices(self: *Self, vertices: *ArrayList(ModelVertex), aiMesh: Assimp.aiMesh) !void {

        if (aiMesh.mNumBones == 0) {
            return;
        }
         
        for (aiMesh.mBones[0..aiMesh.mNumBones]) |bone| {
            var bone_id: i32 = undefined;
            const bone_name = bone.*.mName.data[0..bone.*.mName.length];

            const result = try self.bone_data_map.getOrPut(bone_name);

            if (result.found_existing) {
                bone_id = result.value_ptr.*.bone_index;
            } else {
                const bone_data = try self.allocator.create(BoneData);
                bone_data.* = BoneData {
                    .name = try String.new(bone_name),
                    .bone_index = self.bone_count,
                    .offset_transform = utils.transfrom_from_aiMatrix(bone.*.mOffsetMatrix),
                    .allocator = self.allocator,
                };
                result.value_ptr.* = bone_data;
                bone_id = self.bone_count;
                self.bone_count += 1;
            }

            for (bone.*.mWeights[0..bone.*.mNumWeights]) |bone_weight| {
                const vertex_id: u32 = bone_weight.mVertexId;
                const weight: f32 = bone_weight.mWeight;
                vertices.items[vertex_id].set_bone_data(bone_id, weight);
            }
        }
    }
};

inline fn vec2FromVector2D(aiVec: Assimp.aiVector2D) CVec2 {
    return CVec2.new(aiVec.x, aiVec.y);
}

inline fn vec3FromVector3D(aiVec: Assimp.aiVector3D) CVec3 {
    return CVec3.new(aiVec.x, aiVec.y, aiVec.z);
}

inline fn GetMaterialTexture(
    material: *Assimp.aiMaterial,
    texture_type: Texture.TextureType,
    index: u32,
    path: *Assimp.aiString,
) Assimp.aiReturn {
    return Assimp.aiGetMaterialTexture(material, @intFromEnum(texture_type), index, path, null, null, null, null, null, null);
}

fn printSceneInfo(aiScene: Assimp.aiScene) void {
    std.debug.print("number of meshes: {d}\n", .{aiScene.mNumMeshes});
    std.debug.print("number of materials: {d}\n", .{aiScene.mNumMaterials});
    std.debug.print("number of mNumTextures: {d}\n", .{aiScene.mNumTextures});
    std.debug.print("number of mNumAnimations: {d}\n", .{aiScene.mNumAnimations});
    std.debug.print("number of mNumLights: {d}\n", .{aiScene.mNumLights});
    std.debug.print("number of mNumCameras: {d}\n", .{aiScene.mNumCameras});
    std.debug.print("number of mNumSkeletons: {d}\n", .{aiScene.mNumSkeletons});
}
