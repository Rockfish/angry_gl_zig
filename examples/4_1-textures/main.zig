const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");
const Shader = @import("core/shader.zig").Shader;

// const math = @import("math/main.zig");
const math = @import("core/math.zig");

const SCR_WIDTH: f32 = 800.0;
const SCR_HEIGHT: f32 = 800.0;


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    // glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(600, 600, "Angry ", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    var vao: u32 = undefined;
    var vbo: u32 = undefined;
    var ebo: u32 = undefined;
    var texture_id: u32 = undefined;

    const shader = try Shader.new(
            allocator,
            "src/4_1-textures/4_1-texture.vert",
            "src/4_1-textures/4_1-texture.frag",
    );

    // set up vertex data (and buffer(s)) and configure vertex attributes
    // ------------------------------------------------------------------
    const vertices: [32]f32 = .{
         // positions      // colors        // texture coordinates
         0.5,  0.5, 0.0,   1.0, 0.0, 0.0,   1.0, 1.0, // top right
         0.5, -0.5, 0.0,   0.0, 1.0, 0.0,   1.0, 0.0, // bottom right
        -0.5, -0.5, 0.0,   0.0, 0.0, 1.0,   0.0, 0.0, // bottom left
        -0.5,  0.5, 0.0,   1.0, 1.0, 0.0,   0.0, 1.0, // top left
    };

    const indices: [6]u32 = .{
        0, 1, 3, // first triangle
        1, 2, 3  // second triangle
    };

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.genBuffers(1, &ebo);

    // load vertex data into vertex buffers
    gl.bindVertexArray(vao);

    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
    gl.ARRAY_BUFFER,
    @as(isize, @intCast(vertices.len * @sizeOf(f32))),
    &vertices,
    gl.STATIC_DRAW,
    );

    // load index data into element buffer
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
    gl.ELEMENT_ARRAY_BUFFER,
    @as(isize, @intCast(indices.len * @sizeOf(u32))),
    &indices,
    gl.STATIC_DRAW,
    );

    // position
    gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(f32) * 8,
            @as(?*anyopaque, @ptrFromInt(0 * @sizeOf(f32))),
    );
    gl.enableVertexAttribArray(0);

    // color
    gl.vertexAttribPointer(
            1,
            3,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(f32) * 8,
            @as(?*anyopaque, @ptrFromInt(3 * @sizeOf(f32))),
    );
    gl.enableVertexAttribArray(1);

    // texture coordinates
    gl.vertexAttribPointer(
            2,
            2,
            gl.FLOAT,
            gl.FALSE,
            @sizeOf(f32) * 8,
            @as(?*anyopaque, @ptrFromInt(6 * @sizeOf(f32))),
    );
    gl.enableVertexAttribArray(2);

    gl.genTextures(1, &texture_id);
    gl.bindTexture(gl.TEXTURE_2D, texture_id);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

    zstbi.init(allocator);
    defer zstbi.deinit();

    std.debug.print("loading image\n", .{});
    var image = try zstbi.Image.loadFromFile("src/4_1-textures/container.jpg", 0);
    defer image.deinit();

    const width: c_int = @intCast(image.width);
    const height: c_int = @intCast(image.height);

    // gl.texImage2D(
    //         gl.TEXTURE_2D,
    //         0,
    //         @as(gl.GLint, @intCast(@intFromEnum(pixelFormat))),
    //         @as(c_int, @intCast(width)),
    //         @as(c_int, @intCast(height)),
    //         0,
    //         @intFromEnum(pixelFormat),
    //         gl.UNSIGNED_BYTE,
    //         data.ptr);

    gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            @as(c_int, @intCast(width)),
            @as(c_int, @intCast(height)),
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            image.data.ptr,
    );

    gl.generateMipmap(gl.TEXTURE_2D);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT); // | gl.DEPTH_BUFFER_BIT);

        shader.use_shader();

        gl.bindTexture(gl.TEXTURE_2D, texture_id);

        gl.bindVertexArray(vao);
        gl.drawElements(gl.TRIANGLES,  @as(c_int, @intCast(6)), gl.UNSIGNED_INT, null); //@as(?*anyopaque, @ptrFromInt(0)));

        window.swapBuffers();
    }

    std.debug.print("\nRun completed.\n\n", .{});

    shader.deinit();

}