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

    @import("system_sdk").addLibraryPathsTo(exe);

    exe.root_module.addImport("cglm", cglm.module("root"));
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.addImport("zopengl", zopengl.module("root"));
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    exe.root_module.addImport("assimp", assimp.module("root"));

    exe.linkLibrary(cglm.artifact("cglm"));
    exe.linkLibrary(zstbi.artifact("zstbi"));
    exe.linkLibrary(zglfw.artifact("glfw"));
    exe.linkLibrary(assimp.artifact("assimp"));

    exe.addIncludePath(.{ .path = "src/include" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);


    // const math_example = b.addExecutable(.{
    //     .name = "math_example",
    //     .root_source_file = .{ .path = "examples/math_example/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // math_example.root_module.addImport("cglm", cglm.module("root"));
    // math_example.linkLibrary(lib);
    //
    // b.installArtifact(math_example);

}

pub const Options = struct {
    optimize: std.builtin.Mode,
    target: std.Build.ResolvedTarget,
};

const examples_list = struct {
    pub const math_example = @import("examples/math_example/main.zig");
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
