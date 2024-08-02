const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

const CUBE_VERTICES = [_]f32{
    // positions      // texture Coords
    -0.5, -0.5, -0.5, 0.0, 0.0,
    0.5,  -0.5, -0.5, 1.0, 0.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    -0.5, 0.5,  -0.5, 0.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 0.0,

    -0.5, -0.5, 0.5,  0.0, 0.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 1.0,
    0.5,  0.5,  0.5,  1.0, 1.0,
    -0.5, 0.5,  0.5,  0.0, 1.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,

    -0.5, 0.5,  0.5,  1.0, 0.0,
    -0.5, 0.5,  -0.5, 1.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,
    -0.5, 0.5,  0.5,  1.0, 0.0,

    0.5,  0.5,  0.5,  1.0, 0.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, 0.5,  0.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 0.0,

    -0.5, -0.5, -0.5, 0.0, 1.0,
    0.5,  -0.5, -0.5, 1.0, 1.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    0.5,  -0.5, 0.5,  1.0, 0.0,
    -0.5, -0.5, 0.5,  0.0, 0.0,
    -0.5, -0.5, -0.5, 0.0, 1.0,

    -0.5, 0.5,  -0.5, 0.0, 1.0,
    0.5,  0.5,  -0.5, 1.0, 1.0,
    0.5,  0.5,  0.5,  1.0, 0.0,
    0.5,  0.5,  0.5,  1.0, 0.0,
    -0.5, 0.5,  0.5,  0.0, 0.0,
    -0.5, 0.5,  -0.5, 0.0, 1.0,
};

pub const Cube = struct {
    vao: u32,
    vbo: u32,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        gl.DeleteVertexArrays(1, &self.vao);
        gl.DeleteBuffers(1, &self.vbo);
    }

    pub fn init() Self {
        var vao: u32 = undefined;
        var vbo: u32 = undefined;

        gl.genVertexArrays(1, &vao);
        gl.genBuffers(1, &vbo);

        gl.bindVertexArray(vao);

        // vertices
        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            @as(isize, @intCast(CUBE_VERTICES.len * SIZE_OF_FLOAT)),
            &CUBE_VERTICES,
            gl.STATIC_DRAW,
        );

        // position
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 5,
            @ptrFromInt(0),
        );
        gl.enableVertexAttribArray(0);

        // texture coordinates
        gl.vertexAttribPointer(
            1,
            2,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 5,
            @ptrFromInt(SIZE_OF_FLOAT * 3),
        );
        gl.enableVertexAttribArray(1);

        return .{
            .vao = vao,
            .vbo = vbo,
        };
    }

    pub fn draw(self: *const Self, texture_id: u32) void {
        gl.bindVertexArray(self.vao);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, texture_id);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        gl.bindVertexArray(0);
    }
};
