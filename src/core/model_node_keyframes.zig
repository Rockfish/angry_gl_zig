const std = @import("std");
const math = @import("math");
const assimp = @import("assimp.zig");
const utils = @import("utils/main.zig");
const Transform = @import("transform.zig").Transform;
const String = @import("string.zig").String;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Assimp = assimp.Assimp;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const KeyPosition = struct {
    position: Vec3,
    tick: f32,
};

pub const KeyRotation = struct {
    orientation: Quat,
    tick: f32,
};

pub const KeyScale = struct {
    scale: Vec3,
    tick: f32,
};

pub const NodeKeyframes = struct {
    node_name: *String,
    positions: *ArrayList(KeyPosition),
    rotations: *ArrayList(KeyRotation),
    scales: *ArrayList(KeyScale),
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator, name: Assimp.aiString, aiNodeAnim: [*c]Assimp.aiNodeAnim) !*NodeKeyframes {
        const name_string = try String.from_aiString(name);
        const positions = try allocator.create(ArrayList(KeyPosition));
        const rotations = try allocator.create(ArrayList(KeyRotation));
        const scales = try allocator.create(ArrayList(KeyScale));

        positions.* = ArrayList(KeyPosition).init(allocator);
        rotations.* = ArrayList(KeyRotation).init(allocator);
        scales.* = ArrayList(KeyScale).init(allocator);

        const num_positions = aiNodeAnim.*.mNumPositionKeys;
        const num_rotations = aiNodeAnim.*.mNumRotationKeys;
        const num_scales = aiNodeAnim.*.mNumScalingKeys;

        for (aiNodeAnim.*.mPositionKeys[0..num_positions]) |positionKey| {
            const key = KeyPosition{
                .position = assimp.vec3FromAiVector3D(positionKey.mValue),
                .tick = @floatCast(positionKey.mTime),
            };
            try positions.append(key);
        }

        for (aiNodeAnim.*.mRotationKeys[0..num_rotations]) |rotationKey| {
            const key = KeyRotation{
                .orientation = assimp.quatFromAiQuaternion(rotationKey.mValue),
                .tick = @floatCast(rotationKey.mTime),
            };
            try rotations.append(key);
        }

        for (aiNodeAnim.*.mScalingKeys[0..num_scales]) |scaleKey| {
            const key = KeyScale{
                .scale = assimp.vec3FromAiVector3D(scaleKey.mValue),
                .tick = @floatCast(scaleKey.mTime),
            };
            try scales.append(key);
        }

        const node_animation = try allocator.create(NodeKeyframes);
        node_animation.* = NodeKeyframes{
            .node_name = name_string,
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
        self.node_name.deinit();
        self.allocator.destroy(self.positions);
        self.allocator.destroy(self.rotations);
        self.allocator.destroy(self.scales);
        self.allocator.destroy(self);
    }

    pub fn get_animation_transform(self: *Self, current_tick: f32) Transform {
        // const translation = self.interpolate_position(current_tick);
        // const rotation = self.interpolate_rotation(current_tick);
        // const scale = self.interpolate_scaling(current_tick);
        // std.debug.print("looking for nan, translation = {any}  rotation = {any}  scale = {any}\n", .{translation, rotation, scale});

        return Transform{
            .translation = self.interpolate_position(current_tick),
            .rotation = self.interpolate_rotation(current_tick),
            .scale = self.interpolate_scaling(current_tick),
        };
    }

    fn interpolate_position(self: *Self, current_tick: f32) Vec3 {
        if (self.positions.items.len == 1) {
            return self.positions.items[0].position;
        }

        const p0_index = self.get_position_index(current_tick);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(
            self.positions.items[p0_index].tick,
            self.positions.items[p1_index].tick,
            current_tick,
        );

        // final_position
        return Vec3.lerp(
            &self.positions.items[p0_index].position,
            &self.positions.items[p1_index].position,
            scale_factor,
        );
    }

    fn interpolate_rotation(self: *Self, current_tick: f32) Quat {
        if (self.rotations.items.len == 1) {
            var rotation = self.rotations.items[0].orientation.clone();
            rotation.normalize();
            return rotation;
        }

        const p0_index = self.get_rotation_index(current_tick);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(
            self.rotations.items[p0_index].tick,
            self.rotations.items[p1_index].tick,
            current_tick,
        );

        // final_rotation
        const final_rotation = Quat.slerp(
            &self.rotations.items[p0_index].orientation,
            &self.rotations.items[p1_index].orientation,
            scale_factor,
        );
        return final_rotation;
    }

    fn interpolate_scaling(self: *Self, current_tick: f32) Vec3 {
        if (self.scales.items.len == 1) {
            return self.scales.items[0].scale;
        }

        const p0_index = self.get_scale_index(current_tick);
        const p1_index = p0_index + 1;

        const scale_factor = self.get_scale_factor(
            self.scales.items[p0_index].tick,
            self.scales.items[p1_index].tick,
            current_tick,
        );

        // final_scale
        return Vec3.lerp(
            &self.scales.items[p0_index].scale,
            &self.scales.items[p1_index].scale,
            scale_factor,
        );
    }

    fn get_position_index(self: *Self, current_tick: f32) usize {
        for (0..self.positions.items.len - 1) |index| {
            if (current_tick < self.positions.items[index + 1].tick) {
                return index;
            }
        }
        @panic("animation tick out of bounds");
    }

    fn get_rotation_index(self: *Self, current_tick: f32) usize {
        for (0..self.rotations.items.len - 1) |index| {
            if (current_tick < self.rotations.items[index + 1].tick) {
                return index;
            }
        }
        @panic("animation tick out of bounds");
    }

    fn get_scale_index(self: *Self, current_tick: f32) usize {
        for (0..self.scales.items.len - 1) |index| {
            if (current_tick < self.scales.items[index + 1].tick) {
                return index;
            }
        }
        @panic("animation tick out of bounds");
    }

    fn get_scale_factor(self: *Self, previous_tick: f32, next_tick: f32, current_tick: f32) f32 {
        _ = self;
        const mid_way_length = current_tick - previous_tick;
        const frames_diff = next_tick - previous_tick;
        return mid_way_length / frames_diff;
    }
};
