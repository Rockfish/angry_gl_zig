const std = @import("std");
const math = @import("math");
const Assimp = @import("assimp.zig").Assimp;
const Transform = @import("transform.zig").Transform;
const ModelNodeAnimation = @import("model_node_animation.zig").ModelNodeAnimation;
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
        node.* = ModelNode {
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
        bone.* = ModelBone {
            .bone_name = String.new(name),
            .bone_index = id,
            .offset_transform = Transform.from_matrix(offset),
            .allocator = allocator,
        };

        return bone;
    }
};

pub const ModelAnimation = struct {
    duration: f32,
    ticks_per_second: f32,
    node_animations: *ArrayList(*ModelNodeAnimation),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        for (self.node_animations.items) |node_animation| {
            node_animation.deinit();
        }
        self.node_animations.deinit();
        self.allocator.destroy(self.node_animations);
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, aiScene: [*c]const Assimp.aiScene) !*Self {
        const node_animations = try allocator.create(ArrayList(*ModelNodeAnimation));
        node_animations.* = ArrayList(*ModelNodeAnimation).init(allocator);

        const model_animation = try allocator.create(ModelAnimation);
        model_animation.* = .{
            .duration = 0.0,
            .ticks_per_second = 0.0,
            .node_animations = node_animations,
            .allocator = allocator,
        };

        const num_animations = aiScene.*.mNumAnimations;
        if (num_animations == 0) {
            return model_animation;
        }

        // only handling the first animation
        const animation = aiScene.*.mAnimations[0..num_animations][0];
        model_animation.*.duration = @as(f32, @floatCast(animation.*.mDuration));
        model_animation.*.ticks_per_second = @as(f32, @floatCast(animation.*.mTicksPerSecond));

        const num_channels = animation.*.mNumChannels;

        for (animation.*.mChannels[0..num_channels]) |channel| {
            const node_animation = try ModelNodeAnimation.new(allocator, channel.*.mNodeName, channel);
            try model_animation.node_animations.append(node_animation);
        }

        return model_animation;
    }
};
