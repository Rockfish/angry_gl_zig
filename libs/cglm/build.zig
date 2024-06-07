const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add cglm source files
    const cglm_sources = &[_][]const u8{
        "src/aabb2d.c",
        "src/affine.c",
        "src/affine2d.c",
        "src/bezier.c",
        "src/box.c",
        "src/cam.c",
        "src/clipspace/ortho_lh_no.c",
        "src/clipspace/ortho_lh_zo.c",
        "src/clipspace/ortho_rh_no.c",
        "src/clipspace/ortho_rh_zo.c",
        "src/clipspace/persp_lh_no.c",
        "src/clipspace/persp_lh_zo.c",
        "src/clipspace/persp_rh_no.c",
        "src/clipspace/persp_rh_zo.c",
        "src/clipspace/project_no.c",
        "src/clipspace/project_zo.c",
        "src/clipspace/view_lh_no.c",
        "src/clipspace/view_lh_zo.c",
        "src/clipspace/view_rh_no.c",
        "src/clipspace/view_rh_zo.c",
        "src/curve.c",
        "src/ease.c",
        "src/euler.c",
        "src/frustum.c",
        "src/io.c",
        "src/ivec2.c",
        "src/ivec3.c",
        "src/ivec4.c",
        "src/mat2.c",
        "src/mat2x3.c",
        "src/mat2x4.c",
        "src/mat3.c",
        "src/mat3x2.c",
        "src/mat3x4.c",
        "src/mat4.c",
        "src/mat4x2.c",
        "src/mat4x3.c",
        "src/plane.c",
        "src/project.c",
        "src/quat.c",
        "src/ray.c",
        "src/sphere.c",
        "src/swift/empty.c",
        "src/vec2.c",
        "src/vec3.c",
        "src/vec4.c",
    };

    const lib = b.addStaticLibrary(.{
        .name = "cglm",
        .optimize = optimize,
        .target = target,
    });

    lib.addIncludePath(.{ .path = "include" });

    lib.addCSourceFiles(.{
        .root = .{ .path = "" },
        .files = cglm_sources,
        .flags = &.{ "-DCGLM_STATIC=ON" },
    });

    lib.installHeadersDirectory(.{.path = "include" }, "", .{ .include_extensions = &.{ ".h", } });

    _ = b.addModule("root", .{
        .root_source_file = .{ .path = "src/cglm.zig" },
    });

    b.installArtifact(lib);
}
