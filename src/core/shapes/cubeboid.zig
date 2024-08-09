const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");

const AABB = @import("../aabb.zig").AABB;

const Vec3 = math.Vec3;
const vec3 = math.vec3;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

pub const Cubeboid = struct {
    vao: u32,
    vbo: u32,
    ebo: u32,
    num_indices: i32,
    aabb: AABB,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        gl.DeleteVertexArrays(1, &self.vao);
        gl.DeleteBuffers(1, &self.vbo);
    }

    pub fn init(width: f32, height: f32, depth: f32) Self {
        const max = vec3(width / 2.0, height / 2.0, depth / 2.0);
        const min = max.mulScalar(-1.0);

        // position, normal, texcoords
        const vertices = [_]f32{
            // Front
            min.x, min.y, max.z, 0.0,  0.0,  1.0,  0.0, 0.0,
            max.x, min.y, max.z, 0.0,  0.0,  1.0,  1.0, 0.0,
            max.x, max.y, max.z, 0.0,  0.0,  1.0,  1.0, 1.0,
            min.x, max.y, max.z, 0.0,  0.0,  1.0,  0.0, 1.0,
            // Back
            min.x, max.y, min.z, 0.0,  0.0,  -1.0, 1.0, 0.0,
            max.x, max.y, min.z, 0.0,  0.0,  -1.0, 0.0, 0.0,
            max.x, min.y, min.z, 0.0,  0.0,  -1.0, 0.0, 1.0,
            min.x, min.y, min.z, 0.0,  0.0,  -1.0, 1.0, 1.0,
            // Right
            max.x, min.y, min.z, 1.0,  0.0,  0.0,  0.0, 0.0,
            max.x, max.y, min.z, 1.0,  0.0,  0.0,  1.0, 0.0,
            max.x, max.y, max.z, 1.0,  0.0,  0.0,  1.0, 1.0,
            max.x, min.y, max.z, 1.0,  0.0,  0.0,  0.0, 1.0,
            // Left
            min.x, min.y, max.z, -1.0, 0.0,  0.0,  1.0, 0.0,
            min.x, max.y, max.z, -1.0, 0.0,  0.0,  0.0, 0.0,
            min.x, max.y, min.z, -1.0, 0.0,  0.0,  0.0, 1.0,
            min.x, min.y, min.z, -1.0, 0.0,  0.0,  1.0, 1.0,
            // Top
            max.x, max.y, min.z, 0.0,  1.0,  0.0,  1.0, 0.0,
            min.x, max.y, min.z, 0.0,  1.0,  0.0,  0.0, 0.0,
            min.x, max.y, max.z, 0.0,  1.0,  0.0,  0.0, 1.0,
            max.x, max.y, max.z, 0.0,  1.0,  0.0,  1.0, 1.0,
            // Bottom
            max.x, min.y, max.z, 0.0,  -1.0, 0.0,  0.0, 0.0,
            min.x, min.y, max.z, 0.0,  -1.0, 0.0,  1.0, 0.0,
            min.x, min.y, min.z, 0.0,  -1.0, 0.0,  1.0, 1.0,
            max.x, min.y, min.z, 0.0,  -1.0, 0.0,  0.0, 1.0,
        };

        const indices = [_]u32{
            0, 1, 2, 2, 3, 0, // front
            4, 5, 6, 6, 7, 4, // back
            8, 9, 10, 10, 11, 8, // right
            12, 13, 14, 14, 15, 12, // left
            16, 17, 18, 18, 19, 16, // top
            20, 21, 22, 22, 23, 20, // bottom
        };

        var aabb = AABB.init();
        for (0..vertices.len / 8) |i| {
            const v = 8 * i;
            aabb.expand_to_include(vec3(vertices[v], vertices[v + 1], vertices[v + 2]));
        }

        var vao: u32 = undefined;
        var vbo: u32 = undefined;
        var ebo: u32 = undefined;

        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);
        gl.genBuffers(1, &ebo);

        gl.bindVertexArray(vao);

        // vertices
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            @intCast(vertices.len * SIZE_OF_FLOAT),
            &vertices,
            gl.STATIC_DRAW,
        );

        // indices
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @intCast(indices.len * @sizeOf(u32)),
            &indices,
            gl.STATIC_DRAW,
        );

        // position
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(0),
        );
        gl.enableVertexAttribArray(0);

        // normal
        gl.vertexAttribPointer(
            1,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(SIZE_OF_FLOAT * 3),
        );
        gl.enableVertexAttribArray(1);

        // texcoords
        gl.vertexAttribPointer(
            2,
            2,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 8,
            @ptrFromInt(SIZE_OF_FLOAT * 6),
        );
        gl.enableVertexAttribArray(2);

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .num_indices = @intCast(indices.len),
            .aabb = aabb,
        };
    }

    pub fn render(self: *const Self) void {
        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.num_indices,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
    }
};
