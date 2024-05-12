const std = @import("std");
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Animator = @import("animator.zig").Animator;

pub const Model = struct {
    name: []const u8,
    meshes: std.ArrayList(ModelMesh),
    animator: Animator,
};

