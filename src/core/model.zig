const std = @import("std");
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Animator = @import("animator.zig").Animator;

pub const Model = struct {
    allocator: std.mem.Allocator, 
    name: []const u8,
    meshes: std.ArrayList(*ModelMesh),
    animator: Animator,

    const Self = @This();


    pub fn deinit(self: *Self) void {
        for (self.meshes.items) |mesh| {
            mesh.deinit();
        }
        // self.animator.deinit();
        // self.allocator.destroy(self.animator); ?
        self.meshes.deinit();
        self.allocator.destroy(self);
    }
};

