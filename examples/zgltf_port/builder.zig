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

    // TODO: the transform of the skinned mesh node MUST be ignored

    pub fn build(self: *Self) !*Model {

        // TODO: check file extension for glb or gltf

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

        try self.loadBufferData(&gltf);
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

    // Uri patterns found in the Khonos examples.
    // data:application/gltf-buffer;base64
    // data:application/octet-stream;base64
    // data:image/jpeg;base64
    // data:image/png;base64

    pub fn loadBufferData(self: *Self, gltf: *Gltf) !void {
        const alloc = gltf.arena.allocator();
        for (gltf.data.buffers.items, 0..) |buffer, i| {
            if (buffer.uri) |uri| {
                if (std.mem.eql(u8, "data:", uri)) {
                    const comma = strchr(uri, ',');
                    if (comma) |idx| {
                        // "uri" : "data:application/octet-stream;base64,
                        std.debug.print("uri: {s}\n", .{uri[0..idx]});
                        const decoder = std.base64.standard.Decoder;
                        const decoded_length = try decoder.calcSizeForSlice(uri[idx..uri.len]);
                        const decoded_buffer:[]align(4) u8 = try alloc.allocWithOptions(u8, decoded_length, 4, null);
                        try decoder.decode(decoded_buffer, uri[idx..uri.len]);
                        try gltf.buffer_data.append(decoded_buffer);
                    }
                } else if (!std.mem.eql(u8, "://", uri)) {
                    const directory = Path.dirname(self.filepath);
                    const path = try std.fs.path.join(self.allocator, &[_][]const u8{ directory.?, uri });
                    defer self.allocator.free(path);

                    std.debug.print("position buffer file path: {s}\n", .{path});

                    const glb_buf = try std.fs.cwd().readFileAllocOptions(
                        alloc,
                        path,
                        512_000,
                        null,
                        4,
                        null,
                    );

                    std.debug.print("buffer: {d} length: {d}\n", .{ i, glb_buf.len });
                    try gltf.buffer_data.append(glb_buf);
                } else {
                    std.debug.panic("Unknown buffer type.", .{});
                }
            }
        }
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
                // const indices = try self.allocator.create(ArrayList(u32));
                // indices.* = ArrayList(u32).init(self.allocator);

                var positions: ?[]Vec3 = null;
                var normals: ?[]Vec3 = null;
                var texcoords: ?[]Vec2= null;
                var tangents: ?[]Vec3 = null;
                var colors: ?[]Vec4 = null;
                var joints: ?[][4]u16 = null;
                var weights: ?[][4]f32 = null;
                var indices: ?[]u32 = null;

                for (primitive.attributes.items) |attribute| {
                    switch (attribute) {
                        .position => |accessor_id| {
                            positions = getBufferSlice(Vec3, gltf, accessor_id);
                        },
                        .normal => |accessor_id| {
                            normals = getBufferSlice(Vec3, gltf, accessor_id);
                        },
                        .texcoord => |accessor_id| {
                            texcoords = getBufferSlice(Vec2, gltf, accessor_id);
                        },
                        .tangent => |accessor_id| {
                            tangents = getBufferSlice(Vec3, gltf, accessor_id);
                        },
                        .color => |accessor_id| {
                            colors = getBufferSlice(Vec4, gltf, accessor_id);
                        },
                        .joints => |accessor_id| {
                            joints = getBufferSlice([4]u16, gltf, accessor_id);
                        },
                        .weights => |accessor_id| {
                            weights = getBufferSlice([4]f32, gltf, accessor_id);
                        },
                    }
                }

                if (positions != null) {
                    for (0..positions.?.len) |i| {
                        const vertex = PrimitiveVertex{
                            .position = if (positions) |pos| pos[i] else Vec3.fromArray([3]f32{0, 0, 0}),
                            .normal = if (normals) |norm| norm[i] else Vec3.fromArray([3]f32{0, 0, 1}),
                            .uv = if (texcoords) |uv| uv[i] else Vec2.fromArray([2]f32{0, 0}),
                            .tangent = if (tangents) |tan| tan[i] else Vec3.fromArray([3]f32{1, 0, 0}),
                            //.bitangent = if (tangents and normals) cross(normal, tangent.xyz) * tangent.w else [3]f32{0, 1, 0},
                            .bi_tangent = Vec3.fromArray([3]f32{0, 1, 0}),
                            .bone_ids = if (joints) |j| j[i] else [4]u16{0, 0, 0, 0},
                            .bone_weights = if (weights) |w| w[i] else [4]f32{0, 0, 0, 0},
                        };
                        try vertices.append(vertex);
                    }
                }

                if (primitive.indices) |accessor_id| {
                    indices = getBufferSlice(u32, gltf, accessor_id);
                }

                const material = Material{
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

                model_primitive.printMeshVertices();

                try self.meshes.append(model_primitive);
            }
        }
    }
};

fn getBufferSlice(comptime T: type, gltf: *Gltf, accessor_id: usize) []T {
    const accessor = gltf.data.accessors.items[accessor_id];
    if (@sizeOf(T) != accessor.stride) {
        std.debug.panic("sizeOf(T) : {d} does not equal accessor.stride: {d}", .{@sizeOf(T), accessor.stride});
    }
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const glb_buf = gltf.buffer_data.items[buffer_view.buffer];
    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + buffer_view.byte_length;
    const slice = glb_buf[start..end];
    const data = @as([*]T, @ptrCast(@alignCast(@constCast(slice))))[0..accessor.count];
    return data;
}

fn strchr(str: []const u8, c: u8) ?usize {
    for (str, 0..) |char, i| {
        if (char == c) {
            return i;
        }
    }
    return null;
}
