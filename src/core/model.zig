const std = @import("std");
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const Animator = @import("animator.zig").Animator;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Model = struct {
    allocator: Allocator, 
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    animator: *Animator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, meshes: *ArrayList(*ModelMesh), animator: *Animator) !Self {
        const model = try allocator.create(Model);
        model.* = Model {
            .allocator = allocator,
            .name = try allocator.dupe(u8, name),
            .meshes = meshes,
            .animator = animator,
        };

        return model;
    }

    pub fn deinit(self: *Self) void {
        for (self.meshes.items) |mesh| {
            mesh.deinit();
        }
        self.meshes.deinit();
        self.allocator.destroy(self.meshes);
        self.allocator.free(self.name);
        self.animator.deinit();
        self.allocator.destroy(self);
    }
};

