const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add cglm source files
    const sources = &[_][]const u8{
        "src/miniaudio.c",
    };

    const lib = b.addStaticLibrary(.{
        .name = "miniaudio",
        .optimize = optimize,
        .target = target,
    });

    lib.addCSourceFiles(.{
        .root = b.path(""),
        .files = sources,
        .flags = &.{"-fno-sanitize=undefined"},
    });

    const mod = b.addModule("root", .{
        .root_source_file = b.path("src/miniaudio.zig"),
    });

    mod.addIncludePath(b.path("include"));

    lib.addIncludePath(b.path("include"));

    lib.installHeadersDirectory(
        b.path("include"),
        "",
        .{ .include_extensions = &.{ ".h", } },
    );

    // b.verbose = true;

    b.installArtifact(lib);
}
