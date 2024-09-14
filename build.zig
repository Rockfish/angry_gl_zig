const std = @import("std");

const content_dir = "assets/";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // b.verbose = true;

    const miniaudio = b.dependency("miniaudio", .{
        .target = target,
        .optimize = optimize,
    });

    const miniaudiolib = miniaudio.artifact("miniaudio");
    miniaudiolib.addIncludePath(miniaudio.path("include"));
    b.installArtifact(miniaudiolib);

    const cglm = b.dependency("cglm", .{
        .target = target,
        .optimize = optimize,
    });

    const cglmlib = cglm.artifact("cglm");
    cglmlib.addIncludePath(cglm.path("include"));
    b.installArtifact(cglmlib);

    const tomlz = b.dependency("tomlz", .{
        .target = target,
        .optimize = optimize,
    });

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zopengl = b.dependency("zopengl", .{
        .target = target,
        .optimize = optimize,
    });

    const zgui = b.dependency("zgui", .{
        .target = target,
        .optimize = optimize,
        .backend = .glfw_opengl3,
        .with_te = true,
        .shared = false,
    });

    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    // Supported formats:
    // 3DS, 3MF, AC, AMF, ASE, Assbin, Assjson, Assxml, B3D, Blend, BVH, COB, Collada, CSM, DXF, FBX,
    // glTF, glTF2, HMP, IFC, Irr, IrrMesh, IQM, LWO, LWS, M3D, MD2, MD3, MD5, MDC, MDL, MMD, MS3D, NDO,
    // NFF, Obj, OFF, Ogre, OpenGEX, Ply, Q3BSP, Q3D, Raw, SIB, SMD, Step, STEPParser, STL, Terragen, 3D, X, X3D, XGL

    const formats: []const u8 = "Obj,Collada,FBX,glTF,MD2"; // B3D";

    const assimp = b.dependency("assimp", .{
        .target = target,
        .optimize = optimize,
        .formats = formats,
    });

    const lib = assimp.artifact("assimp");
    lib.addIncludePath(assimp.path("include"));
    b.installArtifact(lib);

    const math = b.createModule(.{
        .root_source_file = b.path("src/math/main.zig"),
    });
    math.addIncludePath(b.path("src/include"));

    const core = b.createModule(.{
        .root_source_file = b.path("src/core/main.zig"),
    });

    core.addImport("math", math);
    core.addImport("zopengl", zopengl.module("root"));
    core.addImport("zgui", zgui.module("root"));
    core.addImport("assimp", assimp.module("root"));
    core.addImport("zstbi", zstbi.module("root"));
    core.addImport("miniaudio", miniaudio.module("root"));

    core.linkLibrary(assimp.artifact("assimp"));
    core.linkLibrary(zstbi.artifact("zstbi"));

    inline for ([_]struct {
        name: []const u8,
        exe_name: []const u8,
        source: []const u8,
    }{
        .{ .name = "main", .exe_name = "core_main", .source = "src/main.zig" },
        .{ .name = "game_angrybot", .exe_name = "angry_monsters", .source = "game_angrybot/main.zig" },
        .{ .name = "animation", .exe_name = "animation_example", .source = "examples/sample_animation/sample_animation.zig" },
        .{ .name = "assimp_report", .exe_name = "assimp_report", .source = "examples/assimp_report/assimp_report.zig" },
        .{ .name = "bullets", .exe_name = "bullets_example", .source = "examples/bullets/main.zig" },
        .{ .name = "audio", .exe_name = "audio_example", .source = "examples/audio/main.zig" },
        .{ .name = "gui_settings", .exe_name = "gui_example", .source = "examples/gui_settings/gui_settings.zig" },
        .{ .name = "skybox", .exe_name = "skybox_example", .source = "examples/skybox/main.zig" },
        .{ .name = "picker", .exe_name = "picker_example", .source = "examples/picker/main.zig" },
        .{ .name = "ray_selection", .exe_name = "ray_selection_example", .source = "examples/ray_selection/main.zig" },
        .{ .name = "scene_tree", .exe_name = "scene_tree_example", .source = "examples/scene_tree/main.zig" },
        .{ .name = "game_level_001", .exe_name = "angry_monsters", .source = "game_level_001/main.zig" },
    }) |app| {
        const exe = b.addExecutable(.{
            .name = app.exe_name,
            .root_source_file = b.path(app.source),
            .target = target,
            .optimize = optimize,
        });

        if (exe.root_module.optimize == .ReleaseFast) {
            exe.root_module.strip = true;
        }

        exe.root_module.addImport("math", math);
        exe.root_module.addImport("core", core);
        exe.root_module.addImport("cglm", cglm.module("root"));
        exe.root_module.addImport("miniaudio", miniaudio.module("root"));
        exe.root_module.addImport("zglfw", zglfw.module("root"));
        exe.root_module.addImport("zopengl", zopengl.module("root"));
        exe.root_module.addImport("zgui", zgui.module("root"));
        exe.root_module.addImport("zstbi", zstbi.module("root")); // gui
        exe.root_module.addImport("tomlz", tomlz.module("tomlz"));

        exe.addIncludePath(b.path("src/include"));
        exe.addIncludePath(miniaudio.path("include"));

        exe.linkLibrary(zgui.artifact("imgui"));
        exe.linkLibrary(zglfw.artifact("glfw"));
        exe.linkLibrary(cglm.artifact("cglm"));
        exe.linkLibrary(miniaudio.artifact("miniaudio"));

        const install_exe = b.addInstallArtifact(exe, .{});

        b.getInstallStep().dependOn(&install_exe.step);
        b.step(app.name, "Build '" ++ app.name ++ "' app").dependOn(&install_exe.step);

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);

        if (b.args) |args| {
            run_exe.addArgs(args);
        }

        b.step(app.name ++ "-run", "Run '" ++ app.name ++ "' app").dependOn(&run_exe.step);

        const exe_options = b.addOptions();
        exe.root_module.addOptions("build_options", exe_options);
        exe_options.addOption([]const u8, "content_dir", content_dir);

        const install_content_step = b.addInstallDirectory(.{
            .source_dir = b.path(content_dir),
            .install_dir = .{ .custom = "" },
            .install_subdir = "bin/" ++ content_dir,
        });

        run_exe.step.dependOn(&install_content_step.step);
    }

    // extra check step for the game for better zls
    // See https://kristoff.it/blog/improving-your-zls-experience/
    const exe_check = b.addExecutable(.{
        .name = "angry_monsters",
        .root_source_file = b.path("game/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_check.root_module.addImport("math", math);
    exe_check.root_module.addImport("core", core);
    exe_check.root_module.addImport("cglm", cglm.module("root"));
    exe_check.root_module.addImport("miniaudio", miniaudio.module("root"));
    exe_check.root_module.addImport("zglfw", zglfw.module("root"));
    exe_check.root_module.addImport("zopengl", zopengl.module("root"));
    exe_check.linkLibrary(miniaudio.artifact("miniaudio"));
    exe_check.linkLibrary(zglfw.artifact("glfw"));
    exe_check.linkLibrary(cglm.artifact("cglm"));
    exe_check.addIncludePath(b.path("src/include"));
    exe_check.addIncludePath(miniaudio.path("include"));

    const check = b.step("check", "Check if game compiles");
    check.dependOn(&exe_check.step);
}

pub const Options = struct {
    optimize: std.builtin.Mode,
    target: std.Build.ResolvedTarget,
};

// const examples_list = struct {
//     pub const animation_example = @import("examples/sample_animation/sample_animation.zig");
// };
//
// fn buildAndInstallExamples(b: *std.Build, options: Options, comptime examples: type) void {
//     inline for (comptime std.meta.declarations(examples)) |d| {
//         // const exe = @field(examples, d.name).build(b, options);
//
//         // if (exe.root_module.optimize == .ReleaseFast) {
//         //     exe.root_module.strip = true;
//         // }
//         const target = b.standardTargetOptions(.{});
//         const optimize = b.standardOptimizeOption(.{});
//
//         const assimp_report = b.addExecutable(.{
//             .name = "assimp_report",
//             .root_source_file = b.path("examples/assimp_report/assimp_report.zig"),
//             .target = target,
//             .optimize = optimize,
//         });
//
//         assimp_report.addIncludePath(b.path("src/include"));
//         assimp_report.root_module.addImport("math", math);
//         assimp_report.root_module.addImport("core", core);
//         assimp_report.root_module.addImport("cglm", cglm.module("root"));
//         assimp_report.root_module.addImport("zglfw", zglfw.module("root"));
//         assimp_report.root_module.addImport("zopengl", zopengl.module("root"));
//         assimp_report.linkLibrary(zglfw.artifact("glfw"));
//         assimp_report.linkLibrary(cglm.artifact("cglm"));
//
//         const install_exe = b.addInstallArtifact(exe, .{});
//
//         b.getInstallStep().dependOn(&install_exe.step);
//         b.step(d.name, "Build '" ++ d.name ++ "' example").dependOn(&install_exe.step);
//
//         const run_cmd = b.addRunArtifact(exe);
//         run_cmd.step.dependOn(&install_exe.step);
//         b.step(d.name ++ "-run", "Run '" ++ d.name ++ "' example").dependOn(&run_cmd.step);
//     }
// }
