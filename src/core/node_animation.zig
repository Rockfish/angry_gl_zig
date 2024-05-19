const std = @import("std");
const zm = @import("zmath");
// const gl = @import("zopengl").bindings;
// const Texture = @import("texture.zig").Texture;
// const ModelVertex = @import("model_mesh.zig").ModelVertex;
// const ModelMesh = @import("model_mesh.zig").ModelMesh;
// const Model = @import("model.zig").Model;
// const Animator = @import("animator.zig").Animator;
const Assimp = @import("assimp.zig").Assimp;
const Utils = @import("utils.zig");
// const BoneData = @import("model_animation.zig").BoneData;


const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
// const StringHashMap = std.StringHashMap;

pub const KeyPosition = struct {
    position: zm.Vec3,
    time_stamp: f32,
};

pub const KeyRotation = struct {
    orientation: zm.Quat,
    time_stamp: f32,
};

pub const KeyScale = struct {
    scale: zm.Vec3,
    time_stamp: f32,
};

pub const NodeAnimation = struct {
    name: []const u8,
    positions: *ArrayList(KeyPosition),
    rotations: *ArrayList(KeyRotation),
    scales: *ArrayList(KeyScale),
    allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator, name: []const u8, aiNodeAnim: [*c]Assimp.aiNodeAnim) !*NodeAnimation {
        const positions = try allocator.create(ArrayList(KeyPosition));
        const rotations = try allocator.create(ArrayList(KeyRotation));
        const scales = try allocator.create(ArrayList(KeyScale));

        positions.* = ArrayList(KeyPosition).init(allocator);
        rotations.* = ArrayList(KeyRotation).init(allocator);
        scales.* = ArrayList(KeyScale).init(allocator);

        const num_positions = aiNodeAnim[0].mNumPositionKeys;
        const num_rotations = aiNodeAnim[0].mNumRotationKeys;
        const num_scales = aiNodeAnim[0].mNumScalingKeys;

        for (aiNodeAnim[0].mPositionKeys[0..num_positions]) |positionKey| {
            const time_stamp: f32 = @floatCast(positionKey.mTime);
            const key = KeyPosition {
                .position = Utils.vec3_from_aiVector3D(positionKey.mValue),
                .time_stamp = time_stamp,
            };
            try positions.append(key);
        }

        for (aiNodeAnim[0].mRotationKeys[0..num_rotations]) |rotationKey| {
            const time_stamp: f32 = @floatCast(rotationKey.mTime);
            const key = KeyRotation {
                .orientation = Utils.quat_from_aiQuaternion(rotationKey.mValue),
                .time_stamp = time_stamp,
            };
            try rotations.append(key);
        }

        for (aiNodeAnim[0].mScalingKeys[0..num_scales]) |scaleKey| {
            const time_stamp: f32 = @floatCast(scaleKey.mTime);
            const key = KeyScale {
                .scale = Utils.vec3_from_aiVector3D(scaleKey.mValue),
                .time_stamp = time_stamp,
            };
            try scales.append(key);
        }

        const node_animation = try allocator.create(NodeAnimation);
        node_animation.* = NodeAnimation{
            .name = try allocator.dupe(u8, name),
            .positions = positions,
            .rotations = rotations,
            .scales = scales,
            .allocator = allocator,
        };

        return node_animation;
    }

    pub fn deinit(self: *Self) void {
        self.positions.deinit();
        self.rotations.deinit();
        self.scales.deinit();
        self.allocator.free(self.name);
        self.allocator.destroy(self.positions);
        self.allocator.destroy(self.rotations);
        self.allocator.destroy(self.scales);
        self.allocator.destroy(self);
    }
};

