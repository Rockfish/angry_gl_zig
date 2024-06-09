const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zstbi = @import("zstbi");
const Assimp = @import("core/assimp.zig");
const Model = @import("core/model_mesh.zig");
const ModelBuilder = @import("core/model_builder.zig").ModelBuilder;
const Animation = @import("core/animator.zig");
const Texture = @import("core/texture.zig").Texture;
const Camera = @import("core/camera.zig").Camera;
const Shader = @import("core/shader.zig").Shader;
const String = @import("core/string.zig");

// const math = @import("math/main.zig");
const math = @import("core/math.zig");

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
    lightPos: Vec3,
    deltaTime: f32,
    lastFrame: f32,
    firstMouse: bool,
    lastX: f32,
    lastY: f32,
};

const content_dir = "angrygl_assets";

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

    // try builderTest(allocator);

    try run(allocator, window);
}

pub fn builderTest(allocator: std.mem.Allocator) !void {
    const file = "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/vampire/dancing_vampire.dae";

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    var builder = try ModelBuilder.init(allocator, &texture_cache, "Player", file);

    const texture_type = .{ .texture_type = .Normals, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };

    try builder.addTexture("Vampire-lib", texture_type, "textures/Vampire_normal.png");

    var model = try builder.flipv().build();
    builder.deinit();

    std.debug.print("", .{});

    // std.debug.print("mesh name: {s}\n", .{model.meshes.items[0].name});
    // std.debug.print("mesh num vertices: {any}\n", .{model.meshes.items[0].vertices.items.len});
    // std.debug.print("mesh num indices: {any}\n", .{model.meshes.items[0].indices.items.len});

    // for (model.meshes.items[0].textures.items) |_texture| {
    //     std.debug.print("model texture: {s}\n", .{_texture.texture_path});
    // }

    // std.debug.print("\nmodel builder test completed.\n\n", .{});

    model.deinit();

    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";

    const camera = try Camera.camera_vec3(allocator, vec3(0.0, 40.0, 120.0));

    // Initialize the world state
    var state = State{
        .camera = camera,
        .lightPos = vec3(1.2, 1.0, 2.0),
        .deltaTime = 0.0,
        .lastFrame = 0.0,
        .firstMouse = true,
        .lastX = SCR_WIDTH / 2.0,
        .lastY = SCR_HEIGHT / 2.0,
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
    state.lastFrame = @floatCast(glfw.getTime());

    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.deltaTime = currentFrame - state.lastFrame;
        state.lastFrame = currentFrame;

        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        // std.debug.print("Main: use_shader\n", .{});
        shader.use_shader();

        // std.debug.print("Main: update_animation\n", .{});
        try model.update_animation(state.deltaTime);

        gl.clearColor(0.05, 0.1, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // fov: 0.7853982
        // width: 800
        // height: 800
        // projection: [[2.4142134, 0, 0, 0], [0, 2.4142134, 0, 0], [0, 0, -1.0001999, -1], [0, 0, -0.20001999, 0]]
        // view: [[1, 0, 0.00000004371139, 0], [0, 1, -0, 0], [-0.00000004371139, 0, 1, 0], [0.0000052453665, -40, -120, 1]]
        // model: [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, -10.4, -400, 1]]

        const projection = Mat4.perspectiveRhGl(toRadians(state.camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 1000.0);
        const view = state.camera.get_view_matrix();

        var modelTransform = Mat4.identity();
        modelTransform.translate(vec3(0.0, -10.4, -400.0));
        modelTransform.scale(vec3(1.0, 1.0, 1.0));

        // std.debug.print("fov: {any}\nwidth: {any}\nheight: {any}\nprojection: {any}\nview: {any}\nmodel: {any}\n\n",
        // .{toRadians(state.camera.zoom), SCR_WIDTH, SCR_HEIGHT, projection, view, modelTransform});
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
