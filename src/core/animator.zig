const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const BoneData = @import("model_animation.zig").BoneData;
const NodeData = @import("model_animation.zig").NodeData;
const ModelAnimation = @import("model_animation.zig").ModelAnimation;
const Transform = @import("transform.zig").Transform;
const Utils = @import("utils.zig");

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

    pub fn new(start_tick: f32, end_tick: f32, repeat: AnimationRepeat) AnimationClip {
        return .{
            .start_tick = start_tick,
            .end_tick = end_tick,
            .repeat = repeat,
        };
    }
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

    pub fn new(weight: f32, start_tick: f32, end_tick: f32, offset: f32, optional_start: f32) WeightedAnimation {
        return .{
            .weight = weight,
            .start_tick = start_tick,
            .end_tick = end_tick,
            .offset = offset,
            .optional_start = optional_start, // used for non-looped animations
        };
    }
};

pub const PlayingAnimation = struct {
    animation_clip: AnimationClip,
    current_tick: f32,
    ticks_per_second: f32,
    repeat_completions: u32,

    pub fn update(self: *PlayingAnimation, delta_time: f32) void {
        if (self.current_tick < 0.0) {
            self.current_tick = self.animation_clip.start_tick;
        }

        self.current_tick += self.ticks_per_second * delta_time;

        if (self.current_tick > self.animation_clip.end_tick) {
            switch (self.animation_clip.repeat) {
                AnimationRepeat.Once => { self.current_tick = self.animation_clip.end_tick; },
                AnimationRepeat.Count => |_| {},
                AnimationRepeat.Forever => { self.current_tick = self.animation_clip.start_tick; }
            }
        }
    }
};

pub const NodeTransform = struct {
    transform: Transform,
    meshes: ArrayList(u32),

    pub fn new(transform: Transform, meshes: *ArrayList(u32)) NodeTransform {
        return .{
            .transform = transform,
            .meshes = meshes,
        };
    }
};

pub const Animator = struct {
    allocator: Allocator,
    root_node: NodeData,
    global_inverse_transform: zm.Mat4,
    bone_data_map: *StringHashMap(*BoneData),

    model_animation: *ModelAnimation, // maybe should be vec?

    current_animation: PlayingAnimation,
    transitions: ArrayList(AnimationTransition),

    node_transforms: StringHashMap(NodeTransform),

    final_bone_matrices: ArrayList(zm.Mat4),
    final_node_matrices: ArrayList(zm.Mat4),

    const Self = @This();

    pub fn init(allocator: Allocator, aiScene: [*c]const Assimp.aiScene, bone_data_map: *StringHashMap(*BoneData)) !*Self {
        const root = aiScene[0].mRootNode[0];
        const transform = Utils.mat4_from_aiMatrix(root.mTransformation);
        const global_inverse_transform = zm.inverse(transform);

        const model_animation = try ModelAnimation.init(allocator, aiScene);
        //
        // let mut final_bone_matrices = Vec::with_capacity(100);
        // let mut final_node_matrices = Vec::with_capacity(50);
        //
        // for i in 0..100 {
        // final_bone_matrices.push(Mat4::IDENTITY);
        // if i < 50 {
        // final_node_matrices.push(Mat4::IDENTITY);
        // }
        // }
        //
        // let animation_clip = AnimationClip {
        // start_tick: 0.0,
        // end_tick: model_animation.duration,
        // repeat: AnimationRepeat::Forever,
        // };
        //
        // let current_animation = PlayingAnimation {
        // animation_clip: Rc::new(animation_clip),
        // current_tick: -1.0,
        // ticks_per_second: model_animation.ticks_per_second,
        // repeat_completions: 0,
        // };

        const animator = try allocator.create(Animator);
        animator.* = Animator{
            .allocator = allocator,
            .root_node = undefined,
            .global_inverse_transform = global_inverse_transform,
            .bone_data_map = bone_data_map,
            .model_animation = model_animation,
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
        self.model_animation.deinit();
        self.allocator.destroy(self);
    }
};
