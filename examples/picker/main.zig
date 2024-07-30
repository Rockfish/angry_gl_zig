const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const Cube = @import("cube.zig").Cube;

const PickingTexture = @import("picking_texture.zig").PickingTexture;
const PixelInfo = @import("picking_texture.zig").PixelInfo;
const PickingTechnique = @import("picking_technique.zig").PickingTechnique;

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;

const ModelBuilder = core.ModelBuilder;
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
    last_x: i32,
    last_y: i32,
    scr_width: i32 = @intFromFloat(SCR_WIDTH),
    scr_height: i32 = @intFromFloat(SCR_HEIGHT),
    key_presses: EnumSet(glfw.Key),
    key_shift: bool = false,
    mouse_right_button: bool = false,
    mouse_left_button: bool = false,
};

var state: State = undefined;
var picking_texture: PickingTexture = undefined;
var picking_technique: PickingTechnique = undefined;

pub fn main() !void {
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
    _ = window.setMouseButtonCallback(mouse_hander);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    gl.enable(gl.DEPTH_TEST);

    // const postion = vec3(0.0, 5.0, -22.0);
    // const target = vec3(0.0, -0.2, 1.0);
    // const up = vec3(0.0, 1.0, 0.0);

    // const camera = try Camera.camera_vec3(allocator, postion);
    const camera = try Camera.camera_vec3(allocator, vec3(0.0, 0.0, 6.0));
    defer camera.deinit();

    const key_presses = EnumSet(glfw.Key).initEmpty();

    state = State{
        .camera = camera,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .last_x = SCR_WIDTH / 2.0,
        .last_y = SCR_HEIGHT / 2.0,
        .key_presses = key_presses,
    };

    const basic_shader = try Shader.new(
        allocator,
        "examples/picker/basic.vert",
        "examples/picker/basic.frag",
    );
    defer basic_shader.deinit();

    const basic_model_shader = try Shader.new(
        allocator,
        "examples/picker/basic_model.vert",
        "examples/picker/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    const color_shader = try Shader.new(
        allocator,
        "examples/picker/simple_color.vert",
        "examples/picker/simple_color.frag",
    );
    defer color_shader.deinit();

    const model_path = "/Users/john/Dev/Repos/ogldev/Content/jeep.obj";
    const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = false, .gamma_correction = false, .wrap = .Clamp };

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    var builder = try ModelBuilder.init(allocator, &texture_cache, "bunny", model_path);
    try builder.addTexture("Group", texture_diffuse, "jeep_rood.jpg");
    var model = try builder.build();
    builder.deinit();
    defer model.deinit();

    const cube = Cube.init();
    const texture_config = .{
        .texture_type = .Diffuse,
        .filter = .Linear,
        .flip_v = false,
        .gamma_correction = false,
        .wrap = .Clamp,
    };
    const cube_texture = try Texture.new(
        allocator,
        "assets/textures/container.jpg",
        texture_config,
    );
    defer cube_texture.deinit();

    basic_shader.use_shader();
    basic_shader.set_uint("texture1", cube_texture.id);

    const projection = Mat4.perspectiveRhGl(math.degreesToRadians(camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 500.0);

    picking_texture = PickingTexture.init(SCR_WIDTH, SCR_HEIGHT);
    defer picking_texture.deinit();

    picking_technique = try PickingTechnique.init(allocator);
    defer picking_technique.deinit();

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        const view = camera.getViewMatrix();

        var model_transform = Mat4.identity();
        model_transform.translate(&vec3(0.0, -1.4, -50.0));
        model_transform.scale(&vec3(0.05, 0.05, 0.05));

        // const model_pvm = get_pvm_matrix(projection, view, model_transform);

        // render to picking framebuffer
        picking_texture.enableWriting(); // bind fbo
        picking_technique.enable(); // use shader
        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const cube_transform1 = Mat4.identity();

        var cube_transform2 = Mat4.identity();
        cube_transform2.translate(&vec3(2.0, 0.0, 0.0));

        picking_technique.setProjectionView(&projection, &view);

        picking_technique.setModel(&cube_transform1);
        picking_technique.setObjectIndex(1);
        picking_technique.setDrawIndex(1);
        cube.draw(cube_texture.id);

        picking_technique.setModel(&cube_transform2);
        picking_technique.setObjectIndex(2);
        picking_technique.setDrawIndex(2);
        cube.draw(cube_texture.id);

        picking_texture.disableWriting();

        // read from picking framebuffer

        var pixel_info = PixelInfo{};
        if (state.mouse_left_button) {
            pixel_info = picking_texture.readPixel(state.last_x, state.scr_width - state.last_y - 1);
            std.debug.print(
                "pixel_info x: {d} y: {d} object_id: {d} mesh_id: {d} primative_id: {d}\n",
                .{ state.last_x, state.last_y, pixel_info.object_id, pixel_info.draw_id, pixel_info.primative_id },
            );
        }

        basic_shader.use_shader();

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        basic_shader.set_mat4("projection", &projection);
        basic_shader.set_mat4("view", &view);

        var selected: i32 = if (pixel_info.object_id == 1.0) @intFromFloat(pixel_info.primative_id) else 0;
        basic_shader.set_int("primative_id", selected);
        basic_shader.set_mat4("model", &cube_transform1);
        cube.draw(cube_texture.id);

        selected = if (pixel_info.object_id == 2.0) @intFromFloat(pixel_info.primative_id) else 0;
        basic_shader.set_int("primative_id", selected);
        basic_shader.set_mat4("model", &cube_transform2);
        cube.draw(cube_texture.id);

        basic_model_shader.use_shader();
        basic_model_shader.set_mat4("projection", &projection);
        basic_model_shader.set_mat4("view", &view);
        basic_model_shader.set_mat4("model", &model_transform);

        try model.render(basic_model_shader);

        window.swapBuffers();
        glfw.pollEvents();
    }

    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();

    glfw.terminate();
}

fn get_pvm_matrix(projection: *const Mat4, view: *const Mat4, model_transform: *const Mat4) Mat4 {
    return projection.mulMat4(&view.mulMat4(model_transform));
}

fn key_handler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;

    switch (action) {
        .press => state.key_presses.insert(key),
        .release => state.key_presses.remove(key),
        else => {},
    }

    state.key_shift = mods.shift;

    var iterator = state.key_presses.iterator();
    while (iterator.next()) |k| {
        switch (k) {
            .escape => window.setShouldClose(true),
            .t => std.debug.print("time: {d}\n", .{state.delta_time}),
            .w => state.camera.process_keyboard(.Forward, state.delta_time),
            .s => state.camera.process_keyboard(.Backward, state.delta_time),
            .a => state.camera.process_keyboard(.Left, state.delta_time),
            .d => state.camera.process_keyboard(.Right, state.delta_time),
            .up => state.camera.process_keyboard(.Up, state.delta_time),
            .down => state.camera.process_keyboard(.Down, state.delta_time),
            else => {},
        }
    }
}

fn framebuffer_size_handler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}

fn mouse_hander(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = mods;

    state.mouse_left_button = action == .press and button == glfw.MouseButton.left;
    state.mouse_right_button = action == .press and button == glfw.MouseButton.right;
}

fn cursor_position_handler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    var xpos: i32 = @intFromFloat(xposIn);
    var ypos: i32 = @intFromFloat(yposIn);

    xpos = if (xpos < 0) 0 else if (xpos < state.scr_width) xpos else state.scr_width;
    ypos = if (ypos < 0) 0 else if (ypos < state.scr_height) ypos else state.scr_height;

    if (state.first_mouse) {
        state.last_x = xpos;
        state.last_y = ypos;
        state.first_mouse = false;
    }

    const xoffset = xpos - state.last_x;
    const yoffset = state.last_y - ypos; // reversed since y-coordinates go from bottom to top

    state.last_x = xpos;
    state.last_y = ypos;

    if (state.key_shift) {
        state.camera.processDirectionChange(xoffset, yoffset, true);
    }
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}