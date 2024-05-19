const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const BoneData = @import("model_animation.zig").BoneData;
const NodeData = @import("model_animation.zig").NodeData;
const ModelAnimation = @import("model_animation.zig").ModelAnimation;
const Transform = @import("transform.zig").Transform;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

pub const AnimationRepeat = union {
    Once: u32,
    Count: u32,
    Forever: u32,
};

pub const AnimationClip = struct {
    start_tick: f32,
    end_tick: f32,
    repeat: AnimationRepeat,
};

// An animation that is being faded out as part of a transition (from Bevy)
pub const AnimationTransition = struct {
    // The current weight. Starts at 1.0 and goes to 0.0 during the fade-out.
    current_weight: f32,
    // How much to decrease `current_weight` per second
    weight_decline_per_sec: f32,
    // The animation that is being faded out
    animation: PlayingAnimation,
};

pub const WeightedAnimation = struct {
    weight: f32,
    start_tick: f32,
    end_tick: f32,
    offset: f32,
    optional_start: f32,
};

pub const PlayingAnimation = struct {
    animation_clip: AnimationClip,
    current_tick: f32,
    ticks_per_second: f32,
    repeat_completions: u32,
};

pub const NodeTransform = struct {
    transform: Transform,
    meshes: ArrayList(u32),
};

pub const Animator = struct {
    allocator: Allocator,
    root_node: NodeData,
    global_inverse_transform: zm.Mat4,
    bone_data_map: *StringHashMap(*BoneData),

    model_animation: ModelAnimation, // maybe should be vec?

    current_animation: PlayingAnimation,
    transitions: ArrayList(AnimationTransition),

    node_transforms: StringHashMap(NodeTransform),

    final_bone_matrices: ArrayList(zm.Mat4),
    final_node_matrices: ArrayList(zm.Mat4),
    

    const Self = @This();

    pub fn init(allocator: Allocator, aiScene: [*c]const Assimp.aiScene, bone_data_map: *StringHashMap(*BoneData)) !*Self {
        _ = aiScene;

        const animator = try allocator.create(Animator);
        animator.* = Animator{ 
            .allocator = allocator,
            .root_node = undefined,
            .global_inverse_transform = undefined,
            .bone_data_map = bone_data_map,
            .model_animation = undefined,
            .current_animation = undefined,
            .transitions = undefined,
            .node_transforms = undefined,
            .final_bone_matrices = undefined,
            .final_node_matrices = undefined,
        };

        return animator;
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.bone_data_map.valueIterator();
        while (iterator.next()) |bone_data| {
            bone_data.*.deinit();
        }
        self.bone_data_map.deinit();
        self.allocator.destroy(self.bone_data_map);
        self.allocator.destroy(self);
    }
};