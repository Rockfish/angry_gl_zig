const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const Transform = @import("transform.zig").Transform;
const NodeAnimation = @import("node_animation.zig").NodeAnimation;
const String = @import("string.zig").String;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const NodeData = struct {
    name: *String,
    transform: Transform,
    childern: *ArrayList(*NodeData),
    meshes: *ArrayList(u32),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        for (self.childern.items) |child| {
            child.deinit();
        }
        self.childern.deinit();
        self.name.deinit();
        self.meshes.deinit();
        self.allocator.destroy(self.childern);
        self.allocator.destroy(self.meshes);
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: *String) !*NodeData {
        const node_data = try allocator.create(NodeData);
        node_data.* = NodeData {
            .name = name,
            .transform = Transform.default(),
            .childern = try allocator.create(ArrayList(*NodeData)),
            .meshes = try allocator.create(ArrayList(u32)),
            .allocator = allocator,
        };
        node_data.childern.* = ArrayList(*NodeData).init(allocator);
        node_data.meshes.* = ArrayList(u32).init(allocator);
        return node_data;
    }
};

pub const BoneData = struct {
    name: *String,
    bone_index: i32,
    offset_transform: Transform,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.name.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: []const u8, id: i32, offset: zm.Mat4) !*BoneData {
        const bone_data = try allocator.create(BoneData);
        bone_data.* = BoneData{
            .name = String.new(name),
            .bone_index = id,
            .offset_transform = Transform.from_matrix(offset),
            .allocator = allocator,
        };

        return bone_data;
    }
};

pub const ModelAnimation = struct {
    duration: f32,
    ticks_per_second: f32,
    node_animations: *ArrayList(*NodeAnimation),
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
            const node_animation = try NodeAnimation.new(allocator, channel[0].mNodeName, channel);
            try model_animation.node_animations.append(node_animation);
        }

        // std.debug.print("NodeAnimation[0] position[0] = {any}\n", .{model_animation.node_animations.items[0].positions.items[0]});
        // std.debug.print("NodeAnimation[0] rotations[0] = {any}\n", .{model_animation.node_animations.items[0].rotations.items[0]});
        // std.debug.print("NodeAnimation[0] scales[0] = {any}\n", .{model_animation.node_animations.items[0].scales.items[0]});

        return model_animation;
    }
};
