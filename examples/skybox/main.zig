const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const cube = @import("cube.zig");
const skybox = @import("skybox.zig");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Allocator = std.mem.Allocator;

const Camera = core.Camera;
const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const TextureConfig = core.texture.TextureConfig;
const TextureFilter = core.texture.TextureFilter;
const TextureWrap = core.texture.TextureWrap;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

const State = struct {
    camera: *Camera,
    light_postion: Vec3,
    delta_time: f32,
    last_frame: f32,
    first_mouse: bool,
    last_x: f32,
    last_y: f32,
};

var state: State = undefined;

pub fn main() !void {

    // var buf: [512]u8 = undefined;
    // const cwd = try std.fs.selfExeDirPath(&buf);
    // std.debug.print("Running sample_animation. cwd = {s}\n", .{cwd});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    core.string.init(allocator);

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.opengl_forward_compat, true);

    const window = try glfw.Window.create(
        SCR_WIDTH,
        SCR_HEIGHT,
        "Skybox",
        null,
    );
    defer window.destroy();

    _ = window.setKeyCallback(key_handler);
    _ = window.setFramebufferSizeCallback(framebuffer_size_handler);
    _ = window.setCursorPosCallback(cursor_position_handler);
    _ = window.setScrollCallback(scroll_handler);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // tell GLFW to capture our mouse
    // glfw.setInputMode(window, .cursor, .cursor_disabled); // ?

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    gl.enable(gl.DEPTH_TEST);

    const camera = try Camera.camera_vec3(allocator, vec3(0.0, 0.0, 3.0));
    defer camera.deinit();

    state = State{
        .camera = camera,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .last_x = SCR_WIDTH / 2.0,
        .last_y = SCR_HEIGHT / 2.0,
    };

    const shader = try Shader.new(
        allocator,
        "examples/skybox/basic.vert",
        "examples/skybox/basic.frag",
    );
    defer shader.deinit();

    const skybox_shader = try Shader.new(
        allocator,
        "examples/skybox/skybox.vert",
        "examples/skybox/skybox.frag",
    );
    defer skybox_shader.deinit();

    const cubeVAO = cube.init_cube();
    const skyboxVAO = skybox.init_skybox();

    const texture_config = .{
        .texture_type = .Diffuse,
        .filter = .Linear,
        .flip_v = true,
        .gamma_correction = false,
        .wrap = .Clamp,
    };

    const cubeTexture = try Texture.new(
        allocator,
        "assets/textures/container.jpg",
        texture_config,
    );
    defer cubeTexture.deinit();

    const faces = [_][:0]const u8{
        "assets/textures/skybox/right.jpg",
        "assets/textures/skybox/left.jpg",
        "assets/textures/skybox/top.jpg",
        "assets/textures/skybox/bottom.jpg",
        "assets/textures/skybox/front.jpg",
        "assets/textures/skybox/back.jpg",
    };

    const cubemap_id = skybox.loadCubemap(allocator, &faces);

    // shader configuration
    // --------------------
    shader.use_shader();
    shader.set_int("texture1", 0);

    skybox_shader.use_shader();
    skybox_shader.set_int("skybox", 0);

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        gl.clearColor(0.1, 0.1, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // draw scene as normal
        shader.use_shader();

        const model = Mat4.identity();
        const view = camera.get_view_matrix();
        const projection = Mat4.perspectiveRhGl(
            math.degreesToRadians(camera.zoom),
            SCR_WIDTH / SCR_HEIGHT,
            0.1,
            100.0,
        );

        shader.set_mat4("model", &model);
        shader.set_mat4("view", &view);
        shader.set_mat4("projection", &projection);

        // cubes
        gl.bindVertexArray(cubeVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_2D, cubemap_id);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        gl.bindVertexArray(0);

        // draw skybox as last
        gl.depthFunc(gl.LEQUAL); // change depth function so depth test passes when values are equal to depth buffer's content
        skybox_shader.use_shader();

        const sky_view = view.removeTranslation();
        skybox_shader.set_mat4("view", &sky_view);
        skybox_shader.set_mat4("projection", &projection);

        // skybox cube
        gl.bindVertexArray(skyboxVAO);
        gl.activeTexture(gl.TEXTURE0);
        gl.bindTexture(gl.TEXTURE_CUBE_MAP, cubemap_id);
        gl.drawArrays(gl.TRIANGLES, 0, 36);
        gl.bindVertexArray(0);
        gl.depthFunc(gl.LESS); // set depth function back to default

        window.swapBuffers();
        glfw.pollEvents();
    }

    // optional: de-allocate all resources once they've outlived their purpose:
    // ------------------------------------------------------------------------
    // gl.DeleteVertexArrays(1, &cubeVAO);
    // gl.DeleteVertexArrays(1, &skyboxVAO);
    // gl.DeleteBuffers(1, &cubeVBO);
    // gl.DeleteBuffers(1, &skyboxVBO);

    glfw.terminate();
}

fn key_handler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;
    _ = mods;
    switch (key) {
        .escape => {
            window.setShouldClose(true);
        },
        .t => {
            if (action == glfw.Action.press) {
                std.debug.print("time: {d}\n", .{state.delta_time});
            }
        },
        .w => state.camera.process_keyboard(.Forward, state.delta_time),
        .s => state.camera.process_keyboard(.Backward, state.delta_time),
        .a => state.camera.process_keyboard(.Left, state.delta_time),
        .d => state.camera.process_keyboard(.Right, state.delta_time),
        else => {},
    }
}

fn framebuffer_size_handler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}

fn mouse_hander(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = button;
    _ = action;
    _ = mods;
}

fn cursor_position_handler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    const xpos: f32 = @floatCast(xposIn);
    const ypos: f32 = @floatCast(yposIn);

    if (state.first_mouse) {
        state.last_x = xpos;
        state.last_y = ypos;
        state.first_mouse = false;
    }

    const xoffset = xpos - state.last_x;
    const yoffset = state.last_y - ypos; // reversed since y-coordinates go from bottom to top

    state.last_x = xpos;
    state.last_y = ypos;

    state.camera.process_mouse_movement(xoffset, yoffset, true);
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}
