const std = @import("std");
const ModelMesh = @import("model_mesh.zig").ModelMesh;
const animation = @import("animator.zig");
const AnimationClip = @import("animator.zig").AnimationClip;
const Shader = @import("shader.zig").Shader;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Animator = animation.Animator;
const WeightedAnimation = animation.WeightedAnimation;

const MAX_BONES = animation.MAX_BONES;
const MAX_NODES = animation.MAX_NODES;

pub const Model = struct {
    allocator: Allocator,
    name: []const u8,
    meshes: *ArrayList(*ModelMesh),
    animator: *Animator,
    single_mesh_select: i32 = -1,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, meshes: *ArrayList(*ModelMesh), animator: *Animator) !Self {
        const model = try allocator.create(Model);
        model.* = Model{
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

    pub fn playClip(self: *Self, clip: AnimationClip) !void {
        try self.animator.playClip(clip);
    }

    pub fn playTick(self: *Self, tick: f32) !void {
        try self.animator.playTick(tick);
    }

    pub fn playClipWithTransition(self: *Self, clip: AnimationClip, transition_duration: f32) !void {
        try self.animator.playClipWithTransition(clip, transition_duration);
    }

    pub fn playWeightAnimations(self: *Self, weighted_animation: []const WeightedAnimation, frame_time: f32) !void {
        try self.animator.playWeightAnimations(weighted_animation, frame_time);
    }

    pub fn render(self: *Self, shader: *const Shader) void {
        shader.useShader();
        var buf: [256:0]u8 = undefined;

        for (0..MAX_BONES) |i| {
            const bone_transform = self.animator.final_bone_matrices[i];
            const uniform = std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i}) catch unreachable;
            shader.setMat4(uniform, &bone_transform);
        }

        for (self.meshes.items, 0..) |mesh,n| {
            if (self.single_mesh_select != -1 and @as(usize, @intCast(self.single_mesh_select)) != n) {
                continue;
            }

            shader.setInt("mesh_id", mesh.id);
            shader.setMat4("nodeTransform", &self.animator.final_node_matrices[@intCast(mesh.id)]);
            mesh.render(shader);
        }
    }

    pub fn setShaderBonesForMesh(self: *Self, shader: *const Shader, mesh: *ModelMesh) !void {
        var buf: [256:0]u8 = undefined;

        for (0..MAX_BONES) |i| {
            const bone_transform = self.animator.final_bone_matrices[i];
            const uniform = try std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i});
            shader.setMat4(uniform, &bone_transform);
        }
        shader.setMat4("nodeTransform", &self.animator.final_node_matrices[@intCast(mesh.id)]);
    }

    pub fn updateAnimation(self: *Self, delta_time: f32) !void {
        try self.animator.updateAnimation(delta_time);
    }
};

pub fn dumpModelNodes(model: *Model) !void {
    std.debug.print("\n--- Dumping nodes ---\n", .{});
    var buf: [1024:0]u8 = undefined;

    var node_iterator = model.animator.node_transform_map.iterator();
    while (node_iterator.next()) |entry| { // |node_name, node_transform| {
        const name = entry.key_ptr.*;
        const transform = entry.value_ptr.*;
        const str = transform.transform.asString(&buf);
        std.debug.print("node_name: {s} : {s}\n", .{name, str});
    }
    std.debug.print("\n", .{});

    var bone_iterator = model.animator.bone_map.iterator();
    while (bone_iterator.next()) |entry| { // |node_name, node_transform| {
        const name = entry.key_ptr.*;
        const transform = entry.value_ptr.*;
        const str = transform.offset_transform.asString(&buf);
        std.debug.print("bone_name: {s} : {s}\n", .{name, str});
    }
}
