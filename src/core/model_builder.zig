const std = @import("std");
const zm = @import("zmath");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const ModelVertex = @import("model_mesh.zig").ModelVertex;
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Model = @import("model.zig").Model;
const Animator = @import("animator.zig").Animator;
const Assimp = @import("assimp.zig").Assimp;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ModelBuilder = struct {
    name: []const u8,
    meshes: ArrayList(*ModelMesh),
    // bone_data_map: RefCell<HashMap<BoneName, BoneData>>,
    bone_count: i32,
    filepath: []const u8,
    directory: []const u8,
    gamma_correction: bool,
    flip_v: bool,
    flip_h: bool,
    load_textures: bool,
    textures_cache: ArrayList(Texture),
    added_textures: ArrayList(AddedTexture),
    mesh_count: i32,
    allocator: Allocator,

    const Self = @This();

    const AddedTexture = struct {
        mesh_name: []const u8,
        texture_type: Texture.TextureType,
        texture_filename: []const u8,
    };

    pub fn init(allocator: Allocator, name: []const u8, path: []const u8) Self {
        const builder = ModelBuilder{
            .name = name,
            .meshes = ArrayList(*ModelMesh).init(allocator),
            .mesh_count = 0,
            .bone_count = 0,
            .filepath = path,
            .directory = path, // todo: fix, get parent
            .gamma_correction = false,
            .flip_v = false,
            .flip_h = false,
            .load_textures = true,
            .added_textures = ArrayList(AddedTexture).init(allocator),
            .textures_cache = ArrayList(Texture).init(allocator),
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

    pub fn build(self: *Self) !*Model {
        std.debug.print("loading scene. number of meshes: {}\n", .{self.meshes.items.len});
        try self.loadScene(self.filepath);

        const model = try self.allocator.create(Model);
        model.* = Model {
            .allocator = self.allocator,
            .name = self.name,
            .meshes = self.meshes,
            .animator = undefined,
        };

        self.added_textures.deinit();
        self.textures_cache.deinit();

        return model;
    }

    fn loadScene(self: *Self, file_path: []const u8) !void {
        const c_path: [:0]const u8 = try self.allocator.dupeZ(u8, file_path);
        defer self.allocator.free(c_path);

        const aiScene = Assimp.aiImportFile(c_path, Assimp.aiProcess_CalcTangentSpace |
            Assimp.aiProcess_Triangulate |
            Assimp.aiProcess_JoinIdenticalVertices |
            Assimp.aiProcess_SortByPType);

        printSceneInfo(aiScene[0]);

        try self.processNode(aiScene[0].mRootNode[0], aiScene[0]);
    }

    fn processNode(self: *Self, node: Assimp.aiNode, aiScene: Assimp.aiScene) !void {
        const c_name = node.mName.data[0 .. node.mName.length + 1];
        std.debug.print("node name: '{s}'  num meshes: {d}\n", .{ c_name, node.mNumMeshes });

        const num_mesh: u32 = node.mNumMeshes;
        for (0..num_mesh) |i| {
            const aiMesh = aiScene.mMeshes[node.mMeshes[i]][0];
            const model_mesh = try self.processMesh(aiMesh, aiScene);
            try self.meshes.append(model_mesh);
        }

        for (0..node.mNumChildren) |i| {
            try self.processNode(node.mChildren[i][0], aiScene);
        }
    }

    fn processMesh(self: *Self, aiMesh: Assimp.aiMesh, aiScene: Assimp.aiScene) !*ModelMesh {
        var vertices = ArrayList(ModelVertex).init(self.allocator);
        var indices = ArrayList(u32).init(self.allocator);
        const textures = ArrayList(Texture).init(self.allocator);

        for (0..aiMesh.mNumVertices) |i| {
            var model_vertex = ModelVertex.init();
            model_vertex.position = vec3FromVector3D(aiMesh.mVertices[i]);

            if (aiMesh.mNormals != null) {
                model_vertex.normal = vec3FromVector3D(aiMesh.mNormals[i]);
            }
            
            if (aiMesh.mTextureCoords[0] != null) {
                const tex_coords = aiMesh.mTextureCoords[0];
                model_vertex.uv = .{tex_coords[i].x, tex_coords[i].y};
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

        var material = aiScene.mMaterials[aiMesh.mMaterialIndex][0];
        std.debug.print("processMesh material: {any}\n", .{material});

        const material_textures = try self.loadMaterialTextures(&material, Texture.TextureType.Diffuse);
        std.debug.print("processMesh material_textures: {any}\n", .{material_textures});


        const c_name = aiMesh.mName.data[0 .. aiMesh.mName.length + 1];
        const model_mesh = try ModelMesh.init(
            self.allocator, 
            self.mesh_count, 
            c_name, 
            vertices, 
            indices, 
            textures);
        self.mesh_count += 1;
        return model_mesh;
    }

    fn loadMaterialTextures(self: *Self, material: *Assimp.aiMaterial, texture_type: Texture.TextureType) !ArrayList(Texture) {
        const material_textures = ArrayList(Texture).init(self.allocator);
        const texture_count = Assimp.aiGetMaterialTextureCount(material, @intFromEnum(texture_type));

        for (0..texture_count) |i| {
            const ai_str = try self.allocator.create(Assimp.aiString);
            defer self.allocator.destroy(ai_str);
            // Assimp.aiGetMaterialTexture
            
            const ai_return = GetMaterialTexture(material, texture_type, @intCast(i), ai_str);
            const str: []const u8 = ai_str.data[0..ai_str.length + 1];
            std.debug.print("ai_str: {s}\n", .{str});
            std.debug.print("ai_return: {d}\n", .{ai_return});

        } 
        return material_textures;
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
    return Assimp.aiGetMaterialTexture(material, @intFromEnum(texture_type),index,path, null, null, null, null, null, null);
}