const std = @import("std");
const core = @import("core");
const math = @import("math");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const cglm = math.cglm;
const assimp = core.assimp;
const Assimp = core.assimp.Assimp;
const Transform = core.Transform;
const ModelBone = core.ModelBone;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

var buffer: [2024]u8 = undefined;
var buffer2: [2024]u8 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    core.string.init(allocator);

    const model_paths = [_][]const u8{
        "examples/sample_animation/animated_cube/AnimatedCube.gltf",
        "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/source/cube_capoeira_martelo_cruzando.fbx", // animated nodes, no bones
        "/Users/john/Dev_Rust/Repos/ogldev/Content/box.obj",
        "/Users/john/Dev_Rust/Repos/OpenGL-Animation/Resources/res/model.dae", // doesn't load
        "/Users/john/Dev/Zig/Dev/angry_gl_zig/angrybots_assets/Models/Player/Player.fbx",
        "/Users/john/Dev/Repos/ogldev/Content/jeep.obj",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/RiggedFigure/glTF/RiggedFigure.gltf", // no animation
        "/Users/john/Dev/Repos/irrlicht/media/faerie.md2", // skipModelTextures
        "/Users/john/Downloads/Robot2.fbx", // no animation
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/FBX/Spacesuit.fbx", // bone transforms are messed up
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/glTF/Spacesuit.gltf", 
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/Blends/Spacesuit.blend", // no aimation
        "/Users/john/spacesuit_blender_export_1.fbx",
        "/Users/john/spacesuit_blender_export.glb",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/CesiumMan/glTF/CesiumMan.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/BrainStem/glTF/BrainStem.gltf",
        "/Users/john/Dev/Assets/astronaut_character/astronaut_game_character_animated/scene.gltf",
    };

    // const model_path = "examples/sample_animation/colorful_cube/scene.gltf";

    const path = model_paths[16];

    if (!core.utils.fileExists(path)) {
        std.debug.print("File not found: {s}\n", .{path});
        return;
    }

    const scene = try loadScene(allocator, path);

    if (scene == null) {
        std.debug.print("Scene failed to load: {s}\n", .{path});
        return;
    }

    var parse = SceneParser.new(allocator);
    std.debug.print("scene: {any}\n", .{scene});
    try parse.parse_scene(scene);

    parse.deinit();
}

fn loadScene(allocator: Allocator, file_path: []const u8) ![*c]const Assimp.aiScene {
    const c_path: [:0]const u8 = try allocator.dupeZ(u8, file_path);
    defer allocator.free(c_path);

    const aiScene: [*c]const Assimp.aiScene = Assimp.aiImportFile(
        c_path,
        Assimp.aiProcess_CalcTangentSpace |
            Assimp.aiProcess_Triangulate |
            Assimp.aiProcess_JoinIdenticalVertices |
            Assimp.aiProcess_SortByPType |
            Assimp.aiProcess_FlipUVs |
            Assimp.aiProcess_FindInvalidData,
    );

    if (aiScene == null) {
        const errorMessage = Assimp.aiGetErrorString();
        std.debug.print("aiImportFile error: {s}\n", .{errorMessage});
        std.debug.print("-----------------------------------\n", .{});

        const count = Assimp.aiGetImportFormatCount();
        for (0..count) |i| {
            const desc = Assimp.aiGetImportFormatDescription(i);
            if (desc != null) {
                std.debug.print("Importer: {s}\n", .{desc[0].mName});
                std.debug.print("Description: {s}\n", .{desc[0].mComments});
                std.debug.print("File extensions: {s}\n", .{desc[0].mFileExtensions});
                std.debug.print("-----------------------------------\n", .{});
            }
        }
    }

    // printSceneInfo(aiScene[0]);
    return aiScene;
}

const MAX_BONE_INFLUENCE: i32 = 4;

const VertexBoneData = struct {
    bone_ids: [MAX_BONE_INFLUENCE]i32,
    bone_weights: [MAX_BONE_INFLUENCE]f32,
    index: i32,

    const Self = @This();

    pub fn new() Self {
        return VertexBoneData{
            .bone_ids = [_]i32{ -1, -1, -1, -1 },
            .bone_weights = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
            .index = 0,
        };
    }

    pub fn add_bone_data(self: *Self, bone_id: i32, weight: f32) void {
        for (0..self.index) |i| {
            if (self.bone_ids[i] == bone_id) {
                std.debug.print("bone {} already found at index {} old weight {} new weight {}\n", bone_id, i, self.weights[i], weight);
                return;
            }
        }

        std.debug.print("bone {} weight {} at index {}\n", bone_id, weight, self.index);

        if (self.index >= MAX_BONE_INFLUENCE) {
            std.debug.print("Warning: exceeding the maximum number of bones per vertex (current index {})\n", self.index);
        }

        if (self.index < 100) {
            self.bone_ids[self.index] = bone_id;
            self.weights[self.index] = weight;
        } else {
            std.debug.print("bone_id: {} exceeds allocated vec for bones_ids", bone_id);
        }

        self.index += 1;
    }

    pub fn get_weight_sum(self: *const Self) f32 {
        var sum: f32 = 0.0;
        for (0..@as(usize, @intCast(self.index))) |i| {
            sum += self.bone_weights[i];
        }
        return sum;
    }
};

const SceneParser = struct {
    vertex_to_bones: ArrayList(VertexBoneData),
    mesh_base_vertex: ArrayList(i32),
    bone_name_to_index_map: StringHashMap(u32),
    bone_count: u32,
    bone_map: StringHashMap(*core.ModelBone),
    space_count: i32,
    allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator) Self {
        return SceneParser{
            .allocator = allocator,
            .vertex_to_bones = ArrayList(VertexBoneData).init(allocator),
            .mesh_base_vertex = ArrayList(i32).init(allocator),
            .bone_name_to_index_map = StringHashMap(u32).init(allocator),
            .bone_count = 0,
            .bone_map = StringHashMap(*core.ModelBone).init(allocator),
            .space_count = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.vertex_to_bones.deinit();
        self.mesh_base_vertex.deinit();
        self.bone_name_to_index_map.deinit();

        var iterator = self.bone_map.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit();
        }
        self.bone_map.deinit();
        //self.allocator.destroy(self.bone_map);
    }

    fn parse_scene(self: *Self, scene: [*]const Assimp.aiScene) !void {
        try self.parse_meshes(scene);
        self.validate_bones();
        self.parse_hierarchy(scene);
        self.parse_animations(scene);
    }

    fn parse_meshes(self: *Self, scene: [*]const Assimp.aiScene) !void {
        std.debug.print("---------------------------------------------", .{});
        std.debug.print("Parsing {} meshes\n\n", .{scene[0].mNumMeshes});

        var total_vertices: c_uint = 0;
        var total_indices: c_uint = 0;
        var total_bones: c_uint = 0;

        for (0..scene[0].mNumMeshes) |i| {
            const mesh: Assimp.aiMesh = scene[0].mMeshes[i].*;

            const mesh_name = mesh.mName.data[0..mesh.mName.length];
            const num_vertices = mesh.mNumVertices;
            const num_indices = mesh.mNumFaces * 3;
            const num_bones = mesh.mNumBones;

            std.debug.print(
                "  Mesh {d} '{s}': num vertices {d} num indices {d} num bones {d}\n",
                .{
                    i,
                    mesh_name,
                    num_vertices,
                    num_indices,
                    num_bones,
                },
            );

            total_vertices += num_vertices;
            total_indices += num_indices;
            total_bones += num_bones;
            // self.vertex_to_bones.push(total_vertices)

            try self.parse_single_mesh(mesh);
        }
    }

    fn parse_single_mesh(self: *Self, aiMesh: Assimp.aiMesh) !void {
        std.debug.print("Vertex positions\n", .{});

        for (0..aiMesh.mNumVertices) |i| {
            const vert = aiMesh.mVertices[i];
            std.debug.print("{d} :  {d} {d} {d}\n", .{ i, vert.x, vert.y, vert.z });
            if (i > 10) {
                std.debug.print("... skipping rest. Total vertices: {d}\n", .{aiMesh.mNumVertices});
                break;
            }
        }

        std.debug.print("\nIndices\n", .{});
        for (0..aiMesh.mNumFaces) |i| {
            const face = aiMesh.mFaces[i];
            std.debug.print("{d} : {any}\n", .{ i, face });
            if (i > 10) {
                std.debug.print("... skipping rest. Total indices: {d}\n", .{aiMesh.mNumFaces});
                break;
            }
        }

        std.debug.print("\nBones number: {d}\n", .{aiMesh.mNumBones});

        try self.parse_mesh_bones(aiMesh);

        std.debug.print("\n", .{});
    }

    fn parse_mesh_bones(self: *Self, aiMesh: Assimp.aiMesh) !void {
        for (0..aiMesh.mNumBones) |i| {
            const bone = aiMesh.mBones[i];
            try self.parse_bone(bone);
        }
    }

    fn parse_bone(self: *Self, bone: *Assimp.aiBone) !void {
        std.debug.print(
            //"Bone '{s}': address: {*} num vertices affected by this bone: {any} {s}\n",
            "Bone '{s:<15.15}': num vertices affected by this bone: {any:5}\n", //      {s}\n      {s}\n",
            .{
                bone.mName.data[0..bone.mName.length],
                // bone,
                bone.mNumWeights,
                // aiMatrixAsString(&buffer2, bone.mOffsetMatrix),
                // transformAsString(&buffer, &bone.mOffsetMatrix),
            },
        );

        var bone_id: u32 = undefined;
        const bone_name = bone.mName.data[0..bone.mName.length];
        const bone_entry = self.bone_map.get(bone_name);
        const offset_transform = Transform.from_matrix(&assimp.mat4FromAiMatrix(&bone.mOffsetMatrix));

        if (bone_entry != null) {
            bone_id = bone_entry.?.bone_index;
            if (!bone_entry.?.offset_transform.equal(offset_transform)) {
                std.debug.print("bone found. Name: {s}  not equal. {any}\n", 
                    .{bone_entry.?.bone_name.str, bone_entry.?.offset_transform.equal(offset_transform)},
                );
            }
        } else {
            const name_str = try core.String.new(bone_name);
            // std.debug.print("bone_name: {s}\n", .{name_str.str});

            const model_bone = try self.allocator.create(ModelBone);
            model_bone.* = ModelBone{
                .bone_name = name_str,
                .bone_index = self.bone_count,
                .offset_transform = offset_transform,
                .allocator = self.allocator,
            };
            std.debug.print("{s}\n", .{model_bone.asString(&buffer)});

            const key = try self.allocator.dupe(u8, bone_name);
            try self.bone_map.put(key, model_bone);
            bone_id = self.bone_count;
            self.bone_count += 1;
        }
        // const bone_id = self.get_bone_id(bone);
        // for (i, weight) in bone.weights.iter().enumerate() {
        //     print!("     {} : vertex id {} ", i, weight.vertex_id);
        //
        //     // const global_vertex_id = self.mesh_base_vertex[i] + weight.vertex_id as i32;
        //
        //     // assert(global_vertex_id < vertex_to_bones.size());
        //     // vertex_to_bones[global_vertex_id].AddBoneData(bone_id, vw.mWeight);
        // }
    }

    fn get_bone_id(self: *Self, bone: *Assimp.aiBone) u32 {
        var bone_id = 0;
        const bone_name = bone.mName.data[0..bone.mName.length];

        if (self.bone_name_to_index_map.get(bone_name)) |id| {
            bone_id = id;
        } else {
            bone_id = self.bone_name_to_index_map.len;
            self.bone_name_to_index_map.insert(bone_name, bone_id);
        }

        return bone_id;
    }

    fn parse_hierarchy(self: *Self, scene: [*]const Assimp.aiScene) void {
        std.debug.print("\n*******************************************************\n", .{});
        std.debug.print("Parsing the node hierarchy\n", .{});
        std.debug.print("\n", .{});
        self.parse_node(scene[0].mRootNode);
    }

    fn parse_node(self: *Self, node: *Assimp.aiNode) void {
        self.print_space();
        std.debug.print(
            "{s:<20.20} - num children: {d} num meshes: {d} transfrom: {s}\n",
            .{
                node.mName.data[0..node.mName.length],
                node.mNumChildren,
                node.mNumMeshes,
                transformAsString(&buffer, &node.mTransformation),
            },
        );

        //std.debug.print("Node name: '{}' num children {} num meshes {} transform: {:?}", node.name, node.children.borrow().len(), node.meshes.len(), &node.transformation);
        // self.print_space();
        // std.debug.print("Node transformation:");
        // self.print_assimp_matrix(&node.transformation);

        self.space_count += 4;

        for (0..node.mNumChildren) |i| {
            // std.debug.print("\n", .{});
            // self.print_space();
            // std.debug.print("--- {} ---\n", i);
            self.parse_node(node.mChildren[i]);
        }

        self.space_count -= 4;
    }

    fn parse_animations(self: *Self, scene: [*]const Assimp.aiScene) void {
        std.debug.print("\n*******************************************************\n", .{});
        std.debug.print("Parsing animations\n", .{});

        for (0..scene[0].mNumAnimations) |i| {
            const animation = scene[0].mAnimations[i];
            self.parse_single_animation(i, animation);
        }
        std.debug.print("\n", .{});
    }

    fn parse_single_animation(self: *Self, animation_id: usize, animation: *Assimp.aiAnimation) void {
        _ = self;
        const animation_name = animation.mName.data[0..animation.mName.length];
        std.debug.print("animation: {d}\nname: {s}\n", .{ animation_id, animation_name });
        std.debug.print("ticks_per_second: {d}\nduration: {d}\n", .{ animation.mTicksPerSecond, animation.mDuration });
        std.debug.print("NodeAdmin channel length: {d}\n", .{animation.mNumChannels});

        for (0..animation.mNumChannels) |i| {
            const channel = animation.mChannels[i].*;
            const node_name = channel.mNodeName.data[0..channel.mNodeName.length];
            std.debug.print(
                "channel id: {d}  name: {s}  position keys: {d}  rotation keys: {d}, scaling keys: {d}\n",
                .{
                    i,
                    node_name,
                    channel.mNumPositionKeys,
                    channel.mNumRotationKeys,
                    channel.mNumScalingKeys,
                },
            );

            // if (std.mem.eql(u8, node_name, "Character1_Reference")) {
            //     self.space_count = 4;
            //     std.debug.print("postion keys\n", .{});
            //     for (0..channel.mNumPositionKeys) |ci| {
            //         const m = channel.mPositionKeys[ci];
            //         self.print_aiVectorKey(m);
            //     }
            //     std.debug.print("rotation keys\n", .{});
            //     for (0..channel.mNumPositionKeys) |ci| {
            //         const m = channel.mRotationKeys[ci];
            //         self.print_aiQuatKey(m);
            //     }
            std.debug.print("scaling keys\n", .{});
            for (0..channel.mNumScalingKeys) |ci| {
                const m = channel.mScalingKeys[ci];
                std.debug.print("scaling id: {d}  {s}\n", .{ci, aiVectorAsString(&buffer, m)});
            }
            // }
        }
        std.debug.print("\n", .{});
    }

    fn validate_bones(self: *const Self) void {
        std.debug.print("Validating bones\n", .{});
        for (0..self.vertex_to_bones.items.len) |i| {
            std.debug.print("{d}: {d}\n", .{ i, self.vertex_to_bones.items[i].get_weight_sum() });
        }
    }

    fn print_space(self: *const Self) void {
        for (0..@as(usize, @intCast(self.space_count))) |_| {
            std.debug.print(" ", .{});
        }
    }

    fn _print_assimp_matrix(self: *const Self, m: Assimp.aiMatrix4x4) void {
        self.print_space();
        std.debug.print("{d}, {d}, {d}, {d}\n", .{ m.a1, m.a2, m.a3, m.a4 });
        self.print_space();
        std.debug.print("{d}, {d}, {d}, {d}\n", .{ m.b1, m.b2, m.b3, m.b4 });
        self.print_space();
        std.debug.print("{d}, {d}, {d}, {d}\n", .{ m.c1, m.c2, m.c3, m.c4 });
        self.print_space();
        std.debug.print("{d}, {d}, {d}, {d}\n", .{ m.d1, m.d2, m.d3, m.d4 });
    }
};

fn aiMatrixAsString(buf: []u8, m: Assimp.aiMatrix4x4) [:0]u8 {
    return std.fmt.bufPrintZ(
        buf,
        "aiMatrix: {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}, {d}",
        .{ m.a1, m.a2, m.a3, m.a4, m.b1, m.b2, m.b3, m.b4, m.c1, m.c2, m.c3, m.c4, m.d1, m.d2, m.d3, m.d4 },
    ) catch @panic("bufPrintZ error.");
}

fn aiVectorAsString(buf: []u8, v: Assimp.aiVectorKey) [:0]u8 {
    return std.fmt.bufPrintZ(
        buf,
        "aiVectorKey: time: {d}  value: {d}, {d}, {d}",
        .{ v.mTime, v.mValue.x, v.mValue.y, v.mValue.z },
    ) catch @panic("bufPrintZ error.");
}

fn aiQuatKeyAsString(buf: []u8, v: Assimp.aiQuatKey) [:0]u8 {
    return std.fmt.bufPrintZ(
        buf,
        "aiQuatKey: time: {d}  value: {d}, {d}, {d}, {d}",
        .{ v.mTime, v.mValue.x, v.mValue.y, v.mValue.z, v.mValue.w },
    ) catch @panic("bufPrintZ error.");
}

fn transformAsString(buf: []u8, matrix: *Assimp.aiMatrix4x4) [:0]u8 {
    const transform = Transform.from_matrix(&core.assimp.mat4FromAiMatrix(matrix));
    return transform.asString(buf);
}
