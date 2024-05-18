const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const zstbi = @import("zstbi");
const Assimp = @import("core/assimp.zig");
const Model = @import("core/model_mesh.zig");
const ModelBuilder = @import("core/model_builder.zig").ModelBuilder;

const Texture = @import("core/texture.zig").Texture;

const content_dir = "angrygl_assets";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

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

    try builderTest(allocator);

    // run(arena, window);
    _ = arena;
}

pub fn run(arena: std.mem.Allocator, window: *glfw.Window) !void {
    _ = arena;

    // --- event loop
    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });

        window.swapBuffers();
    }
}

pub fn builderTest(allocator: std.mem.Allocator) !void {
    var texture_cache = std.ArrayList(*Texture).init(allocator);
    const file = "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/vampire/dancing_vampire.dae";

    var builder = try ModelBuilder.init(allocator, &texture_cache, "Player", file);

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
