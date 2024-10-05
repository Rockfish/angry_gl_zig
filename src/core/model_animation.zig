const std = @import("std");
const math = @import("math");
const Assimp = @import("assimp.zig").Assimp;
const Transform = @import("transform.zig").Transform;
const NodeAnimation = @import("model_node_animation.zig").NodeAnimation;
const String = @import("string.zig").String;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Mat4 = math.Mat4;

pub const ModelNode = struct {
    node_name: *String,
    transform: Transform,
    childern: *ArrayList(*ModelNode),
    meshes: *ArrayList(u32),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        for (self.childern.items) |child| {
            child.deinit();
        }
        self.childern.deinit();
        self.node_name.deinit();
        self.meshes.deinit();
        self.allocator.destroy(self.childern);
        self.allocator.destroy(self.meshes);
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: *String) !*ModelNode {
        const node = try allocator.create(ModelNode);
        node.* = ModelNode{
            .node_name = name,
            .transform = Transform.default(),
            .childern = try allocator.create(ArrayList(*ModelNode)),
            .meshes = try allocator.create(ArrayList(u32)),
            .allocator = allocator,
        };
        node.childern.* = ArrayList(*ModelNode).init(allocator);
        node.meshes.* = ArrayList(u32).init(allocator);
        return node;
    }
};

pub const ModelBone = struct {
    bone_name: *String,
    bone_index: i32,
    offset_transform: Transform,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.bone_name.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: []const u8, id: i32, offset: Mat4) !*ModelBone {
        const bone = try allocator.create(ModelBone);
        bone.* = ModelBone{
            .bone_name = String.new(name),
            .bone_index = id,
            .offset_transform = Transform.from_matrix(offset),
            .allocator = allocator,
        };

        return bone;
    }
};

pub const ModelAnimation = struct {
    animation_name: *String,
    duration: f32,
    ticks_per_second: f32,
    node_animations: *ArrayList(*NodeAnimation),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.animation_name.deinit();
        for (self.node_animations.items) |node_animation| {
            node_animation.deinit();
        }
        self.node_animations.deinit();
        self.allocator.destroy(self.node_animations);
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: Assimp.aiString) !*Self {
        const node_animations = try allocator.create(ArrayList(*NodeAnimation));
        node_animations.* = ArrayList(*NodeAnimation).init(allocator);

        const animation = try allocator.create(ModelAnimation);
        animation.* = .{
            .animation_name = try String.from_aiString(name),
            .duration = 0.0,
            .ticks_per_second = 0.0,
            .node_animations = node_animations,
            .allocator = allocator,
        };
        return animation;
    }
};

pub fn getAnimations(allocator: Allocator, aiScene: [*c]const Assimp.aiScene) !*ArrayList(*ModelAnimation) {
    const animations = try allocator.create(ArrayList(*ModelAnimation));
    animations.* = ArrayList(*ModelAnimation).init(allocator);

    const num_animations = aiScene.*.mNumAnimations;

    for (aiScene.*.mAnimations[0..num_animations]) |ai_animation| {
        const animation = try ModelAnimation.init(allocator, ai_animation.*.mName);
        animation.*.duration = @as(f32, @floatCast(ai_animation.*.mDuration));
        animation.*.ticks_per_second = @as(f32, @floatCast(ai_animation.*.mTicksPerSecond));

        const num_channels = ai_animation.*.mNumChannels;

        for (ai_animation.*.mChannels[0..num_channels]) |channel| {
            const node_animation = try NodeAnimation.init(allocator, channel.*.mNodeName, channel);
            try animation.node_animations.append(node_animation);
        }

        std.debug.print("Loaded animation:\n", .{});
        std.debug.print("   name    : {s}\n", .{animation.animation_name.str});
        std.debug.print("   duration: {d}\n", .{animation.duration});
        std.debug.print("   node_animations length: {d}\n", .{animation.node_animations.items.len});
    }

    return animations;
}
