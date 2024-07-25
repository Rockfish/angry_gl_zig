const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zstbi = @import("core").zstbi;
const core = @import("core");
const math = @import("math");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Allocator = std.mem.Allocator;

const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const TextureConfig = core.texture.TextureConfig;
const TextureFilter = core.texture.TextureFilter;
const TextureWrap = core.texture.TextureWrap;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

// set up vertex data (and buffer(s)) and configure vertex attributes
// ------------------------------------------------------------------

const VERTICES: [20]f32 = .{
    // positions      // texture coordinates
    0.5, 0.5, 0.0, 1.0, 1.0, // top right
    0.5, -0.5, 0.0, 1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 0.0, // bottom left
    -0.5, 0.5, 0.0, 0.0, 1.0, // top left
};

const INDICES: [6]u32 = .{
    0, 1, 3, // first triangle
    1, 2, 3, // second triangle
};

const vertices = VERTICES;
const indices = INDICES;
const num_indices = indices.len;

pub fn containerExample(allocator: std.mem.Allocator, window: *glfw.Window, shader: *Shader) !void {
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
        @as(isize, @intCast(vertices.len * SIZE_OF_FLOAT)),
        &vertices,
        gl.STATIC_DRAW,
    );

    // indices
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @as(isize, @intCast(indices.len * SIZE_OF_U32)),
        &indices,
        gl.STATIC_DRAW,
    );

    // position
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 5,
        @ptrFromInt(0 * SIZE_OF_FLOAT),
    );
    gl.enableVertexAttribArray(0);

    // texture coordinates
    gl.vertexAttribPointer(
        1,
        2,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 5,
        @ptrFromInt(3 * @sizeOf(f32)),
    );
    gl.enableVertexAttribArray(1);

    const texture_config = TextureConfig{
        .flip_v = false,
        .gamma_correction = false,
        .filter = TextureFilter.Nearest,
        .texture_type = TextureType.None,
        .wrap = TextureWrap.Repeat,
    };

    const texture = try Texture.new(
        allocator,
        "assets/bullet/red_and_green_bullet_transparent.png",
        texture_config,
    );

    defer texture.deinit();

    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        shader.use_shader();

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT); // | gl.DEPTH_BUFFER_BIT);

        gl.bindTexture(gl.TEXTURE_2D, texture.id);

        gl.bindVertexArray(vao);

        gl.drawElements(
            gl.TRIANGLES,
            @as(c_int, @intCast(indices.len)),
            gl.UNSIGNED_INT,
            null,
        );

        window.swapBuffers();
    }

    std.debug.print("\nRun completed.\n\n", .{});
}
