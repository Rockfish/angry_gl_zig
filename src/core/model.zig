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

    pub fn play_clip_with_transition(self: *Self, clip: AnimationClip, transition_duration: f32) !void {
        try self.animator.play_clip_with_transition(clip, transition_duration);
    }

    pub fn play_weight_animations(self: *Self, weighted_animation: []const WeightedAnimation, frame_time: f32) !void {
        try self.animator.play_weight_animations(weighted_animation, frame_time);
    }

    pub fn render(self: *Self, shader: *const Shader) !void {
        var buf: [256:0]u8 = undefined;

        // for (i, bone_transform) in final_bones.iter().enumerate() {
        for (0..MAX_BONES) |i| {
            const bone_transform = self.animator.final_bone_matrices[i];
            const uniform = try std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i});
            // std.debug.print("{s} = {any}\n", .{ uniform, bone_transform });
            shader.set_mat4(uniform, &bone_transform);
        }

        for (self.meshes.items) |mesh| {
            shader.set_mat4("nodeTransform", &self.animator.final_node_matrices[@intCast(mesh.id)]);
            // std.debug.print("mesh name = {s}  nodeTransform = {any}\n", .{mesh.name, self.animator.final_node_matrices[@intCast(mesh.id)]});
            mesh.render(shader);
        }

        // std.debug.print("Model render done.\n",.{});
    }

    pub fn set_shader_bones_for_mesh(self: *Self, shader: *const Shader, mesh: *ModelMesh) !void {
        var buf: [256:0]u8 = undefined;
        const final_bones = self.animator.final_bone_matrices.borrow();
        const final_nodes = self.animator.final_node_matrices.borrow();

        for (0..MAX_BONES) |i| {
            const bone_transform = final_bones[i];
            const uniform = try std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i});
            shader.set_mat4(uniform, &bone_transform);
        }
        shader.set_mat4("nodeTransform", &final_nodes[@intCast(mesh.id)]);
    }

    pub fn update_animation(self: *Self, delta_time: f32) !void {
        try self.animator.update_animation(delta_time);
    }
};
