const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const run_app = @import("run_app.zig").run;
const run_animation = @import("test_animation.zig").run;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

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

    // _ = window.setKeyCallback(keyHandler);
    // _ = window.setFramebufferSizeCallback(framebufferSizeHandler);
    // _ = window.setCursorPosCallback(cursorPositionHandler);
    // _ = window.setScrollCallback(scrollHandler);
    // _ = window.setMouseButtonCallback(mouseHandler);
    // window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
 
    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);
    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    // try run_app(allocator, window);
    try run_animation(allocator, window);

    glfw.terminate();
}


