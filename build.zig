const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    const zopengl = b.dependency("zopengl", .{
        .target = target,
        .optimize = optimize,
    });

    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    const formats: []const u8 = "Obj,Collada,FBX";

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
        .{
            .name = "main",
            .exe_name = "core_main",
            .source = "src/main.zig",
        },
        .{
            .name = "game",
            .exe_name = "angry_monsters",
            .source = "game/main.zig",
        },
        .{
            .name = "animation",
            .exe_name = "animation_example",
            .source = "examples/sample_animation/sample_animation.zig",
        },
        .{
            .name = "assimp_report",
            .exe_name = "assimp_report",
            .source = "examples/assimp_report/assimp_report.zig",
        },
        .{
            .name = "textures",
            .exe_name = "texture_example",
            .source = "examples/4_1-textures/main.zig",
        },
        .{
            .name = "bullets",
            .exe_name = "bullets_example",
            .source = "examples/bullets/main.zig",
        },
        .{
            .name = "audio",
            .exe_name = "audio_example",
            .source = "examples/audio/main.zig",
        },
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
        exe.linkLibrary(miniaudio.artifact("miniaudio"));
        exe.linkLibrary(zglfw.artifact("glfw"));
        exe.linkLibrary(cglm.artifact("cglm"));
        exe.addIncludePath(b.path("src/include"));
        exe.addIncludePath(miniaudio.path("include"));

        // b.verbose = true;

        const install_exe = b.addInstallArtifact(exe, .{});

        b.getInstallStep().dependOn(&install_exe.step);
        b.step(app.name, "Build '" ++ app.name ++ "' app").dependOn(&install_exe.step);

        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);

        if (b.args) |args| {
            run_exe.addArgs(args);
        }

        b.step(app.name ++ "-run", "Run '" ++ app.name ++ "' app").dependOn(&run_exe.step);
    }
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
