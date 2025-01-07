const std = @import("std");
const core = @import("core");
const gl = @import("zopengl").bindings;
const Texture = core.texture.Texture;
const Shader = core.Shader;
const utils = core.utils;
const math = @import("math");

const Gltf = @import("zgltf/src/main.zig");
const gltf_utils = @import("utils.zig");
const Material = @import("material.zig").Material;

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
    material: Material = undefined,
    indices_count: u32,
    vao: c_uint = undefined,
    vboPositions: c_uint = undefined,
    vboNormals: c_uint = undefined,
    vboTexcoords: c_uint = undefined,
    vboTangents: c_uint = undefined,
    vboColors: c_uint = undefined,
    vboJoints: c_uint = undefined,
    vboWeights: c_uint = undefined,
    eboIndices: c_uint = undefined,

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
                    const positions = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vboPositions = createGlArrayBuffer(0, Vec3, positions);
                    std.debug.print("has_positions\n", .{});
                },
                .normal => |accessor_id| {
                    const normals = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vboNormals = createGlArrayBuffer(1, Vec3, normals);
                    std.debug.print("has_normals\n", .{});
                },
                .texcoord => |accessor_id| {
                    const texcoord = getBufferSlice(Vec2, gltf, accessor_id);
                    mesh_primitive.vboTexcoords = createGlArrayBuffer(2, Vec2, texcoord);
                    std.debug.print("has_texcoords\n", .{});
                },
                .tangent => |accessor_id| {
                    const tangents = getBufferSlice(Vec3, gltf, accessor_id);
                    mesh_primitive.vboTangents = createGlArrayBuffer(3, Vec3, tangents);
                    std.debug.print("has_tangents\n", .{});
                },
                .color => |accessor_id| {
                    const colors = getBufferSlice(Vec4, gltf, accessor_id);
                    mesh_primitive.vboColors = createGlArrayBuffer(4, Vec4, colors);
                    std.debug.print("has_colors\n", .{});
                },
                .joints => |accessor_id| {
                    const joints = getBufferSlice([4]u16, gltf, accessor_id);
                    mesh_primitive.vboJoints = createGlArrayBuffer(5, [4]u16, joints);
                    std.debug.print("has_joints\n", .{});
                },
                .weights => |accessor_id| {
                    const weights = getBufferSlice([4]f32, gltf, accessor_id);
                    mesh_primitive.vboWeights = createGlArrayBuffer(6, [4]f32, weights);
                    std.debug.print("has_weights\n", .{});
                },
            }
        }

        if (primitive.indices) |accessor_id| {
            const indices = getBufferSlice(u16, gltf, accessor_id);
            mesh_primitive.eboIndices = createGlElementBuffer(u16, indices);
            const accessor = gltf.data.accessors.items[accessor_id];
            mesh_primitive.indices_count = @intCast(accessor.count);
            std.debug.print("has_indices count: {d}\n", .{accessor.count});
        }

        if (primitive.material) |accessor_id| {
            const material = gltf.data.materials.items[accessor_id];
            std.debug.print("has_material: {any}\n", .{material});
        }

        return mesh_primitive;
    }

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

        // TODO: temp color
        shader.set_bool("has_texture", false);
        shader.set_bool("has_color", true);
        shader.set_vec4("diffuse_color", &Vec4.fromArray(.{0.8, 0.2, 0.2, 1.0}));

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

pub fn createGlArrayBuffer(index: u32, comptime T: type, data: []T) c_uint {
    var vbo: gl.Uint = undefined;
    gl.genBuffers(1, &vbo);
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(data.len * @sizeOf(T)),
        data.ptr,
        gl.STATIC_DRAW,
    );
    gl.enableVertexAttribArray(index);
    gl.vertexAttribPointer(
        index,
        @sizeOf(T) / @sizeOf(f32),
        gl.FLOAT,
        gl.FALSE,
        0,
        @ptrFromInt(0),
    );
    return vbo;
}

pub fn createGlElementBuffer(comptime T: type, data: []T) c_uint {
    var ebo: gl.Uint = undefined;
    gl.genBuffers(1, &ebo);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @intCast(data.len * @sizeOf(T)),
        data.ptr,
        gl.STATIC_DRAW,
    );
    return ebo;
}

