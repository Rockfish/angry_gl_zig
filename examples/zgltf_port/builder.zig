const std = @import("std");
const gl = @import("zopengl").bindings;
const panic = @import("std").debug.panic;
const core = @import("core");
const math = @import("math");

const Gltf = @import("zgltf/src/main.zig");
const Model = @import("model.zig").Model;
const MeshPrimitive = @import("mesh.zig").MeshPrimitive;
const PrimitiveVertex = @import("mesh.zig").PrimitiveVertex;
const Material = @import("material.zig").Material;
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
const Transform = core.Transform;
const String = core.String;
const utils = core.utils;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

pub const GltfBuilder = struct {
    name: []const u8,
    meshes: *ArrayList(*MeshPrimitive),
    texture_cache: *ArrayList(*Texture),
    added_textures: ArrayList(AddedTexture),
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
        const meshes = try allocator.create(ArrayList(*MeshPrimitive));
        meshes.* = ArrayList(*MeshPrimitive).init(allocator);

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

        try self.loadMeshes(&gltf);

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

    // Gltf meshes are collections of primitives. Each primitive is a collection of vertices. 
    pub fn loadMeshes(self: *Self, gltf: *Gltf) !void {
        for (gltf.data.meshes.items) |mesh| {
            const mesh_name = try self.allocator.dupe(u8, mesh.name);

            // A primitive is the same as assimp.mesh
            // primitives are a struct of arrays
            for (mesh.primitives.items) |primitive| {

                const vertices = try self.allocator.create(ArrayList(PrimitiveVertex));
                vertices.* = ArrayList(PrimitiveVertex).init(self.allocator);
                const indices = try self.allocator.create(ArrayList(u32));
                indices.* = ArrayList(u32).init(self.allocator);

                var positions: ?Gltf.Accessor = null;
                var normals: ?Gltf.Accessor = null;
                var texcoords: ?Gltf.Accessor = null;
                var tangents: ?Gltf.Accessor = null;
                var colors: ?Gltf.Accessor = null;
                var joints: ?Gltf.Accessor = null;
                var weights: ?Gltf.Accessor = null;

                for (primitive.attributes.items) |attribute| {
                    switch (attribute) {
                        .position => |accessor_id| {
                            positions = gltf.data.accessors.items[accessor_id];
                        },
                        .normal => |accessor_id| {
                            normals = gltf.data.accessors.items[accessor_id];
                        },
                        .texcoord => |accessor_id| {
                            texcoords = gltf.data.accessors.items[accessor_id];
                        },
                        .tangent => |accessor_id| {
                            tangents = gltf.data.accessors.items[accessor_id];
                        },
                        .color => |accessor_id| {
                            colors = gltf.data.accessors.items[accessor_id];
                        },
                        .joints => |accessor_id| {
                            joints = gltf.data.accessors.items[accessor_id];
                        },
                        .weights => |accessor_id| {
                            weights = gltf.data.accessors.items[accessor_id];
                        },
                    }
                }

                if (positions) |accessor| {
                    std.debug.print("position accessor: {any}\n", .{accessor});
                    if (accessor.buffer_view) |buffer_view_id| {
                        const buffer_view = gltf.data.buffer_views.items[buffer_view_id];
                        std.debug.print("position buffer_view: {any}\n", .{buffer_view});

                        const buffer = gltf.data.buffers.items[buffer_view.buffer];
                        std.debug.print("position buffer: {any}\n", .{buffer});
                        if (buffer.uri) |uri| {
                            std.debug.print("position buffer uri: {s}\n", .{uri});
                            const directory = Path.dirname(self.filepath);
                            const path = try std.fs.path.join(self.allocator, &[_][]const u8{ directory.?, uri });
                            defer self.allocator.free(path);
                            std.debug.print("position buffer file path: {s}\n", .{path});
                            const glb_buf = try std.fs.cwd().readFileAllocOptions(
                                self.allocator, path, 512_000, null, 4, null);
                            defer self.allocator.free(glb_buf);
                            std.debug.print("glf_buf length: {d}\n", .{glb_buf.len});
                            var iter = accessor.iterator(f32, gltf, glb_buf);
                            const first = iter.next();
                            std.debug.print("first: {any}\n", .{first});

                        }
                    }
                    std.debug.print("\n", .{});
                }
                if (normals) |accessor| {
                    std.debug.print("normals accessor: {any}\n", .{accessor});
                }
                if (texcoords) |accessor| {
                    std.debug.print("texcoords accessor: {any}\n", .{accessor});
                }
                if (tangents) |accessor| {
                    std.debug.print("tangents accessor: {any}\n", .{accessor});
                }
                if (colors) |accessor| {
                    std.debug.print("colors accessor: {any}\n", .{accessor});
                }
                if (joints) |accessor| {
                    std.debug.print("joints accessor: {any}\n", .{accessor});
                }
                if (weights) |accessor| {
                    std.debug.print("weights accessor: {any}\n", .{accessor});
                }

                // if (positions) |accessor| {
                //     for (0..accessor.count) |i| {
                //         const vertex = PrimitiveVertex{
                //             .position = if (positions) |pos| pos[i] else [3]f32{0, 0, 0},
                //             .normal = if (normals) |norm| norm[i] else [3]f32{0, 0, 1},
                //             .uv = if (texcoords) |uv| uv[i] else [2]f32{0, 0},
                //             .tangent = if (tangents) |tan| tan[i] else [4]f32{1, 0, 0, 1},
                //             //.bitangent = if (tangents and normals) cross(normal, tangent.xyz) * tangent.w else [3]f32{0, 1, 0},
                //             .bitangent = [3]f32{0, 1, 0},
                //         };
                //         try vertices.append(vertex);
                //     }
                // }

                const material = Material {
                    .name = "material",
                };

                const model_primitive = try self.allocator.create(MeshPrimitive);
                model_primitive.* = MeshPrimitive{
                    .allocator = self.allocator,
                    .id = 0, // needed?
                    .name = mesh_name,
                    .vertices = vertices,
                    .indices = indices,
                    .material = material,
                    .vao = 0,
                    .vbo = 0,
                    .ebo = 0,
                };
                try self.meshes.append(model_primitive);

            } 



        // var vertices = std.ArrayList(Vertex).init(allocator);
        // for (0..numVertices) |i| {
        //     var vertex = Vertex{
        //         .position = if (positions) |pos| pos[i] else [3]f32{0, 0, 0},
        //         .normal = if (normals) |norm| norm[i] else [3]f32{0, 0, 1},
        //         .uv = if (uvs) |uv| uv[i] else [2]f32{0, 0},
        //         .tangent = if (tangents) |tan| tan[i] else [4]f32{1, 0, 0, 1},
        //         .bitangent = if (tangents and normals) cross(normal, tangent.xyz) * tangent.w else [3]f32{0, 1, 0},
        //     };
        //     try vertices.append(vertex);
        // }



        }

    }
};
