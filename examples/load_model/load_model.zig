const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const assimp = @import("../src/core/assimp.zip");
const Model = @import("../src/core/model_mesh.zig");
const ModelBuilder = @import("../src/core/model_builder.zig").ModelBuilder;
const gl = @import("zopengl").bindings;

// const texture = @import("core/texture.zig");
const Texture = @import("core/texture.zig").Texture;

pub fn loadModelTest() void {
    // const file = "assets/Models/Player/Player.fbx";
    const file = "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/vampire/dancing_vampire.dae";

    std.debug.print("\nZig example with math\nLoading model: {s}\n", .{file});

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
