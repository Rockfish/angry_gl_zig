const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const set = @import("ziglangSet");
const core = @import("core");
const math = @import("math");

const Player = @import("player.zig").Player;
const Enemy = @import("enemy.zig").Enemy;
const EnemySystem = @import("enemy.zig").EnemySystem;
const BulletStore = @import("bullets.zig").BulletStore;
const BurnMarks = @import("burn_marks.zig").BurnMarks;
const MuzzleFlash = @import("muzzle_flash.zig").MuzzleFlash;
const Floor = @import("floor.zig").Floor;
const SoundSystem = @import("sound_system.zig").SoundSystem;


const gl = zopengl.bindings;

const Assimp = core.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Animation = core.Animation;
const Texture = core.Texture;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.String;
const FrameCount = core.FrameCount;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const TextureType = Texture.TextureType;
const Animator = Animation.Animator;
const AnimationClip = Animation.AnimationClip;
const AnimationRepeat = Animation.AnimationRepeat;

const Window = glfw.Window;

const VIEW_PORT_WIDTH: f32 = 1500.0;
const VIEW_PORT_HEIGHT: f32 = 1000.0;

// Player
const FIRE_INTERVAL: f32 = 0.1;
// seconds
const SPREAD_AMOUNT: i32 = 20;

const PLAYER_COLLISION_RADIUS: f32 = 0.35;

// Models
const PLAYER_MODEL_SCALE: f32 = 0.0044;
//const PLAYER_MODEL_GUN_HEIGHT: f32 = 120.0; // un-scaled
const PLAYER_MODEL_GUN_HEIGHT: f32 = 110.0;
// un-scaled
const PLAYER_MODEL_GUN_MUZZLE_OFFSET: f32 = 100.0;
// un-scaled
const MONSTER_Y: f32 = PLAYER_MODEL_SCALE * PLAYER_MODEL_GUN_HEIGHT;

// Lighting
const LIGHT_FACTOR: f32 = 0.8;
const NON_BLUE: f32 = 0.9;
const BLUR_SCALE: i32 = 2;
const FLOOR_LIGHT_FACTOR: f32 = 0.35;
const FLOOR_NON_BLUE: f32 = 0.7;

// Enemies
const MONSTER_SPEED: f32 = 0.6;

const CameraType = enum {
    Game,
    Floating,
    TopDown,
    Side,
};

// Struct for passing state between the window loop and the event handler.
const State = struct {
    game_camera: *Camera,
    floating_camera: *Camera,
    ortho_camera: *Camera,
    active_camera: CameraType,
    player: *Player,
    enemies: std.ArrayList(*Enemy),
    burn_marks: *BurnMarks,
    sound_system: *SoundSystem,
    game_projection: Mat4,
    floating_projection: Mat4,
    orthographic_projection: Mat4,
    key_presses: set.Set(glfw.Key),
    light_postion: Vec3,
    mouse_x: f32,
    mouse_y: f32,
    delta_time: f32,
    frame_time: f32,
    last_frame: f32,
    first_mouse: bool,
    last_x: f32,
    last_y: f32,
    run: bool,
};

const content_dir = "angrygl_assets";

var state: State = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    String.init(allocator);

    // var arena_state = std.heap.ArenaAllocator.init(allocator);
    // defer arena_state.deinit();
    // const arena = arena_state.allocator();

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

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
    _ = root_path;


    // Shaders

    const shader = try Shader.new( allocator, "game/shaders/player_shader.vert", "game/shaders/player_shader.frag");
    const player_emissive_shader = Shader.new(allocator, "shaders/player_shader.vert", "shaders/texture_emissive_shader.frag");
    const wiggly_shader = Shader.new(allocator, "shaders/wiggly_shader.vert", "shaders/player_shader.frag");
    const floor_shader = Shader.new(allocator, "shaders/basic_texture_shader.vert", "shaders/floor_shader.frag");

    // bullets, muzzle flash, burn marks
    const instanced_texture_shader = Shader.new(allocator, "shaders/instanced_texture_shader.vert", "shaders/basic_texture_shader.frag");
    const sprite_shader = Shader.new(allocator, "shaders/geom_shader2.vert", "shaders/sprite_shader.frag");
    const basic_texture_shader = Shader.new(allocator, "shaders/basic_texture_shader.vert", "shaders/basic_texture_shader.frag");

    // blur and scene
    const blur_shader = Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/blur_shader.frag");
    const scene_draw_shader = Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/texture_merge_shader.frag");

    // for debug
    const basicer_shader = Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/basicer_shader.frag");
    const _depth_shader = Shader.new(allocator, "shaders/depth_shader.vert", "shaders/depth_shader.frag");
    const _debug_depth_shader = Shader.new(allocator, "shaders/debug_depth_quad.vert", "shaders/debug_depth_quad.frag");

    // --- Lighting ---

    const light_dir = vec3(-0.8, 0.0, -1.0).normalize();
    const player_light_dir = vec3(-1.0, -1.0, -1.0).normalize();
    const muzzle_point_light_color = vec3(1.0, 0.2, 0.0);

    const light_color = LIGHT_FACTOR * 1.0 * vec3(NON_BLUE * 0.406, NON_BLUE * 0.723, 1.0);
    const ambient_color = LIGHT_FACTOR * 0.10 * vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7);

    const floor_light_color = FLOOR_LIGHT_FACTOR * 1.0 * vec3(FLOOR_NON_BLUE * 0.406, FLOOR_NON_BLUE * 0.723, 1.0);
    const floor_ambient_color = FLOOR_LIGHT_FACTOR * 0.50 * vec3(FLOOR_NON_BLUE * 0.7, FLOOR_NON_BLUE * 0.7, 0.7);

    const window_scale = window.getContentScale();

    const viewport_width = VIEW_PORT_WIDTH * window_scale[0];
    const viewport_height = VIEW_PORT_HEIGHT * window_scale[1];
    const scaled_width = viewport_width / window_scale[0];
    const scaled_height = viewport_height / window_scale[1];

    //     // -- Framebuffers ---
    //
    //     let depth_map_fbo = create_depth_map_fbo();
    //     let mut emissions_fbo = create_emission_fbo(viewport_width, viewport_height);
    //     let mut scene_fbo = create_scene_fbo(viewport_width, viewport_height);
    //     let mut horizontal_blur_fbo = create_horizontal_blur_fbo(viewport_width, viewport_height);
    //     let mut vertical_blur_fbo = create_vertical_blur_fbo(viewport_width, viewport_height);
    //
    //     // --- quads ---
    //
    //     let unit_square_quad = create_unit_square_vao() as i32;
    //     let _obnoxious_quad_vao = create_obnoxious_quad_vao() as i32;
    //     let more_obnoxious_quad_vao = create_more_obnoxious_quad_vao() as i32;


    // --- Cameras ---

    const camera_follow_vec = vec3(-4.0, 4.3, 0.0);
    const _camera_up = vec3(0.0, 1.0, 0.0);

    const game_camera = Camera.camera_vec3_up_yaw_pitch(
        vec3(0.0, 20.0, 80.0), // for xz world
        vec3(0.0, 1.0, 0.0),
        -90.0,
        -20.0,
    );

    const floating_camera = Camera.camera_vec3_up_yaw_pitch(
        vec3(0.0, 10.0, 20.0), // for xz world
        vec3(0.0, 1.0, 0.0),
        -90.0,
        -20.0,
    );

    const ortho_camera = Camera.camera_vec3_up_yaw_pitch(vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), 0.0, -90.0);

    const ortho_width = VIEW_PORT_WIDTH / 130.0;
    const ortho_height = VIEW_PORT_HEIGHT / 130.0;
    const aspect_ratio = VIEW_PORT_WIDTH / VIEW_PORT_HEIGHT;
    const game_projection = Mat4.perspectiveRhGl(game_camera.zoom.to_radians(), aspect_ratio, 0.1, 100.0);
    const floating_projection = Mat4.perspectiveRhGl(floating_camera.zoom.to_radians(), aspect_ratio, 0.1, 100.0);
    const orthographic_projection = Mat4.orthographicRhGl(-ortho_width, ortho_width, -ortho_height, ortho_height, 0.1, 100.0);

    // Models and systems

    const player = Player.new(allocator);
    const floor = Floor.new(allocator);
    const enemies = EnemySystem.new(allocator);
    const muzzle_flash = MuzzleFlash.new(allocator, unit_square_quad);
    const bullet_store = BulletStore.new(allocator, unit_square_quad);


    // Initialize the world state
    state = State{
        .game_camera = game_camera,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .last_x = SCR_WIDTH / 2.0,
        .last_y = SCR_HEIGHT / 2.0,
    };

    gl.enable(gl.DEPTH_TEST);


    std.debug.print("Shader id: {d}\n", .{shader.id});

    // const lightDir: Vec3 = vec3(-0.8, 0.0, -1.0).normalize_or_zero();
    // const playerLightDir: Vec3 = vec3(-1.0, -1.0, -1.0).normalize_or_zero();

    // const lightColor: Vec3 = LIGHT_FACTOR * 1.0 * vec3(NON_BLUE * 0.406, NON_BLUE * 0.723, 1.0);
    // const lightColor: Vec3 = LIGHT_FACTOR * 1.0 * vec3(0.406, 0.723, 1.0);

    // const floorLightColor: Vec3 = FLOOR_LIGHT_FACTOR * 1.0 * vec3(FLOOR_NON_BLUE * 0.406, FLOOR_NON_BLUE * 0.723, 1.0);
    // const floorAmbientColor: Vec3 = FLOOR_LIGHT_FACTOR * 0.50 * vec3(FLOOR_NON_BLUE * 0.7, FLOOR_NON_BLUE * 0.7, 0.7);

    const ambientColor: Vec3 = vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7);

    const model_path = "assets/Models/Player/Player.fbx";

    std.debug.print("Main: loading model: {s}\n", .{model_path});

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    var builder = try ModelBuilder.init(allocator, &texture_cache, "Player", model_path);

    const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_specular = .{ .texture_type = .Specular, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_emissive = .{ .texture_type = .Emissive, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
    const texture_normals = .{ .texture_type = .Normals, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };

    std.debug.print("Main: adding textures\n", .{});
    try builder.addTexture("Player", texture_diffuse, "assets/Models/Player/Textures/Player_D.tga");
    try builder.addTexture("Player", texture_specular, "assets/Models/Player/Textures/Player_M.tga");
    try builder.addTexture("Player", texture_emissive, "assets/Models/Player/Textures/Player_E.tga");
    try builder.addTexture("Player", texture_normals, "assets/Models/Player/Textures/Player_NRM.tga");
    try builder.addTexture("Gun", texture_diffuse, "assets/Models/Player/Textures/Gun_D.tga");
    try builder.addTexture("Gun", texture_specular, "assets/Models/Player/Textures/Gun_M.tga");
    try builder.addTexture("Gun", texture_emissive, "assets/Models/Player/Textures/Gun_E.tga");
    try builder.addTexture("Gun", texture_normals, "assets/Models/Player/Textures/Gun_NRM.tga");

    std.debug.print("Main: building model: {s}\n", .{model_path});
    var model = try builder.build();
    builder.deinit();

    const idle = AnimationClip.new(55.0, 130.0, AnimationRepeat.Forever);
    const forward = AnimationClip.new(134.0, 154.0, AnimationRepeat.Forever);
    // const backwards = AnimationClip.new(159.0, 179.0, AnimationRepeat.Forever);
    // const right = AnimationClip.new(184.0, 204.0, AnimationRepeat.Forever);
    // const left = AnimationClip.new(209.0, 229.0, AnimationRepeat.Forever);
    // const dying = AnimationClip.new(234.0, 293.0, AnimationRepeat.Once);

    std.debug.print("Main: playClip\n", .{});
    try model.playClip(idle);
    try model.play_clip_with_transition(forward, 6);

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

        // if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
        //     window.setShouldClose(true);
        // }

        // std.debug.print("Main: use_shader\n", .{});
        shader.use_shader();

        // std.debug.print("Main: update_animation\n", .{});
        try model.update_animation(state.delta_time);

        gl.clearColor(0.05, 0.1, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // fov: 0.7853982
        // width: 800
        // height: 800
        // projection: [[2.4142134, 0, 0, 0], [0, 2.4142134, 0, 0], [0, 0, -1.0001999, -1], [0, 0, -0.20001999, 0]]
        // view: [[1, 0, 0.00000004371139, 0], [0, 1, -0, 0], [-0.00000004371139, 0, 1, 0], [0.0000052453665, -40, -120, 1]]
        // model: [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, -10.4, -400, 1]]

        const projection = Mat4.perspectiveRhGl(toRadians(state.game_camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 1000.0);
        const view = state.game_camera.get_view_matrix();

        var modelTransform = Mat4.identity();
        modelTransform.translate(&vec3(0.0, -10.4, -400.0));
        modelTransform.scale(&vec3(1.0, 1.0, 1.0));

        // std.debug.print("fov: {any}\nwidth: {any}\nheight: {any}\nprojection: {any}\nview: {any}\nmodel: {any}\n\n",
        // .{toRadians(state.game_camera.zoom), SCR_WIDTH, SCR_HEIGHT, projection, view, modelTransform});
        // std.debug.print("Matrix identity: {any}\n", .{Matrix.identity().toArray()});

        shader.set_mat4("projection", &projection);
        shader.set_mat4("view", &view);
        shader.set_mat4("model", &modelTransform);

        shader.set_bool("useLight", true);
        shader.set_vec3("ambient", &ambientColor);

        const identity = Mat4.identity();
        shader.set_mat4("aimRot", &identity);
        shader.set_mat4("lightSpaceMatrix", &identity);

        // std.debug.print("Main: render\n", .{});
        try model.render(shader);

        window.swapBuffers();
    }

    std.debug.print("\nRun completed.\n\n", .{});

    shader.deinit();
    game_camera.deinit();
    model.deinit();
    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}

inline fn toRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}

fn key_handler (window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;
    _ = mods;
    switch (key) {
        .escape => { window.setShouldClose(true); },
        .t => {
            if (action == glfw.Action.press) {
                std.debug.print("time: {d}\n", .{state.delta_time});
            }
        },
        .w => { state.game_camera.process_keyboard(.Forward, state.delta_time);},
        .s => { state.game_camera.process_keyboard(.Backward, state.delta_time);},
        .a => { state.game_camera.process_keyboard(.Left, state.delta_time);},
        .d => { state.game_camera.process_keyboard(.Right, state.delta_time);},
        else => {}
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

    state.game_camera.process_mouse_movement(xoffset, yoffset, true);
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.game_camera.process_mouse_scroll(@floatCast(yoffset));
}
