const std = @import("std");
const core = @import("core");
const gl = @import("zopengl").bindings;
const Texture = core.texture.Texture;
const Shader = core.Shader;
const utils = core.utils;
const math = @import("math");

const Gltf = @import("zgltf/src/main.zig");
const gltf_utils = @import("utils.zig");
// const Material = @import("material.zig").Material;

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

    pub fn init(allocator: Allocator, gltf: *Gltf, gltf_mesh: Gltf.Mesh) !*Mesh {
        const mesh = try allocator.create(Mesh);

        mesh.* = Mesh {
            .allocator = allocator,
            .name = gltf_mesh.name,
            .primitives = ArrayList(*MeshPrimitive).init(allocator),
        };

        for (gltf_mesh.primitives.items, 0..) |primitive, id| {

            const mesh_primitive = try MeshPrimitive.init(allocator, gltf, primitive, id);
            try mesh.primitives.append(mesh_primitive);
        }

        return mesh;
    }

    pub fn render(self: *Self, shader: *const Shader) void {
        for (self.primitives.items) |primitive| {
            primitive.render(shader);
        }
    }
};


pub const MeshPrimitive = struct {
    allocator: Allocator,
    id: usize,
    name: []const u8 = undefined,
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
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, gltf: *Gltf, primitive: Gltf.Primitive, id: usize) !*MeshPrimitive {

        const mesh_primitive = try allocator.create(MeshPrimitive);
        mesh_primitive.* = MeshPrimitive {
            .allocator = allocator,
            .id = id,
            .indices_count = 0,
        };

        gl.genVertexArrays(1, &mesh_primitive.vao);
        gl.bindVertexArray(mesh_primitive.vao);

        for (primitive.attributes.items) |attribute| {
            switch (attribute) {
                .position => |accessor_id| {
                    // const positions = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vbo_positions = createGlArrayBuffer(gltf, 0, accessor_id);
                    std.debug.print("has_positions\n", .{});
                },
                .normal => |accessor_id| {
                    // const normals = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vbo_normals = createGlArrayBuffer(gltf, 1, accessor_id);
                    std.debug.print("has_normals\n", .{});
                },
                .texcoord => |accessor_id| {
                    // const texcoord = getBufferSlice(Vec2, gltf, accessor_id);
                    mesh_primitive.vbo_texcoords = createGlArrayBuffer(gltf, 2, accessor_id);
                    std.debug.print("has_texcoords\n", .{});
                },
                .tangent => |accessor_id| {
                    // const tangents = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vbo_tangents = createGlArrayBuffer(gltf, 3, accessor_id);
                    std.debug.print("has_tangents\n", .{});
                },
                .color => |accessor_id| {
                    // const colors = getBufferSlice(Vec4, gltf, accessor_id);
                    mesh_primitive.vbo_colors = createGlArrayBuffer(gltf, 4, accessor_id);
                    std.debug.print("has_colors\n", .{});
                },
                .joints => |accessor_id| {
                    // const joints = getBufferSlice([4]u16, gltf, accessor_id);
                    mesh_primitive.vbo_joints = createGlArrayBuffer(gltf, 5, accessor_id);
                    std.debug.print("has_joints\n", .{});
                },
                .weights => |accessor_id| {
                    // const weights = getBufferSlice([4]f32, gltf, accessor_id);
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
            mesh_primitive.material = gltf.data.materials.items[accessor_id];
            std.debug.print("has_material: {any}\n", .{mesh_primitive.material});
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
    //


    pub fn render(self: *MeshPrimitive, shader: *const Shader) void {
        // const has_texture = self.*.textures.items.len > 0;
        // shader.set_bool("has_texture", has_texture);
        //
        // for (self.*.textures.items, 0..) |texture, i| {
        //     const texture_unit: u32 = @intCast(i);
        //
        //     gl.activeTexture(gl.TEXTURE0 + texture_unit);
        //     gl.bindTexture(gl.TEXTURE_2D, texture.id);
        //
        //     const uniform = texture.texture_type.toString();
        //     shader.set_int(uniform, @as(i32, @intCast(texture_unit)));
        //     // std.debug.print("has_texture: {any} texture id: {d}  name: {s}\n", .{has_texture, i, texture.texture_path});
        // }


        shader.set_bool("has_color", true);
        shader.set_vec4("diffuse_color", &Vec4.fromArray(self.material.pbr_metallic_roughness.base_color_factor));

        shader.set_bool("has_texture", false);

        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            @intCast(self.indices_count),
            gl.UNSIGNED_SHORT,
            null,
        );
        gl.bindVertexArray(0);

        shader.set_bool("has_color", false);
    }
};

pub fn createGlArrayBuffer(gltf: *Gltf, index: u32, accessor_id: usize) c_uint {
    const accessor = gltf.data.accessors.items[accessor_id];
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const buffer_data = gltf.buffer_data.items[buffer_view.buffer];

    const data_size = accessor.getComponentSize() * accessor.getTypeSize() * accessor.count;

    std.debug.print("\naccessor:  {any}\n\n", .{accessor});
    std.debug.print("buffer_view:  {any}\n\n", .{buffer_view});
    std.debug.print("buffer len:  {any}\n\n", .{buffer_data.len});
    std.debug.print("data size:  {any}\n\n", .{data_size});

    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + data_size;
    const data = buffer_data[start..end];

    var vbo: gl.Uint = undefined;
    gl.genBuffers(1, &vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(data.len),
        data.ptr,
        gl.STATIC_DRAW,
    );
    gl.enableVertexAttribArray(index);
    gl.vertexAttribPointer(
        index,
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
    const buffer = gltf.buffer_data.items[buffer_view.buffer];

    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + buffer_view.byte_length;
    const data = buffer[start..end];

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

