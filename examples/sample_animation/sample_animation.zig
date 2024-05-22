const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zm = @import("zmath");
const zstbi = @import("zstbi");
const Model = @import("../src/core/model_mesh.zig");
const ModelBuilder = @import("../src/core/model_builder.zig").ModelBuilder;
const gl = @import("zopengl").bindings;
const String = @import("../src/core/string.zig");
const Camera = @import("../src/core/camera.zig").Camera;

const SCR_WIDTH: f32 = 800.0;
const SCR_HEIGHT: f32 = 800.0;

// Lighting
const LIGHT_FACTOR: f32 = 1.0;
const NON_BLUE: f32 = 0.9;

const FLOOR_LIGHT_FACTOR: f32 = 0.35;
const FLOOR_NON_BLUE: f32 = 0.7;

// Struct for passing state between the window loop and the event handler.
const State = struct {
    camera: Camera,
    lightPos: zm.Vec3,
    deltaTime: f32,
    lastFrame: f32,
    firstMouse: bool,
    lastX: f32,
    lastY: f32,
};

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


    // run(allocator, window);
}