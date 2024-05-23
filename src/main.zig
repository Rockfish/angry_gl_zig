const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const zstbi = @import("zstbi");
const math = @import("math/main.zig");
const Assimp = @import("core/assimp.zig");
const Model = @import("core/model_mesh.zig");
const ModelBuilder = @import("core/model_builder.zig").ModelBuilder;
const Texture = @import("core/texture.zig").Texture;
const Camera = @import("core/camera.zig").Camera;
const Shader = @import("core/shader.zig").Shader;
const String = @import("core/string.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Mat4 = math.Mat4x4;
const vec2 = math.vec2;
const vec3 = math.vec3;
// const mat4 = zm.mat4;

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
    var texture_cache = std.ArrayList(*Texture).init(allocator);
    const file = "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/vampire/dancing_vampire.dae";

    var builder = try ModelBuilder.init(allocator, &texture_cache, "Player", file);

    const texture_type = .{ .texture_type = .Normals, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };

    try builder.addTexture("Vampire-lib", texture_type, "textures/Vampire_normal.png");

    var model = try builder.flipv().build();
    builder.deinit();

    std.debug.print("", .{});

    std.debug.print("mesh name: {s}\n", .{model.meshes.items[0].name});
    std.debug.print("mesh num vertices: {any}\n", .{model.meshes.items[0].vertices.items.len});
    std.debug.print("mesh num indices: {any}\n", .{model.meshes.items[0].indices.items.len});

    for (model.meshes.items[0].textures.items) |_texture| {
        std.debug.print("model texture: {s}\n", .{_texture.texture_path});
    }

    std.debug.print("\nmodel builder test completed.\n\n", .{});

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
    const state = State{
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

    _ = state;
    _ = root_path;

    std.debug.print("Shader id: {d}\n", .{shader.id});

    // --- event loop
    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });

        window.swapBuffers();
    }

    shader.deinit();
    camera.deinit();
}
