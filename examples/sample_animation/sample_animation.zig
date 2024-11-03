const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const core = @import("core");
const math = @import("math");

const gl = zopengl.bindings;

const Assimp = core.assimp.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const animation = core.animation;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.string.String;
const FrameCount = core.FrameCount;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const Animator = animation.Animator;
const AnimationClip = animation.AnimationClip;
const AnimationRepeat = animation.AnimationRepeatMode;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 800.0;
const SCR_HEIGHT: f32 = 800.0;

// Lighting
const LIGHT_FACTOR: f32 = 1.0;
const NON_BLUE: f32 = 0.9;

const FLOOR_LIGHT_FACTOR: f32 = 0.35;
const FLOOR_NON_BLUE: f32 = 0.7;

// Struct for passing state between the window loop and the event handler.
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
};

const content_dir = "assets";

var state: State = undefined;

const V4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn new(x: f32, y: f32, z: f32, w: f32) V4 {
        return .{ .x = x, .y = y, .z = z, .w = w };
    }
};

pub fn main() !void {
    var buf: [512]u8 = undefined;
    const cwd = try std.fs.selfExeDirPath(&buf);
    std.debug.print("Running sample_animation. cwd = {s}\n", .{cwd});

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
    // For MacOS
    glfw.windowHintTyped(.opengl_forward_compat, true);

    const window = try glfw.Window.create(600, 600, "Angry ", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";

    const camera = try Camera.camera_vec3(allocator, vec3(0.0, 40.0, 120.0));

    // Initialize the world state
    state = State{
        .camera = camera,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .last_x = SCR_WIDTH / 2.0,
        .last_y = SCR_HEIGHT / 2.0,
    };

    gl.enable(gl.DEPTH_TEST);

    const shader = try Shader.new(
        allocator,
        "examples/sample_animation/player_shader.vert",
        "examples/sample_animation/player_shader.frag",
    );

    _ = root_path;

    std.debug.print("Shader id: {d}\n", .{shader.id});

    // const lightDir: Vec3 = vec3(-0.8, 0.0, -1.0).normalize_or_zero();
    // const playerLightDir: Vec3 = vec3(-1.0, -1.0, -1.0).normalize_or_zero();

    // const lightColor: Vec3 = LIGHT_FACTOR * 1.0 * vec3(NON_BLUE * 0.406, NON_BLUE * 0.723, 1.0);
    // const lightColor: Vec3 = LIGHT_FACTOR * 1.0 * vec3(0.406, 0.723, 1.0);

    // const floorLightColor: Vec3 = FLOOR_LIGHT_FACTOR * 1.0 * vec3(FLOOR_NON_BLUE * 0.406, FLOOR_NON_BLUE * 0.723, 1.0);
    // const floorAmbientColor: Vec3 = FLOOR_LIGHT_FACTOR * 0.50 * vec3(FLOOR_NON_BLUE * 0.7, FLOOR_NON_BLUE * 0.7, 0.7);

    const ambientColor: Vec3 = vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7);

    const model_path = "angrybots_assets/Models/Player/Player.fbx";

    std.debug.print("Main: loading model: {s}\n", .{model_path});

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    var builder = try ModelBuilder.init(allocator, &texture_cache, "Player", model_path);

    const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_specular = .{ .texture_type = .Specular, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_emissive = .{ .texture_type = .Emissive, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_normals = .{ .texture_type = .Normals, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };

    std.debug.print("Main: adding textures\n", .{});
    try builder.addTexture("Player", texture_diffuse, "Textures/Player_D.tga");
    try builder.addTexture("Player", texture_specular, "Textures/Player_M.tga");
    try builder.addTexture("Player", texture_emissive, "Textures/Player_E.tga");
    try builder.addTexture("Player", texture_normals, "Textures/Player_NRM.tga");
    try builder.addTexture("Gun", texture_diffuse, "Textures/Gun_D.tga");
    try builder.addTexture("Gun", texture_specular, "Textures/Gun_M.tga");
    try builder.addTexture("Gun", texture_emissive, "Textures/Gun_E.tga");
    try builder.addTexture("Gun", texture_normals, "Textures/Gun_NRM.tga");

    std.debug.print("Main: building model: {s}\n", .{model_path});
    var model = try builder.build();
    builder.deinit();

    const bullet_model_path = "angrybots_assets/Models/Bullet/Bullet.FBX";
    var bullet_model_builder = try ModelBuilder.init(
        allocator,
        &texture_cache,
        "bullet",
        bullet_model_path,
    );
    bullet_model_builder.skipModelTextures();

    // try bullet_model_builder.addTexture( "Plane001", texture_diffuse, "Textures/BulletTexture.png");
    try bullet_model_builder.addTexture(
        "Plane001",
        texture_diffuse,
        "Floor D.png",
    );
    var bullet_model = try bullet_model_builder.build();
    bullet_model_builder.deinit();

    defer bullet_model.deinit();

    // const idle = AnimationClip.new(55.0, 130.0, AnimationRepeat.Forever);
    // const forward = AnimationClip.new(134.0, 154.0, AnimationRepeat.Forever);
    // const backwards = AnimationClip.new(159.0, 179.0, AnimationRepeat.Forever);
    // const right = AnimationClip.new(184.0, 204.0, AnimationRepeat.Forever);
    // const left = AnimationClip.new(209.0, 229.0, AnimationRepeat.Forever);
    // const dying = AnimationClip.new(234.0, 293.0, AnimationRepeat.Once);

    std.debug.print("Main: playClip\n", .{});
    // try model.playClip(idle);
    // try model.play_clip_with_transition(forward, 6);
    // try model.playClip(forward);
    std.debug.print("animation state: {any}\n", .{model.animator.animation_state});

    // --- event loop
    state.last_frame = @floatCast(glfw.getTime());
    var frame_counter = FrameCount.new();

    _ = window.setKeyCallback(key_handler);
    _ = window.setFramebufferSizeCallback(framebuffer_size_handler);
    _ = window.setCursorPosCallback(cursor_position_handler);
    _ = window.setScrollCallback(scroll_handler);

    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        frame_counter.update();

        glfw.pollEvents();

        gl.clearColor(0.05, 0.1, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const debug_camera = try Camera.camera_vec3(allocator, vec3(0.0, 40.0, 120.0));
        defer debug_camera.deinit();

        const projection = Mat4.perspectiveRhGl(toRadians(debug_camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 1000.0);
        const view = state.camera.get_lookto_view();

        var model_transform = Mat4.identity();
        model_transform.translate(&vec3(0.0, -10.4, -400.0));
        model_transform.scale(&vec3(1.0, 1.0, 1.0));

        shader.set_mat4("projection", &projection);
        shader.set_mat4("view", &view);
        shader.set_mat4("model", &model_transform);

        shader.set_bool("useLight", true);
        shader.set_vec3("ambient", &ambientColor);

        const identity = Mat4.identity();
        shader.set_mat4("aimRot", &identity);
        shader.set_mat4("lightSpaceMatrix", &identity);

        // std.debug.print("Main: render\n", .{});
        //try model.update_animation(state.delta_time);
        try model.playTick(140.0);
        model.render(shader);
        try core.dumpModelNodes(model);

        const bulletTransform = Mat4.fromScale(&vec3(2.0, 2.0, 2.0));

        shader.set_mat4("model", &bulletTransform);
        bullet_model.render(shader);

        window.swapBuffers();

        break;
    }

    std.debug.print("\nRun completed.\n\n", .{});

    shader.deinit();
    camera.deinit();
    model.deinit();
    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}

inline fn toRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
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
        .w => {
            state.camera.process_keyboard(.Forward, state.delta_time);
        },
        .s => {
            state.camera.process_keyboard(.Backward, state.delta_time);
        },
        .a => {
            state.camera.process_keyboard(.Left, state.delta_time);
        },
        .d => {
            state.camera.process_keyboard(.Right, state.delta_time);
        },
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

    state.camera.process_mouse_movement(xoffset, yoffset, true);
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}
