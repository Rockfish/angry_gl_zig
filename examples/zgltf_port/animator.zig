const std = @import("std");
const math = @import("math");
const core = @import("core");

const Node = @import("node.zig").Node;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Transform = core.Transform;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;

pub const MAX_BONES: usize = 100;
pub const MAX_NODES: usize = 100;

pub const AnimationRepeatMode = enum {
    Once,
    Count,
    Forever,
};

pub const Animation = struct {

};

pub const AnimationState = struct {
    animation: *Animation,
    animation_id: usize,
    start_tick: f32,
    end_tick: f32,
    current_tick: f32,
    ticks_per_second: f32,
    repeat_mode: AnimationRepeatMode,
    repeat_completions: u32,

    pub fn update(self: *AnimationState, delta_time: f32) void {
        if (self.current_tick < 0.0) {
            self.current_tick = self.start_tick;
        }

        self.current_tick += self.ticks_per_second * delta_time;

        if (self.current_tick > self.end_tick) {
            switch (self.repeat_mode) {
                .Once => {
                    self.current_tick = self.end_tick;
                },
                .Count => |_| {},
                .Forever => {
                    self.current_tick = self.start_tick;
                },
            }
        }
    }
};



pub const Animator = struct {
    allocator: Allocator,

    // root_node: *Node,
    // global_inverse_transform: Transform,
    //
    // animations: *ArrayList(*Animation),
    // animation_state: ?*AnimationState,


    final_bone_matrices: [MAX_BONES]Mat4,
    final_node_matrices: [MAX_NODES]Mat4,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator) !*Animator {
        const animator = try allocator.create(Animator);
        animator.* = Animator {
            .allocator = allocator,
            .final_bone_matrices = [_]Mat4{Mat4.identity()} ** MAX_BONES,
            .final_node_matrices = [_]Mat4{Mat4.identity()} ** MAX_NODES,
        };

        return animator;
    }

};
