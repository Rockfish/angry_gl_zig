const std = @import("std");
const gl = @import("zopengl").bindings;
const panic = @import("std").debug.panic;
const ModelVertex = @import("model_mesh.zig").ModelVertex;
const Model = @import("model.zig").Model;
const Animator = @import("animator.zig").Animator;
const assimp = @import("assimp.zig");
const BoneData = @import("model_animation.zig").BoneData;
const Transform = @import("transform.zig").Transform;
const String = @import("string.zig").String;
const Model_Mesh = @import("model_mesh.zig");
const utils = @import("utils/main.zig");
const math = @import("math");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Path = std.fs.path;

const texture_ = @import("texture.zig");
const Texture = texture_.Texture;
const TextureType = texture_.TextureType;
const TextureConfig = texture_.TextureConfig;
const TextureFilter = texture_.TextureFilter;
const TextureWrap = texture_.TextureWrap;
const Assimp = assimp.Assimp;
const ModelMesh = Model_Mesh.ModelMesh;
const MeshColor = Model_Mesh.MeshColor;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

pub const MaterialKey = struct {
    ai_key: [:0]const u8,
    uniform: [:0]const u8,
};

// Redefining Assimp.AI_MATKEY's because they are c macros that don't import correctly.
pub const MATKEY_NAME: MaterialKey = .{ .ai_key = "?mat.name", .uniform = "material_name" };
pub const MATKEY_COLOR_DIFFUSE: MaterialKey = .{ .ai_key = "$clr.diffuse", .uniform = "diffuse_color" };
pub const MATKEY_COLOR_AMBIENT: MaterialKey = .{ .ai_key = "$clr.ambient", .uniform = "ambient_color" };
pub const MATKEY_COLOR_SPECULAR: MaterialKey = .{ .ai_key = "$clr.specular", .uniform = "specular_color" };
pub const MATKEY_COLOR_EMISSIVE: MaterialKey = .{ .ai_key = "$clr.emissive", .uniform = "emissive_color" };

pub const ModelBuilder = struct {
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    texture_cache: *ArrayList(*Texture),
    added_textures: ArrayList(AddedTexture),
    bone_data_map: *StringHashMap(*BoneData),
    bone_count: i32,
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
        // allocator: Allocator,
        //
        // pub fn deinit(self: *AddedTexture) void {
        //     self.allocator.free(self.mesh_name);
        //     self.allocator.free(self.texture_filename);
        // }
    };

    pub fn init(allocator: Allocator, texture_cache: *ArrayList(*Texture), name: []const u8, path: []const u8) !*Self {
        const meshes = try allocator.create(ArrayList(*ModelMesh));
        meshes.* = ArrayList(*ModelMesh).init(allocator);

        const bone_data_map = try allocator.create(StringHashMap(*BoneData));
        bone_data_map.* = StringHashMap(*BoneData).init(allocator);

        const builder = try allocator.create(Self);
        builder.* = ModelBuilder{
            .name = try allocator.dupe(u8, name),
            .filepath = try allocator.dupeZ(u8, path),
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
        const aiScene = Assimp.aiImportFile(
            self.filepath,
            Assimp.aiProcess_CalcTangentSpace |
                Assimp.aiProcess_Triangulate |
                Assimp.aiProcess_JoinIdenticalVertices |
                Assimp.aiProcess_SortByPType |
                Assimp.aiProcess_FlipUVs |
                Assimp.aiProcess_FindInvalidData, // this fixes animation by removing duplicate keys
        );

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

        Assimp.aiReleaseImport(aiScene);

        return model;
    }

    fn load_model(self: *Self, aiScene: [*]const Assimp.aiScene) !void {
        try self.processNode(aiScene[0].mRootNode, aiScene);
    }

    fn processNode(self: *Self, node: *const Assimp.aiNode, aiScene: [*c]const Assimp.aiScene) !void {
        // std.debug.print("Builder: processing node: {any}\n", .{node});
        // if (node.mName.length < 1024) {
        //     const name = node.mName.data[0..@min(1024, node.mName.length)];
        //     std.debug.print("Builder: node name: '{s}'  num children: {d}\n", .{ name, node.mNumChildren });
        // } else {
        //     std.debug.print("Builder: node error\n", .{});
        // }

        const num_mesh: u32 = node.mNumMeshes;
        for (0..num_mesh) |i| {
            const aiMesh = aiScene[0].mMeshes[node.mMeshes[i]][0];
            const model_mesh = try self.processMesh(aiMesh, aiScene);
            try self.meshes.append(model_mesh);
        }

        // const name = node.mName.data[0..@min(1024, node.mName.length)];

        const num_children: u32 = node.mNumChildren;
        if (num_children > 0) {
            for (node.mChildren[0..num_children]) |child| {
                // std.debug.print("Builder: parent calling child, parent name: '{s}'\n", .{name});
                try self.processNode(child, aiScene);
            }
        }
        // std.debug.print("Builder: finished node name: '{s}'  num chidern: {d}\n", .{ name, node.mNumChildren });
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
                model_vertex.uv = Vec2.new(tex_coords[i].x, tex_coords[i].y);
                model_vertex.tangent = vec3FromVector3D(aiMesh.mTangents[i]);
                model_vertex.bi_tangent = vec3FromVector3D(aiMesh.mBitangents[i]);
            }

            if (aiMesh.mColors[0] != null) {
                const color = vec4FromColor4D(aiMesh.mColors[0][i]);
                std.debug.print("v: {d}  mColor: {any}\n", .{ i, color });
            }

            try vertices.append(model_vertex);
        }

        for (0..aiMesh.mNumFaces) |i| {
            const face = aiMesh.mFaces[i];
            for (0..face.mNumIndices) |j| {
                try indices.append(face.mIndices[j]);
            }
        }

        const name = aiMesh.mName.data[0..aiMesh.mName.length];
        // std.debug.print("\nmesh name: {s} verts: {d} indices: {d} \n", .{ name, vertices.items.len, indices.items.len });

        var material = aiScene[0].mMaterials[aiMesh.mMaterialIndex][0];

        const colors = try self.loadMaterialColors(&material);

        const texture_types = [_]TextureType{ .Diffuse, .Specular, .Ambient, .Emissive, .Normals };
        const textures = try self.loadMaterialTextures(&material, texture_types[0..]);

        try self.extract_bone_weights_for_vertices(vertices, aiMesh);

        const model_mesh = try ModelMesh.init(
            self.allocator,
            self.mesh_count,
            name,
            vertices,
            indices,
            textures,
            colors,
        );

        self.mesh_count += 1;
        return model_mesh;
    }

    fn loadMaterialColors(self: *Self, material: *Assimp.aiMaterial) !*ArrayList(*MeshColor) {
        // const material_name = GetMaterialName(material);
        // if (material_name) |n| {
        //     std.debug.print("material_name: {s}\n", .{n});
        // }

        const color_keys = [_]MaterialKey{
            MATKEY_COLOR_DIFFUSE,
            MATKEY_COLOR_AMBIENT,
            MATKEY_COLOR_SPECULAR,
            MATKEY_COLOR_EMISSIVE,
        };

        const colors = try self.allocator.create(ArrayList(*MeshColor));
        colors.* = ArrayList(*MeshColor).init(self.allocator);

        for (color_keys) |color_key| {
            const color = GetMaterialColor(material, color_key);
            if (color) |c| {
                // std.debug.print("color {s}: {any}\n", .{ color_key.ai_key, c });
                const mesh_color = try self.allocator.create(MeshColor);
                mesh_color.* = .{ .uniform = color_key.uniform, .color = c };
                try colors.*.append(mesh_color);
            }
        }

        return colors;
    }

    fn loadMaterialTextures(self: *Self, material: *Assimp.aiMaterial, texture_types: []const TextureType) !*ArrayList(*Texture) {
        var material_textures = try self.allocator.create(ArrayList(*Texture));
        material_textures.* = ArrayList(*Texture).init(self.allocator);

        if (self.load_textures == false) {
            return material_textures;
        }

        for (texture_types) |texture_type| {
            const texture_count = Assimp.aiGetMaterialTextureCount(material, @intFromEnum(texture_type));

            for (0..texture_count) |i| {
                const path = try self.allocator.create(Assimp.aiString);
                defer self.allocator.destroy(path);

                const ai_return = GetMaterialTexture(material, texture_type, @intCast(i), path);

                if (ai_return == Assimp.AI_SUCCESS) {
                    const texture = try self.loadTexture(TextureConfig.new(texture_type), path.data[0..path.length]);
                    //std.debug.print("texture: {any}\n", .{texture});
                    try material_textures.append(texture);
                }
            }
        }
        return material_textures;
    }

    fn add_textures(self: *Self) !void {
        for (self.added_textures.items) |added_texture| {
            const mesh: *ModelMesh = for (self.meshes.items) |_mesh| {
                if (std.mem.eql(u8, _mesh.*.name, added_texture.mesh_name)) {
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

    fn loadTexture(self: *Self, texture_config: TextureConfig, file_path: []const u8) !*Texture {
        const filename = try utils.getExistsFilename(self.allocator, self.directory, file_path);
        defer self.allocator.free(filename);

        for (self.texture_cache.items) |cached_texture| {
            if (std.mem.eql(u8, cached_texture.texture_path, file_path)) {
                const texture = try cached_texture.clone();
                texture.texture_type = texture_config.texture_type;
                return texture;
            }
        }

        const texture = try Texture.new(self.allocator, filename, texture_config);
        try self.texture_cache.append(texture);

        // std.debug.print("Builder: created a new texture: {s}\n", .{texture.texture_path});
        return texture;
    }

    fn extract_bone_weights_for_vertices(self: *Self, vertices: *ArrayList(ModelVertex), aiMesh: Assimp.aiMesh) !void {
        if (aiMesh.mNumBones == 0) {
            return;
        }

        for (aiMesh.mBones[0..aiMesh.mNumBones]) |bone| {
            var bone_id: i32 = undefined;
            const bone_name = bone.*.mName.data[0..bone.*.mName.length];

            const result = self.bone_data_map.get(bone_name);

            if (result != null) {
                bone_id = result.?.bone_index;
            } else {
                const bone_data = try self.allocator.create(BoneData);
                bone_data.* = BoneData{
                    .name = try String.new(bone_name),
                    .bone_index = self.bone_count,
                    .offset_transform = Transform.from_matrix(&assimp.mat4_from_aiMatrix(&bone.*.mOffsetMatrix)),
                    .allocator = self.allocator,
                };

                const key = try self.allocator.dupe(u8, bone_name);
                try self.bone_data_map.put(key, bone_data);
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

inline fn vec2FromVector2D(aiVec: Assimp.aiVector2D) Vec2 {
    return Vec2.new(aiVec.x, aiVec.y);
}

inline fn vec3FromVector3D(aiVec: Assimp.aiVector3D) Vec3 {
    return Vec3.new(aiVec.x, aiVec.y, aiVec.z);
}

inline fn vec4FromColor4D(aiColor: Assimp.aiColor4D) Vec4 {
    return Vec4.new(aiColor.r, aiColor.g, aiColor.b, aiColor.a);
}

inline fn GetMaterialTexture(
    material: *Assimp.aiMaterial,
    texture_type: TextureType,
    index: u32,
    path: *Assimp.aiString,
) Assimp.aiReturn {
    return Assimp.aiGetMaterialTexture(
        material,
        @intFromEnum(texture_type),
        index,
        path,
        null,
        null,
        null,
        null,
        null,
        null,
    );
}

inline fn GetMaterialColor(
    material: *Assimp.aiMaterial,
    material_key: MaterialKey,
) ?Vec4 {
    var ai_color: Assimp.aiColor4D = undefined;
    if (Assimp.AI_SUCCESS == Assimp.aiGetMaterialColor(material, material_key.ai_key, 0, 0, &ai_color)) {
        const c = vec4FromColor4D(ai_color);
        if (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) {
            return null;
        }
        return c;
    }
    return null;
}

inline fn GetMaterialName(
    material: *Assimp.aiMaterial,
) ?[]u8 {
    const property = GetMaterialProperty(material, MATKEY_NAME);
    if (property) |p| {
        const mat_name: []u8 = p.*.mData[4 .. p.*.mDataLength - 1];
        return mat_name;
    }
    return null;
}

inline fn GetMaterialProperty(
    material: *Assimp.aiMaterial,
    material_key: MaterialKey,
) ?*Assimp.aiMaterialProperty {
    for (0..material.mNumProperties) |i| {
        const property = material.mProperties[i];
        const key_name = property.*.mKey.data[0..property.*.mKey.length];
        if (std.mem.eql(u8, material_key.ai_key, key_name)) {
            return property;
        }
    }
    return null;
}

// var ai_name: Assimp.aiString = undefined;
// _ = Assimp.aiGetMaterialString(&material,Assimp.AI_MATKEY_NAME,0, 0, &ai_name);
// const material_name = ai_name.data[0..ai_name.length];
// std.debug.print("\nmaterial name: {s}\n", .{material_name});

fn printSceneInfo(aiScene: Assimp.aiScene) void {
    std.debug.print("number of meshes: {d}\n", .{aiScene.mNumMeshes});
    std.debug.print("number of materials: {d}\n", .{aiScene.mNumMaterials});
    std.debug.print("number of mNumTextures: {d}\n", .{aiScene.mNumTextures});
    std.debug.print("number of mNumAnimations: {d}\n", .{aiScene.mNumAnimations});
    std.debug.print("number of mNumLights: {d}\n", .{aiScene.mNumLights});
    std.debug.print("number of mNumCameras: {d}\n", .{aiScene.mNumCameras});
    std.debug.print("number of mNumSkeletons: {d}\n", .{aiScene.mNumSkeletons});
}
