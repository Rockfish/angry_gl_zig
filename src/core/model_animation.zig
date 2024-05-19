const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const Transform = @import("transform.zig").Transform;
const NodeAnimation = @import("node_animation.zig").NodeAnimation;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const NodeData = struct {
    name: []const u8,
    transform: Transform,
    childern: ArrayList(*NodeData),
    meshes: ArrayList(u32),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8) !*NodeData {
        const node_data = try allocator.create(BoneData);
        node_data.* = NodeData{
            .name = try allocator.dupe(u8, name),
            .transform = Transform.from_matrix(), // todo: from what matrix?
            .childern = ArrayList(*NodeData).init(allocator),
            .meshes = ArrayList(u32).init(allocator),
            .allocator = allocator,
        };
        return node_data;
    }

    pub fn deinit(self: *Self) void {
        for (self.chidern) |child| {
            child.deinit();
        }
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }
};

pub const BoneData = struct {
    name: []const u8,
    bone_index: i32,
    offset_transform: Transform,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, id: i32, offset: zm.Mat4) !*BoneData {
        const bone_data = try allocator.create(BoneData);
        bone_data.* = BoneData{
            .name = try allocator.dupe(u8, name),
            .bone_index = id,
            .offset_transform = Transform.from_matrix(offset),
            .allocator = allocator,
        };

        return bone_data;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.allocator.destroy(self);
    }
};

pub const ModelAnimation = struct {
    duration: f32,
    ticks_per_second: f32,
    node_animations: *ArrayList(*NodeAnimation),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, aiScene: [*c]const Assimp.aiScene) !*Self {
        const node_animations = try allocator.create(ArrayList(*NodeAnimation));
        node_animations.* = ArrayList(*NodeAnimation).init(allocator);

        const model_animation = try allocator.create(ModelAnimation);
        model_animation.* = .{
            .duration = 0.0,
            .ticks_per_second = 0.0,
            .node_animations = node_animations,
            .allocator = allocator,
        };

        const num_animations = aiScene[0].mNumAnimations;
        if (num_animations == 0) {
            return model_animation;
        }

        // only handling the first animation
        const animation = aiScene[0].mAnimations[0..num_animations][0];
        model_animation.*.duration = @as(f32, @floatCast(animation.*.mDuration));
        model_animation.*.ticks_per_second = @as(f32, @floatCast(animation.*.mTicksPerSecond));

        const num_channels = animation.*.mNumChannels;
        for (animation.*.mChannels[0..num_channels]) |channel| {
            const name = channel[0].mNodeName.data[0..channel[0].mNodeName.length];
            const node_animation = try NodeAnimation.new(allocator, name, channel);
            try model_animation.node_animations.append(node_animation);
        }

        return model_animation;
    }

    pub fn deinit(self: *Self) void {
        for (self.node_animations.items) |node_animation| {
            node_animation.deinit();
        }
        self.node_animations.deinit();
        self.allocator.destroy(self.node_animations);
        self.allocator.destroy(self);
    }
};
