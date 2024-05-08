const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

pub fn main() !void {
    loadTest();

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

    const window = try glfw.Window.create(600, 600, "zig-gamedev: minimal_glfw_gl", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    const gl = zopengl.bindings;

    glfw.swapInterval(1);

    while (!window.shouldClose()) {
        glfw.pollEvents();
        if (window.getKey(glfw.Key.escape) == glfw.Action.press) {
            window.setShouldClose(true);
        }

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.6, 0.4, 1.0 });

        window.swapBuffers();
    }
}

pub fn loadTest() void {
    const file = "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/vampire/dancing_vampire.dae";
    // const file = "/Users/john/Dev/Dev_Rust/russimp_glam/models/OBJ/cube.obj";

    std.debug.print("Zig example\nLoading model: {s}\n", .{file});

    const aiScene = assimp.aiImportFile(file, assimp.aiProcess_CalcTangentSpace |
        assimp.aiProcess_Triangulate |
        assimp.aiProcess_JoinIdenticalVertices |
        assimp.aiProcess_SortByPType);

    if (aiScene != null) {
        // std.debug.print("name: {s}\n", .{aiScene[0].mName.data});
        std.debug.print("number of meshes: {d}\n", .{aiScene[0].mNumMeshes});
        std.debug.print("number of materials: {d}\n", .{aiScene[0].mNumMaterials});
        std.debug.print("number of mNumTextures: {d}\n", .{aiScene[0].mNumTextures});
        std.debug.print("number of mNumAnimations: {d}\n", .{aiScene[0].mNumAnimations});
        std.debug.print("number of mNumLights: {d}\n", .{aiScene[0].mNumLights});
        std.debug.print("number of mNumCameras: {d}\n", .{aiScene[0].mNumCameras});
        std.debug.print("number of mNumSkeletons: {d}\n", .{aiScene[0].mNumSkeletons});
    } else {
        std.debug.print("aiScene is null.\n", .{});
        const error_string = assimp.aiGetErrorString();
        std.debug.print("Import error: {s}\n", .{error_string});
    }

    var ai_string = assimp.aiString{};
    assimp.aiGetExtensionList(&ai_string);

    var ext_data = ai_string.data;
    std.debug.print("Extensions:\n{s}\n\n", .{ext_data});

    var buffer_storage: [20]u8 = undefined;
    var buffer: []u8 = buffer_storage[0..];

    const last = std.mem.indexOf(u8, &ext_data, &[1]u8{0}) orelse 10;
    var iter = std.mem.split(u8, ext_data[0..last], ";");

    while (iter.next()) |ext| {
        const c_str = sliceToCString(&buffer, ext[2..ext.len]);
        const description = assimp.aiGetImporterDesc(c_str);

        if (description != null) {
            std.debug.print("  {s} : {s}\n", .{ c_str, description[0].mName });
        } else {
            std.debug.print("  {s} : no description\n", .{c_str});
        }
    }

    assimp.aiReleaseImport(aiScene);
}

fn sliceToCString(buffer: *[]u8, slice: []const u8) [*c]u8 {
    std.mem.copyForwards(u8, buffer.*, slice);
    buffer.*[slice.len] = 0;
    return buffer.ptr;
}
