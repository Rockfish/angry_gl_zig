const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");

const Picker = @import("picker.zig").Picker;
const PixelInfo = @import("picker.zig").PixelInfo;

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
    last_x: f32,
    last_y: f32,
    scr_width: f32 = SCR_WIDTH,
    scr_height: f32 = SCR_HEIGHT,
    key_presses: EnumSet(glfw.Key),
    key_shift: bool = false,
    mouse_right_button: bool = false,
    mouse_left_button: bool = false,
};

var state: State = undefined;
// var picker: PickingTexture = undefined;
// var picker: PickingTechnique = undefined;

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

    _ = window.setKeyCallback(keyHandler);
    _ = window.setFramebufferSizeCallback(framebufferSizeHandler);
    _ = window.setCursorPosCallback(cursorPositionHandler);
    _ = window.setScrollCallback(scrollHandler);
    _ = window.setMouseButtonCallback(mouseHandler);

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

    const camera = try Camera.init(
        allocator,
        .{
            .position = vec3(0.0, 0.0, 6.0),
            .target = vec3(0.0, 0.0, 0.0),
            .scr_width = SCR_WIDTH,
            .scr_height = SCR_HEIGHT,
        },
    );
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

    const basic_shader = try Shader.init(
        allocator,
        "examples/picker/basic.vert",
        "examples/picker/basic.frag",
    );
    defer basic_shader.deinit();

    const basic_model_shader = try Shader.init(
        allocator,
        "examples/picker/basic_model.vert",
        "examples/picker/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    const model_path = "/Users/john/Dev/Repos/ogldev/Content/jeep.obj";
    const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = false, .gamma_correction = false, .wrap = .Clamp };

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    var builder = try ModelBuilder.init(allocator, &texture_cache, "bunny", model_path);
    try builder.addTexture("Group", texture_diffuse, "jeep_rood.jpg");

    var model = try builder.build();

    builder.deinit();
    defer model.deinit();

    const cube = try core.shapes.createCube(allocator, .{ .width = 1.0, .height = 1.0, .depth = 2.0 });
    const cylinder = try core.shapes.createCylinder(allocator, 0.5, 4.0, 10);

    const texture_config = .{
        .texture_type = .Diffuse,
        .filter = .Linear,
        .flip_v = false,
        .gamma_correction = false,
        .wrap = .Clamp,
    };
    const cube_texture = try Texture.init(
        allocator,
        "assets/textures/container.jpg",
        texture_config,
    );
    defer cube_texture.deinit();

    const projection = Mat4.perspectiveRhGl(math.degreesToRadians(camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 500.0);

    basic_shader.useShader();
    basic_shader.setMat4("projection", &projection);
    basic_shader.setUint("texture1", cube_texture.gl_texture_id);

    basic_model_shader.useShader();
    basic_model_shader.setMat4("projection", &projection);

    var picker = try Picker.init(allocator, SCR_WIDTH, SCR_HEIGHT);
    defer picker.deinit();

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        const view = camera.getLookToView();

        var model_transform = Mat4.identity();
        model_transform.translate(&vec3(0.0, -1.4, -50.0));
        model_transform.scale(&vec3(0.05, 0.05, 0.05));

        picker.enable();

        const cube_transform1 = Mat4.identity();

        var cube_transform2 = Mat4.identity();
        cube_transform2.translate(&vec3(2.0, 0.0, 0.0));

        var cubeboid_transform = Mat4.identity();
        cubeboid_transform.translate(&vec3(-2.0, 0.0, 0.0));

        picker.setProjectView(&projection, &view);

        picker.setModelTransform(&cube_transform1);
        picker.setObjectId(1);
        picker.setMeshId(1);

        cube.render();

        picker.setModelTransform(&cube_transform2);
        picker.setObjectId(2);
        picker.setMeshId(2);

        cube.render();

        picker.disable();

        // read from picking framebuffer

        var pixel_info = PixelInfo{};
        if (state.mouse_left_button) {
            pixel_info = picker.readPixelInfo(state.last_x, state.scr_width - state.last_y - 1);
            std.debug.print(
                "pixel_info x: {d} y: {d} object_id: {d} mesh_id: {d} primative_id: {d}\n",
                .{ state.last_x, state.last_y, pixel_info.object_id, pixel_info.draw_id, pixel_info.primative_id },
            );
        }


        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        basic_shader.useShader();
        basic_shader.setMat4("view", &view);
        basic_shader.bindTexture(0, "texture_diffuse", cube_texture);

        var selected: i32 = if (pixel_info.object_id == 1.0) @intFromFloat(pixel_info.primative_id) else 0;

        basic_shader.setInt("primative_id", selected);
        basic_shader.setMat4("model", &cube_transform1);
        cube.render();

        selected = if (pixel_info.object_id == 2.0) @intFromFloat(pixel_info.primative_id) else 0;

        basic_shader.setInt("primative_id", selected);
        basic_shader.setMat4("model", &cube_transform2);
        cube.render();

        basic_model_shader.useShader();
        basic_model_shader.setMat4("view", &view);

        basic_model_shader.setMat4("model", &cubeboid_transform);
        basic_model_shader.bindTexture(0, "texture_diffuse", cube_texture);
        cube.render();

        const cylinder_transform = Mat4.fromTranslation(&vec3(3.0, 0.0, 0.0));
        basic_model_shader.setMat4("model", &cylinder_transform);
        cylinder.render();

        basic_model_shader.setMat4("model", &model_transform);
        model.render(basic_model_shader);

        window.swapBuffers();
        glfw.pollEvents();
    }

    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();

    glfw.terminate();
}

fn getPvmMatrix(projection: *const Mat4, view: *const Mat4, model_transform: *const Mat4) Mat4 {
    return projection.mulMat4(&view.mulMat4(model_transform));
}

fn keyHandler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
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
            .w => state.camera.processMovement(.Forward, state.delta_time),
            .s => state.camera.processMovement(.Backward, state.delta_time),
            .a => state.camera.processMovement(.Left, state.delta_time),
            .d => state.camera.processMovement(.Right, state.delta_time),
            .up => state.camera.processMovement(.Up, state.delta_time),
            .down => state.camera.processMovement(.Down, state.delta_time),
            else => {},
        }
    }
}

fn framebufferSizeHandler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}

fn mouseHandler(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = mods;

    state.mouse_left_button = action == .press and button == glfw.MouseButton.left;
    state.mouse_right_button = action == .press and button == glfw.MouseButton.right;
}

fn cursorPositionHandler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    var xpos: f32 = @floatCast(xposIn);
    var ypos: f32 = @floatCast(yposIn);

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
        state.camera.processMouseMovement(xoffset, yoffset, true);
    }
}

fn scrollHandler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.processMouseScroll(@floatCast(yoffset));
}
