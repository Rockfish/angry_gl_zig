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
            .transform = Transform.from_matrix(),
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
    node_animations: ArrayList(*NodeAnimation),

    const Self = @This();

    pub fn init(allocator: Allocator, aiScene: Assimp.aiScene) !*Self {

        _ = aiScene;

        const model_animation = try allocator.create(ModelAnimation);
        model_animation.* = ModelAnimation{
            .duration = 0,
            .ticks_per_second = 0,
            .node_animations = ArrayList(*NodeData).init(allocator),
        };
        return model_animation;
    }
};
