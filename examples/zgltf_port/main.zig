const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const glftReport = @import("gltf_report.zig").gltfReport;
const run_animation = @import("run_animation.zig").run;

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

    const model_paths = [_][]const u8 {
        "/Users/john/Dev/Zig/Repos/zgltf/test-samples/rigged_simple/RiggedSimple.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/BoxVertexColors/glTF/BoxVertexColors.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/BoxTextured/glTF/BoxTextured.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/CesiumMan/glTF/CesiumMan.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/BrainStem/glTF/BrainStem.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/StainedGlassLamp/glTF/StainedGlassLamp.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/WalkingLady/glTF/WalkingLady.gltf",
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/glTF/Spacesuit.gltf",
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/glTF/Adventurer.gltf",
        "/Users/john/Dev/Assets/astronaut_character/astronaut_game_character_animated/scene.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/CesiumMan/glTF-Binary/CesiumMan.glb", // trouble with embedded texture
        "/Users/john/spacesuit_blender_export.glb",
    };

    // try run_app(allocator, window);
    // try glftReport(model_paths[4]);
    try run_animation(allocator, window, model_paths[4]);

    glfw.terminate();
}


