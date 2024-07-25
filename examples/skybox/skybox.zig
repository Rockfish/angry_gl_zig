const std = @import("std");
const gl = @import("zopengl").bindings;
const zstbi = @import("core").zstbi;

const Allocator = std.mem.Allocator;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

const SKYBOX_VERTICES = [_]f32{
    // positions
    -1.0, 1.0,  -1.0,
    -1.0, -1.0, -1.0,
    1.0,  -1.0, -1.0,
    1.0,  -1.0, -1.0,
    1.0,  1.0,  -1.0,
    -1.0, 1.0,  -1.0,

    -1.0, -1.0, 1.0,
    -1.0, -1.0, -1.0,
    -1.0, 1.0,  -1.0,
    -1.0, 1.0,  -1.0,
    -1.0, 1.0,  1.0,
    -1.0, -1.0, 1.0,

    1.0,  -1.0, -1.0,
    1.0,  -1.0, 1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  -1.0,
    1.0,  -1.0, -1.0,

    -1.0, -1.0, 1.0,
    -1.0, 1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    1.0,  -1.0, 1.0,
    -1.0, -1.0, 1.0,

    -1.0, 1.0,  -1.0,
    1.0,  1.0,  -1.0,
    1.0,  1.0,  1.0,
    1.0,  1.0,  1.0,
    -1.0, 1.0,  1.0,
    -1.0, 1.0,  -1.0,

    -1.0, -1.0, -1.0,
    -1.0, -1.0, 1.0,
    1.0,  -1.0, -1.0,
    1.0,  -1.0, -1.0,
    -1.0, -1.0, 1.0,
    1.0,  -1.0, 1.0,
};

pub fn init_skybox() u32 {
    var vao: u32 = undefined;
    var vbo: u32 = undefined;

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.bindVertexArray(vao);

    // vertices
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @as(isize, @intCast(SKYBOX_VERTICES.len * SIZE_OF_FLOAT)),
        &SKYBOX_VERTICES,
        gl.STATIC_DRAW,
    );

    // position
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 3,
        @ptrFromInt(0),
    );
    gl.enableVertexAttribArray(0);

    return vao;
}

// loads a cubemap texture from 6 individual texture faces
// order:
// +X (right)
// -X (left)
// +Y (top)
// -Y (bottom)
// +Z (front)
// -Z (back)
// -------------------------------------------------------
pub fn loadCubemap(allocator: Allocator, faces: *const [6][:0]const u8) u32 {
    zstbi.init(allocator);
    defer zstbi.deinit();

    var textureID: u32 = undefined;

    gl.genTextures(1, &textureID);
    gl.bindTexture(gl.TEXTURE_CUBE_MAP, textureID);

    for (faces, 0..) |face, i| {
        var image = zstbi.Image.loadFromFile(face, 0) catch |err| {
            std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{ err, face });
            @panic(@errorName(err));
        };
        defer image.deinit();

        const format: u32 = switch (image.num_components) {
            0 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => gl.RED,
        };

        gl.texImage2D(
            gl.TEXTURE_CUBE_MAP_POSITIVE_X + @as(c_uint, @intCast(i)),
            0,
            gl.RGB,
            @as(c_int, @intCast(image.width)),
            @as(c_int, @intCast(image.height)),
            0,
            format,
            gl.UNSIGNED_BYTE,
            image.data.ptr,
        );
    }
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_CUBE_MAP, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE);

    return textureID;
}
