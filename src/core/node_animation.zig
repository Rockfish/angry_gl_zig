const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const utils = @import("utils.zig");
const Transform = @import("transform.zig").Transform;
const String = @import("string.zig").String;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const KeyPosition = struct {
    position: zm.Vec4,
    time_stamp: f32,
};

pub const KeyRotation = struct {
    orientation: zm.Quat,
    time_stamp: f32,
};

pub const KeyScale = struct {
    scale: zm.Vec4,
    time_stamp: f32,
};

pub const NodeAnimation = struct {
    name: *String,
    positions: *ArrayList(KeyPosition),
    rotations: *ArrayList(KeyRotation),
    scales: *ArrayList(KeyScale),
    allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator, name: Assimp.aiString, aiNodeAnim: [*c]Assimp.aiNodeAnim) !*NodeAnimation {
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
            const key = KeyPosition{
                .position = utils.vec4_from_aiVector3D(positionKey.mValue),
                .time_stamp = time_stamp,
            };
            try positions.append(key);
        }

        for (aiNodeAnim[0].mRotationKeys[0..num_rotations]) |rotationKey| {
            const time_stamp: f32 = @floatCast(rotationKey.mTime);
            const key = KeyRotation{
                .orientation = utils.quat_from_aiQuaternion(rotationKey.mValue),
                .time_stamp = time_stamp,
            };
            try rotations.append(key);
        }

        for (aiNodeAnim[0].mScalingKeys[0..num_scales]) |scaleKey| {
            const time_stamp: f32 = @floatCast(scaleKey.mTime);
            const key = KeyScale{
                .scale = utils.vec4_from_aiVector3D(scaleKey.mValue),
                .time_stamp = time_stamp,
            };
            try scales.append(key);
        }

        const node_animation = try allocator.create(NodeAnimation);
        node_animation.* = NodeAnimation{
            .name = try String.from_aiString(name),
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
        self.name.deinit();
        self.allocator.destroy(self.positions);
        self.allocator.destroy(self.rotations);
        self.allocator.destroy(self.scales);
        self.allocator.destroy(self);
    }

    pub fn get_animation_transform(self: *Self, animation_time: f32) Transform {
        return Transform{
            .translation = self.interpolate_position(animation_time),
            .rotation = self.interpolate_rotation(animation_time),
            .scale = self.interpolate_scaling(animation_time),
        };
    }

    fn interpolate_position(self: *Self, animation_time: f32) zm.Vec4 {
        if (self.positions.items.len == 1) {
            return self.positions.items[0].position;
        }

        const p0_index = self.get_position_index(animation_time);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(
            self.positions.items[p0_index].time_stamp,
            self.positions.items[p1_index].time_stamp,
            animation_time,
        );

        // final_position
        return zm.lerp(self.positions.items[p0_index].position, self.positions.items[p1_index].position, scale_factor);
    }

    fn interpolate_rotation(self: *Self, animation_time: f32) zm.Quat {
        if (self.rotations.items.len == 1) {
            const rotation = zm.normalize3(self.rotations.items[0].orientation);
            return rotation;
        }

        const p0_index = self.get_rotation_index(animation_time);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(
            self.rotations.items[p0_index].time_stamp,
            self.rotations.items[p1_index].time_stamp,
            animation_time,
        );

        // final_rotation
        return zm.slerp(self.rotations.items[p0_index].orientation, self.rotations.items[p1_index].orientation, scale_factor);
    }

    fn interpolate_scaling(self: *Self, animation_time: f32) zm.Vec4 {
        if (self.scales.items.len == 1) {
            return self.scales.items[0].scale;
        }

        const p0_index = self.get_scale_index(animation_time);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(self.scales.items[p0_index].time_stamp, self.scales.items[p1_index].time_stamp, animation_time);

        // final_scale
        return zm.lerp(self.scales.items[p0_index].scale, self.scales.items[p1_index].scale, scale_factor);
    }

    fn get_position_index(self: *Self, animation_time: f32) usize {
        for (0..self.positions.items.len - 1) |index| {
            if (animation_time < self.positions.items[index + 1].time_stamp) {
                return index;
            }
        }
        @panic("animation time out of bounds");
    }

    fn get_rotation_index(self: *Self, animation_time: f32) usize {
        for (0..self.rotations.items.len - 1) |index| {
            if (animation_time < self.rotations.items[index + 1].time_stamp) {
                return index;
            }
        }
        @panic("animation time out of bounds");
    }

    fn get_scale_index(self: *Self, animation_time: f32) usize {
        for (0..self.scales.items.len - 1) |index| {
            if (animation_time < self.scales.items[index + 1].time_stamp) {
                return index;
            }
        }
        @panic("animation time out of bounds");
    }

    fn get_scale_factor(self: *Self, last_timestamp: f32, next_timestamp: f32, animation_time: f32) f32 {
        _ = self;
        const mid_way_length = animation_time - last_timestamp;
        const frames_diff = next_timestamp - last_timestamp;
        return mid_way_length / frames_diff;
    }
};
