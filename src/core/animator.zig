const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const BoneData = @import("model_animation.zig").BoneData;
const NodeData = @import("model_animation.zig").NodeData;
const ModelAnimation = @import("model_animation.zig").ModelAnimation;
const NodeAnimation = @import("node_animation.zig").NodeAnimation;
const Transform = @import("transform.zig").Transform;
const Utils = @import("utils.zig");
const String = @import("string.zig").String;
const panic = @import("std").debug.panic;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const MAX_BONES: usize = 100;
const MAX_NODES: usize = 50;

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
                AnimationRepeat.Once => {
                    self.current_tick = self.animation_clip.end_tick;
                },
                AnimationRepeat.Count => |_| {},
                AnimationRepeat.Forever => {
                    self.current_tick = self.animation_clip.start_tick;
                },
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

    model_animation: *ModelAnimation,

    current_animation: PlayingAnimation,
    transitions: ArrayList(AnimationTransition),

    node_transforms: StringHashMap(NodeTransform),

    final_bone_matrices: [MAX_BONES]zm.Mat4,
    final_node_matrices: [MAX_NODES]zm.Mat4,

    const Self = @This();

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

    pub fn init(allocator: Allocator, aiScene: [*c]const Assimp.aiScene, bone_data_map: *StringHashMap(*BoneData)) !*Self {
        const root = aiScene[0].mRootNode[0];
        const transform = Utils.mat4_from_aiMatrix(root.mTransformation);
        const global_inverse_transform = zm.inverse(transform);

        const model_animation = try ModelAnimation.init(allocator, aiScene);

        // probably don't need to initialize these
        // for (0..100) |i| {
        // final_bone_matrices.push(zm.identity());
        // if (i < 50) {
        // final_node_matrices.push(zm.identity());
        // }
        // }

        const animation_clip = AnimationClip{
            .start_tick = 0.0,
            .end_tick = model_animation.duration,
            .repeat = .{ .Forever = 0 },
        };

        const current_animation = PlayingAnimation{
            .animation_clip = animation_clip,
            .current_tick = -1.0,
            .ticks_per_second = model_animation.ticks_per_second,
            .repeat_completions = 0,
        };

        const animator = try allocator.create(Animator);
        animator.* = Animator{
            .allocator = allocator,
            .root_node = undefined,
            .global_inverse_transform = global_inverse_transform,
            .bone_data_map = bone_data_map,
            .model_animation = model_animation,
            .current_animation = current_animation,
            .transitions = undefined,
            .node_transforms = undefined,
            .final_bone_matrices = [_]zm.Mat4{zm.identity()} ** MAX_BONES,
            .final_node_matrices = [_]zm.Mat4{zm.identity()} ** MAX_NODES,
        };

        return animator;
    }

    pub fn play_clip(self: *Self, clip: AnimationClip) void {
        self.current_animation = PlayingAnimation{
            .animation_clip = clip,
            .current_tick = -1.0,
            .ticks_per_second = self.model_animation.ticks_per_second,
            .repeat_completions = 0,
        };
    }

    pub fn play_weight_animations(self: *Self, weighted_animation: *ArrayList(WeightedAnimation), frame_time: f32) void {
        {
            var node_map = self.node_transforms;
            const node_animations = self.model_animation.node_animations;

            // reset node transforms
            node_map.clear();

            const inverse_transform = Transform.from_matrix(self.global_inverse_transform);

            for (weighted_animation) |weighted| {
                if (weighted.weight == 0.0) {
                    continue;
                }

                const tick_range = weighted.end_tick - weighted.start_tick;

                var target_anim_ticks = if (weighted.optional_start > 0.0) blk1: {
                    const tick = (frame_time - weighted.optional_start) * self.model_animation.ticks_per_second + weighted.offset;
                    break :blk1 @min(tick, tick_range);
                } else (frame_time * self.model_animation.ticks_per_second + weighted.offset) % tick_range;

                target_anim_ticks += weighted.start_tick;

                if ((target_anim_ticks < (weighted.start_tick - 0.01)) || (target_anim_ticks > (weighted.end_tick + 0.01))) {
                    panic("target_anim_ticks out of range: {}", target_anim_ticks);
                }

                calculate_transform_maps(
                    self.root_node,
                    node_animations,
                    node_map,
                    inverse_transform,
                    target_anim_ticks,
                    weighted.weight,
                );
            }
        }

        self.update_final_transforms();
    }

    // pub fn play_clip_with_transition(self: *Self, clip: AnimationClip, transition_duration: Duration) void {
    //
    // var animation = PlayingAnimation {
    //     .animation_clip = clip,
    //     .current_tick = -1.0,
    //     .ticks_per_second = self.model_animation.ticks_per_second,
    //     .repeat_completions = 0,
    // };
    //
    // std::mem::swap(&mut animation, self: *Self.current_animation);
    //
    // const transition = AnimationTransition {
    // current_weight: 1.0,
    // weight_decline_per_sec: 1.0 / transition_duration.as_secs_f32(),
    // animation,
    // };
    //
    // self.transitions.push(transition);
    // }

    pub fn update_animation(self: *Self, delta_time: f32) void {
        self.current_animation.update(delta_time);
        self.update_transitions(delta_time);
        self.update_node_map(delta_time);
        self.update_final_transforms();
    }

    // fn update_transitions(self: *Self, delta_time: f32) void {
    //     self.transitions.retain_mut(|animation| {
    //      animation.current_weight -= animation.weight_decline_per_sec * delta_time;
    //      animation.current_weight > 0.0 }
    //  )
    // }

    fn update_node_map(self: *Self, delta_time: f32) void {
        self.node_transforms.clear();

        const transitions = self.transitions;
        const node_map = self.node_transforms;
        const node_animations = self.model_animation.node_animations;

        const inverse_transform = Transform.from_matrix(self.global_inverse_transform);

        // First for current animation at weight 1.0
        calculate_transform_maps(
            self.root_node,
            node_animations,
            node_map,
            inverse_transform,
            self.current_animation.current_tick,
            1.0,
        );

        for (transitions.items) |transition| {
            transition.animation.update(delta_time);
            calculate_transform_maps(
                self.root_node,
                node_animations,
                node_map,
                inverse_transform,
                transition.animation.current_tick,
                transition.current_weight,
            );
        }
    }

    fn update_final_transforms(self: *Self) void {
        // const bone_data_map = self.bone_data_map;

        var final_bones = self.final_bone_matrices;
        var final_node = self.final_node_matrices;

        const iterator = self.node_transforms.iterator();
        for (iterator) |entry| { // |node_name, node_transform| {
            const node_name = entry.key_ptr;
            const node_transform = entry.value_ptr;

            if (self.bone_data_map.get(node_name)) |bone_data| {
                const index = bone_data.bone_index;
                const transform_matrix = node_transform.transform.mul_transform(bone_data.offset_transform).compute_matrix();
                final_bones[index] = transform_matrix;
            }

            for (node_transform.meshes.items) |mesh_index| {
                final_node[mesh_index] = node_transform.transform.compute_matrix();
            }
        }
    }

    /// Converts scene Node tree to local NodeData tree. Converting all the transforms to column major form.
    fn read_hierarchy_data(self: *Self, source: Assimp.aiNode) !*NodeData {
        var node_data = try NodeData.init(self.allocator, source.mName);
        node_data.*.transform = Transform.from_matrix(source.transformation);

        for (source.mMeshes[0..source.mNumMeshes]) |mesh_id| {
            try node_data.*.meshes.append(mesh_id);
        }

        for (source.children.items) |child| {
            const node = read_hierarchy_data(child);
            node_data.children.push(node);
        }
        return node_data;
    }

    pub fn calculate_transform_maps(
        self: *Self,
        node_data: *NodeData,
        node_animations: *ArrayList(NodeAnimation),
        node_map: *StringHashMap(*NodeTransform),
        parent_transform: Transform,
        current_tick: f32,
        weight: f32,
    ) void {
        const global_transformation = self.calculate_transform(node_data, node_animations, node_map, parent_transform, current_tick, weight);

        for (node_data.children.items) |child_node| {
            self.calculate_transform_maps(child_node, node_animations, node_map, global_transformation, current_tick, weight);
        }
    }

    fn calculate_transform(
        self: *Self,
        node_data: *NodeData,
        node_animations: *ArrayList(NodeAnimation),
        node_map: *StringHashMap(NodeTransform),
        parent_transform: Transform,
        current_tick: f32,
        weight: f32,
    ) Transform {

        const iterator = node_animations.*.iterator();
        const some_node_animation = for (iterator) |node_anim| blk1: {
            if (node_anim.name.equals(node_data.name)) {
                break :blk1 node_anim;
            }
        } else null;

        var global_transform: Transform = undefined;
        if (some_node_animation) |node_animation| {
            const node_transform = node_animation.get_animation_transform(current_tick);
            global_transform = parent_transform.mul_transform(node_transform);
        } else {
            global_transform = parent_transform.mul_transform(node_data.transform);
        }

        const result = node_map.getOrPut(node_data.name.str);
        if (result.found_existing) {
            result.value_ptr.*.transform = result.value_ptr.*.transform.mul_transform_weighted(global_transform, weight);
        } else {
            const node_transform = try self.allocator.create(NodeTransform);
            node_transform.* = NodeTransform.new(global_transform, node_data.meshes);

        }

        return global_transform;
    }
};
