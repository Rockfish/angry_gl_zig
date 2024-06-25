const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

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

    const exe = b.addExecutable(.{
        .name = "angry_gl_zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const math = b.createModule(.{ .root_source_file = b.path("src/math/main.zig"), });
    math.addIncludePath(b.path("src/include"));

    const core = b.createModule(.{ .root_source_file = b.path("src/core/main.zig"), });

    core.addImport("math", math);
    core.addImport("zopengl", zopengl.module("root"));
    core.addImport("assimp", assimp.module("root"));
    core.addImport("zstbi", zstbi.module("root"));
    core.linkLibrary(assimp.artifact("assimp"));
    core.linkLibrary(zstbi.artifact("zstbi"));

    exe.root_module.addImport("math", math);
    exe.root_module.addImport("core", core);
    exe.root_module.addImport("cglm", cglm.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("zopengl", zopengl.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));
    exe.linkLibrary(cglm.artifact("cglm"));
    exe.addIncludePath(b.path("src/include"));

    // b.verbose = true;

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);

    // game
    const game = b.addExecutable(.{
        .name = "angry_monsters",
        .root_source_file = b.path("game/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    game.addIncludePath(b.path("src/include"));
    game.root_module.addImport("math", math);
    game.root_module.addImport("core", core);
    game.root_module.addImport("cglm", cglm.module("root"));
    game.root_module.addImport("zglfw", zglfw.module("root"));
    game.root_module.addImport("zopengl", zopengl.module("root"));
    game.linkLibrary(zglfw.artifact("glfw"));
    game.linkLibrary(cglm.artifact("cglm"));

    const install_game = b.addInstallArtifact(game, .{});

    b.getInstallStep().dependOn(&install_game.step);
    b.step("game", "Build game").dependOn(&install_game.step);

    const run_game = b.addRunArtifact(game);
    run_game.step.dependOn(&install_game.step);

    if (b.args) |args| {
        run_game.addArgs(args);
    }

    b.step("game-run", "Run game").dependOn(&run_game.step);

    // examples/sample_animation
    const animation_example = b.addExecutable(.{
        .name = "animation_example",
        .root_source_file = b.path("examples/sample_animation/sample_animation.zig"),
        .target = target,
        .optimize = optimize,
    });

    animation_example.addIncludePath(b.path("src/include"));
    animation_example.root_module.addImport("math", math);
    animation_example.root_module.addImport("core", core);
    animation_example.root_module.addImport("cglm", cglm.module("root"));
    animation_example.root_module.addImport("zglfw", zglfw.module("root"));
    animation_example.root_module.addImport("zopengl", zopengl.module("root"));
    animation_example.linkLibrary(zglfw.artifact("glfw"));
    animation_example.linkLibrary(cglm.artifact("cglm"));

    const install_sample = b.addInstallArtifact(animation_example, .{});

    b.getInstallStep().dependOn(&install_sample.step);
    b.step("sample", "Build 'animation_example' demo").dependOn(&install_sample.step);

    const run_cmd = b.addRunArtifact(animation_example);
    run_cmd.step.dependOn(&install_sample.step);
    b.step("sample-run", "Run 'animation_example' demo").dependOn(&run_cmd.step);

    const assimp_report = b.addExecutable(.{
        .name = "assimp_report",
        .root_source_file = b.path("examples/assimp_report/assimp_report.zig"),
        .target = target,
        .optimize = optimize,
    });

    assimp_report.addIncludePath(b.path("src/include"));
    assimp_report.root_module.addImport("math", math);
    assimp_report.root_module.addImport("core", core);
    assimp_report.root_module.addImport("cglm", cglm.module("root"));
    assimp_report.root_module.addImport("zglfw", zglfw.module("root"));
    assimp_report.root_module.addImport("zopengl", zopengl.module("root"));
    assimp_report.linkLibrary(zglfw.artifact("glfw"));
    assimp_report.linkLibrary(cglm.artifact("cglm"));

    const install_assimp_report = b.addInstallArtifact(assimp_report, .{});

    b.getInstallStep().dependOn(&install_assimp_report.step);
    b.step("assimp_report", "Build 'assimp_report' demo").dependOn(&install_assimp_report.step);

    const run_assimp_report = b.addRunArtifact(assimp_report);
    run_assimp_report.step.dependOn(&install_assimp_report.step);
    b.step("assimp_report-run", "Run 'assimp_report' demo").dependOn(&run_assimp_report.step);
}

pub const Options = struct {
    optimize: std.builtin.Mode,
    target: std.Build.ResolvedTarget,
};

const examples_list = struct {
    pub const animation_example = @import("examples/sample_animation/sample_animation.zig");
};

fn buildAndInstallExamples(b: *std.Build, options: Options, comptime examples: type) void {
    inline for (comptime std.meta.declarations(examples)) |d| {
        const exe = @field(examples, d.name).build(b, options);

        if (exe.root_module.optimize == .ReleaseFast) {
            exe.root_module.strip = true;
        }

        const install_exe = b.addInstallArtifact(exe, .{});
        b.getInstallStep().dependOn(&install_exe.step);
        b.step(d.name, "Build '" ++ d.name ++ "' demo").dependOn(&install_exe.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_exe.step);
        b.step(d.name ++ "-run", "Run '" ++ d.name ++ "' demo").dependOn(&run_cmd.step);
    }
}
