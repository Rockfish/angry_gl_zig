const std = @import("std");
const core = @import("core");
const gl = @import("zopengl").bindings;
const Texture = @import("texture.zig").Texture;
const Shader = @import("shader.zig").Shader;
const utils = core.utils;
const math = @import("math");

const Gltf = @import("zgltf/src/main.zig");
const gltf_utils = @import("utils.zig");

const getBufferSlice = gltf_utils.getBufferSlice;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;

pub const Mesh = struct {
    allocator: Allocator,
    name: []const u8,
    primitives: ArrayList(*MeshPrimitive),

    const Self = @This();

    pub fn deinit(self: *Self) void {
        for (self.primitives.items) |primitive| {
            primitive.deinit();
        }
        self.primitives.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, gltf: *Gltf, directory: []const u8, gltf_mesh: Gltf.Mesh) !*Mesh {
        const mesh = try allocator.create(Mesh);

        mesh.* = Mesh{
            .allocator = allocator,
            .name = gltf_mesh.name,
            .primitives = ArrayList(*MeshPrimitive).init(allocator),
        };

        for (gltf_mesh.primitives.items, 0..) |primitive, id| {
            const mesh_primitive = try MeshPrimitive.init(allocator, gltf, directory, primitive, id);
            try mesh.primitives.append(mesh_primitive);
        }

        return mesh;
    }

    pub fn render(self: *Self, gltf: *Gltf, shader: *const Shader) void {
        for (self.primitives.items) |primitive| {
            primitive.renderPBR(gltf, shader);
        }
    }
};

pub const MeshPrimitive = struct {
    allocator: Allocator,
    id: usize,
    name: ?[]const u8 = null,
    material: Gltf.Material = undefined,
    indices_count: u32,
    vao: c_uint = undefined,
    vbo_positions: c_uint = undefined,
    vbo_normals: c_uint = undefined,
    vbo_texcoords: c_uint = undefined,
    vbo_tangents: c_uint = undefined,
    vbo_colors: c_uint = undefined,
    vbo_joints: c_uint = undefined,
    vbo_weights: c_uint = undefined,
    ebo_indices: c_uint = undefined,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        // depending on who owns the name.
        // if (self.name) |name| {
        //     self.allocator.free(name);
        // }
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, gltf: *Gltf, directory: []const u8, primitive: Gltf.Primitive, id: usize) !*MeshPrimitive {
        const mesh_primitive = try allocator.create(MeshPrimitive);
        mesh_primitive.* = MeshPrimitive{
            .allocator = allocator,
            .id = id,
            .indices_count = 0,
        };

        gl.genVertexArrays(1, &mesh_primitive.vao);
        gl.bindVertexArray(mesh_primitive.vao);

        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_id| {
                    mesh_primitive.vbo_positions = createGlArrayBuffer(gltf, 0, accessor_id);
                    std.debug.print("has_positions\n", .{});
                    const aabb = getAABB(gltf, accessor_id);
                    std.debug.print("aabb: {any}\n", .{aabb});
                },
                .normal => |accessor_id| {
                    mesh_primitive.vbo_normals = createGlArrayBuffer(gltf, 1, accessor_id);
                    std.debug.print("has_normals\n", .{});
                },
                .texcoord => |accessor_id| {
                    mesh_primitive.vbo_texcoords = createGlArrayBuffer(gltf, 2, accessor_id);
                    std.debug.print("has_texcoords\n", .{});
                },
                .tangent => |accessor_id| {
                    mesh_primitive.vbo_tangents = createGlArrayBuffer(gltf, 3, accessor_id);
                    std.debug.print("has_tangents\n", .{});
                },
                .color => |accessor_id| {
                    mesh_primitive.vbo_colors = createGlArrayBuffer(gltf, 4, accessor_id);
                    std.debug.print("has_colors\n", .{});
                },
                .joints => |accessor_id| {
                    mesh_primitive.vbo_joints = createGlArrayBuffer(gltf, 5, accessor_id);
                    std.debug.print("has_joints\n", .{});
                },
                .weights => |accessor_id| {
                    mesh_primitive.vbo_weights = createGlArrayBuffer(gltf, 6, accessor_id);
                    std.debug.print("has_weights\n", .{});
                },
            }
        }

        if (primitive.indices) |accessor_id| {
            mesh_primitive.ebo_indices = createGlElementBuffer(gltf, accessor_id);
            const accessor = gltf.data.accessors.items[accessor_id];
            mesh_primitive.indices_count = @intCast(accessor.count);
            std.debug.print("has_indices count: {d}\n", .{accessor.count});
        }

        if (primitive.material) |accessor_id| {
            const material = gltf.data.materials.items[accessor_id];
            mesh_primitive.material = material;
            std.debug.print("has_material: {any}\n", .{material});

            if (material.pbr_metallic_roughness.base_color_texture) |base_color_texture| {
                loadMaterialTexture(allocator, directory, gltf, base_color_texture.index);
            }
            if (material.pbr_metallic_roughness.metallic_roughness_texture) |metallic_roughness_texture| {
                loadMaterialTexture(allocator, directory, gltf, metallic_roughness_texture.index);
            }
            if (material.normal_texture) |normal_texture| {
                loadMaterialTexture(allocator, directory, gltf, normal_texture.index);
            }
            if (material.emissive_texture) |emissive_texture| {
                loadMaterialTexture(allocator, directory, gltf, emissive_texture.index);
            }
            if (material.occlusion_texture) |occlusion_texture| {
                loadMaterialTexture(allocator, directory, gltf, occlusion_texture.index);
            }
        }

        return mesh_primitive;
    }

    // Gltf Material to Assimp Mapping
    //
    // material.metallic_roughness.base_color_factor  : diffuse_color
    // material.metallic_roughness.base_color_factor  : base_color
    // material.pbrMetallicRoughness.baseColorTexture : aiTextureType_DIFFUSE
    // material.pbrMetallicRoughness.baseColorTexture :  aiTextureType_BASE_COLOR
    // mat.pbrMetallicRoughness.metallicRoughnessTexture : AI_MATKEY_GLTF_PBRMETALLICROUGHNESS_METALLICROUGHNESS_TEXTURE
    // mat.pbrMetallicRoughness.metallicRoughnessTexture : aiTextureType_METALNESS
    // mat.pbrMetallicRoughness.metallicRoughnessTexture : aiTextureType_DIFFUSE_ROUGHNESS

    pub fn render(self: *MeshPrimitive, gltf: *Gltf, shader: *const Shader) void {
        if (self.material.pbr_metallic_roughness.base_color_texture) |baseColorTexture| {
            const texUnit: u32 = 0;
            const texture = gltf.loaded_textures.get(baseColorTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            gl.activeTexture(gl.TEXTURE0 + @as(c_uint, @intCast(texUnit)));
            gl.bindTexture(gl.TEXTURE_2D, texture.gl_texture_id);
            shader.set_int("texture_diffuse", texUnit);
            shader.setBool("has_texture", true);
        } else {
            const color = self.material.pbr_metallic_roughness.base_color_factor;
            shader.set4Float("diffuse_color", &color);
            shader.setBool("has_color", true);
        }

        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            @intCast(self.indices_count),
            gl.UNSIGNED_SHORT,
            null,
        );
        gl.bindVertexArray(0);

        shader.setBool("has_color", false);
    }

    pub fn renderPBR(self: *MeshPrimitive, gltf: *Gltf, shader: *const Shader) void {

        // Base Color
        shader.set4Float("material.baseColorFactor", &self.material.pbr_metallic_roughness.base_color_factor);
        shader.setFloat("material.metallicFactor", self.material.pbr_metallic_roughness.metallic_factor);
        shader.setFloat("material.roughnessFactor", self.material.pbr_metallic_roughness.roughness_factor);
        shader.set3Float("material.emissiveFactor", &self.material.emissive_factor);

        if (self.material.pbr_metallic_roughness.base_color_texture) |baseColorTexture| {
            const texture = gltf.loaded_textures.get(baseColorTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            shader.bindTexture(0, "baseColorTexture", texture);
            shader.setBool("has_baseColorTexture", true);
        } else {
            shader.setBool("has_baseColorTexture", false);
        }

        if (self.material.pbr_metallic_roughness.metallic_roughness_texture) |metallicRoughnessTexture| {
            const texture = gltf.loaded_textures.get(metallicRoughnessTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            shader.bindTexture(1, "metallicRoughnessTexture", texture);
            shader.setBool("has_metallicRoughnessTexture", true);
        } else {
            shader.setBool("has_metallicRoughnessTexture", false);
        }

        if (self.material.normal_texture) |normalTexture| {
            const texture = gltf.loaded_textures.get(normalTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            shader.bindTexture(2, "normalTexture", texture);
            shader.setBool("has_normalTexture", true);
        } else {
            shader.setBool("has_normalTexture", false);
        }

        if (self.material.emissive_texture) |emissiveTexture| {
            const texture = gltf.loaded_textures.get(emissiveTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            shader.bindTexture(3, "emissiveTexture", texture);
            shader.setBool("has_emissiveTexture", true);
        } else {
            shader.setBool("has_emissiveTexture", false);
        }

        if (self.material.occlusion_texture) |occlusionTexture| {
            const texture = gltf.loaded_textures.get(occlusionTexture.index) orelse std.debug.panic("texture not loaded.", .{});
            shader.setBool("has_occlusionTexture", true);
            shader.bindTexture(4, "occlusionTexture", texture);
        } else {
            shader.setBool("has_occlusionTexture", false);
        }

        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            @intCast(self.indices_count),
            gl.UNSIGNED_SHORT,
            null,
        );
        gl.bindVertexArray(0);
    }
};

fn loadMaterialTexture(allocator: Allocator, directory: []const u8, gltf: *Gltf, texture_index: usize) void {
    if (!gltf.loaded_textures.contains(texture_index)) {
        const texture = Texture.init(
            allocator,
            gltf,
            directory,
            texture_index,
        ) catch |err| {
            std.debug.panic("Error loading texture index: {d} error: {any}", .{ texture_index, err });
        };
        gltf.loaded_textures.put(texture_index, texture) catch |err| {
            std.debug.panic("Error storing texture index: {d} error: {any}", .{ texture_index, err });
        };
    }
}

pub fn getAABB(gltf: *Gltf, accessor_id: usize) core.AABB {
    const accessor = gltf.data.accessors.items[accessor_id];
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const buffer_data = gltf.buffer_data.items[buffer_view.buffer];

    const data_size = accessor.getComponentSize() * accessor.getTypeSize() * accessor.count;
    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + data_size;

    const data = buffer_data[start..end];
    const len: usize = data.len/@sizeOf(Vec3);
    std.debug.assert(len == accessor.count);
    std.debug.print("aabb number of positions: {d}\n", .{len});

    const positions = @as([*]Vec3, @ptrCast(@alignCast(@constCast(data))))[0..len];

    var aabb = core.AABB.init();
    for (positions) |position| {
        aabb.expand_to_include(position);
    }

    return aabb;
}

pub fn createGlArrayBuffer(gltf: *Gltf, gl_index: u32, accessor_id: usize) c_uint {
    const accessor = gltf.data.accessors.items[accessor_id];
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const buffer_data = gltf.buffer_data.items[buffer_view.buffer];

    const element_size = accessor.getComponentSize() * accessor.getTypeSize();
    const data_size = element_size * accessor.count;

    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + data_size;

    std.debug.print("\naccessor:  {any}\n", .{accessor});
    std.debug.print("buffer_view:  {any}\n", .{buffer_view});
    std.debug.print("buffer len:  {d}\n", .{buffer_data.len});
    std.debug.print("data size:  {d}\n", .{data_size});
    std.debug.print("start:  {d}\n", .{start});
    std.debug.print("end:  {d}\n", .{end});
    std.debug.print("element_size: {d}  byte_stride: {d}  type size: {d}\n", .{element_size, buffer_view.byte_stride, accessor.getTypeSize()});

    const data = buffer_data[start..end];

    // Note: this will break if the data is interleved with other data. 
    std.debug.assert(buffer_view.byte_stride == 0);

    var vbo: gl.Uint = undefined;
    gl.genBuffers(1, &vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(data.len),
        data.ptr,
        gl.STATIC_DRAW,
    );
    gl.enableVertexAttribArray(gl_index);
    gl.vertexAttribPointer(
        gl_index,
        @intCast(accessor.getTypeSize()),
        gl.FLOAT,
        gl.FALSE,
        @intCast(buffer_view.byte_stride),
        @ptrFromInt(0),
    );
    return vbo;
}

pub fn createGlElementBuffer(gltf: *Gltf, accessor_id: usize) c_uint {
    const accessor = gltf.data.accessors.items[accessor_id];
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const buffer_data = gltf.buffer_data.items[buffer_view.buffer];

    const data_size = accessor.getComponentSize() * accessor.getTypeSize() * accessor.count;

    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + data_size; // buffer_view.byte_length;

    std.debug.print("\naccessor:  {any}\n", .{accessor});
    std.debug.print("buffer_view:  {any}\n", .{buffer_view});
    std.debug.print("buffer len:  {d}\n", .{buffer_data.len});
    std.debug.print("data size:  {d}\n", .{data_size});
    std.debug.print("start:  {d}\n", .{start});
    std.debug.print("end:  {d}\n", .{end});

    const data = buffer_data[start..end];

    var ebo: gl.Uint = undefined;
    gl.genBuffers(1, &ebo);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @intCast(data.len),
        data.ptr,
        gl.STATIC_DRAW,
    );
    return ebo;
}
