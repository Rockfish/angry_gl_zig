const std = @import("std");
const core = @import("core");
const math = @import("math");
const world = @import("world.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const State = world.State;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const ModelMesh = core.ModelMesh;
const Shader = core.Shader;
const animation = core.animation;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const Animator = animation.Animator;
const AnimationClip = animation.AnimationClip;
const AnimationRepeat = animation.AnimationRepeat;
const WeightedAnimation = animation.WeightedAnimation;

const PLAYER_SPEED: f32 = 5.0;
// 1.5;
const ANIM_TRANSITION_TIME: f32 = 0.2;

// const IDLE = "idle";
// const RIGHT = "right";
// const FORWARD = "forward";
// const BACK = "back";
// const LEFT = "left";
// const DEAD = "dead";

pub const AnimationName = enum {
    idle,
    right,
    forward,
    back,
    left,
    dead,
};

pub const PlayerAnimations = struct {
    idle: AnimationClip,
    right: AnimationClip,
    forward: AnimationClip,
    back: AnimationClip,
    left: AnimationClip,
    dead: AnimationClip,

    const Self = @This();
    
    pub fn new() Self {
        return .{
            .idle = AnimationClip.new(55.0, 130.0, AnimationRepeat.Forever),
            .right = AnimationClip.new(184.0, 204.0, AnimationRepeat.Forever),
            .forward = AnimationClip.new(134.0, 154.0, AnimationRepeat.Forever),
            .back = AnimationClip.new(159.0, 179.0, AnimationRepeat.Forever),
            .left = AnimationClip.new(209.0, 229.0, AnimationRepeat.Forever),
            .dead = AnimationClip.new(234.0, 293.0, AnimationRepeat.Once),
        };
    }

    pub fn get(self: *Self, name: AnimationName) AnimationClip {
        return switch (name) {
            .idle => self.idle,
            .right => self.right,
            .forward => self.forward,
            .back => self.back,
            .left => self.left,
            .dead => self.dead,
        };
    }
};

pub const AnimationWeights = struct {
    // Previous animation weights
    last_anim_time: f32,
    prev_idle_weight: f32,
    prev_right_weight: f32,
    prev_forward_weight: f32,
    prev_back_weight: f32,
    prev_left_weight: f32,

    const Self = @This();

    fn default() Self {
        return .{
            .last_anim_time = 0.0,
            .prev_idle_weight = 0.0,
            .prev_right_weight = 0.0,
            .prev_forward_weight = 0.0,
            .prev_back_weight = 0.0,
            .prev_left_weight = 0.0,
        };
    }
};

pub const Player = struct {
    allocator: Allocator,
    model: *Model,
    position: Vec3,
    direction: Vec2,
    speed: f32,
    aim_theta: f32,
    last_fire_time: f32,
    is_trying_to_fire: bool,
    is_alive: bool,
    death_time: f32,
    animation_name: AnimationName,
    animations: PlayerAnimations,
    anim_weights: AnimationWeights,
    anim_hash: HashMap(AnimationName, AnimationClip),

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.model.deinit();
        self.anim_hash.deinit();
        self.allocator.destroy(self);
    }

    pub fn new(allocator: Allocator, texture_cache: *ArrayList(*Texture)) !*Self {
        const model_path = "assets/Models/Player/Player.fbx";

        var builder = try ModelBuilder.init(allocator, texture_cache, "Player", model_path);
        defer builder.deinit();

        const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
        const texture_specular = .{ .texture_type = .Specular, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
        const texture_emissive = .{ .texture_type = .Emissive, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
        const texture_normals = .{ .texture_type = .Normals, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };

        try builder.addTexture("Player", texture_diffuse, "Textures/Player_D.tga");
        try builder.addTexture("Player", texture_specular, "Textures/Player_M.tga");
        try builder.addTexture("Player", texture_emissive, "Textures/Player_E.tga");
        try builder.addTexture("Player", texture_normals, "Textures/Player_NRM.tga");
        try builder.addTexture("Gun", texture_diffuse, "Textures/Gun_D.tga");
        try builder.addTexture("Gun", texture_specular, "Textures/Gun_M.tga");
        try builder.addTexture("Gun", texture_emissive, "Textures/Gun_E.tga");
        try builder.addTexture("Gun", texture_normals, "Textures/Gun_NRM.tga");

        std.debug.print("player builder created\n", .{});
        const model = try builder.build();
        std.debug.print("player model built\n", .{});

        var anim_hash = HashMap(AnimationName, AnimationClip).init(allocator);
        try anim_hash.put(.idle, AnimationClip.new(55.0, 130.0, AnimationRepeat.Forever));
        try anim_hash.put(.forward, AnimationClip.new(134.0, 154.0, AnimationRepeat.Forever));
        try anim_hash.put(.back, AnimationClip.new(159.0, 179.0, AnimationRepeat.Forever));
        try anim_hash.put(.right, AnimationClip.new(184.0, 204.0, AnimationRepeat.Forever));
        try anim_hash.put(.left, AnimationClip.new(209.0, 229.0, AnimationRepeat.Forever));
        try anim_hash.put(.dead, AnimationClip.new(234.0, 293.0, AnimationRepeat.Once));

        const player = try allocator.create(Player);
        player.* = Player {
            .allocator = allocator,
            .model = model,
            .last_fire_time = 0.0,
            .is_trying_to_fire = false,
            .is_alive = true,
            .aim_theta = 0.0,
            .position = vec3(0.0, 0.0, 0.0),
            .direction = vec2(0.0, 0.0),
            .death_time = -1.0,
            .animation_name = .idle,
            .speed = PLAYER_SPEED,
            .animations = PlayerAnimations.new(),
            .anim_weights = AnimationWeights.default(),
            .anim_hash = anim_hash,
        };

        try player.model.playClip(player.animations.idle);
        return player;
    }
    
    pub fn set_animation(self: *Self, animation_name: AnimationName, seconds: u32) void {
        if (!self.animation_name.eq(animation_name)) {
            self.animation_name = animation_name;
            self.model.play_clip_with_transition(self.animations.get(self.animation_name.deref()), seconds);
        }
    }

    pub fn get_muzzle_position(self: *const Self, player_model_transform: *const Mat4) Mat4 {
        // Position in original model of gun muzzle
        // const point_vec = vec3(197.0, 76.143, -3.054);
        const point_vec = vec3(191.04, 79.231, -3.4651); // center of muzzle

        var gun_mesh: *ModelMesh = undefined;
        for (self.model.meshes.items) |m| {
            if (std.mem.eql(u8, m.name, "Gun")) {
                gun_mesh = m;
            }
        }

        const gun_transform = self.model.animator.final_node_matrices[@intCast(gun_mesh.id)];
        const muzzle = gun_transform.mulMat4(&Mat4.fromTranslation(&point_vec));

        // muzzle_transform
        return player_model_transform.mulMat4(&muzzle);
    }

    pub fn set_player_death_time(self: *Self, time: f32) void {
        if (self.death_time < 0.0) {
            self.death_time = time;
        }
    }

    pub fn render(self: *Self, shader: *const Shader) !void {
        try self.model.render(shader);
    }

    pub fn update(self: *Self, state: *State, aim_theta: f32) !void {
        const weight_animations = self.update_animation_weights(self.direction, aim_theta, state.frame_time);
        try self.model.play_weight_animations(&weight_animations, state.frame_time);
        // _ = aim_theta;
        // try self.model.update_animation(state.delta_time);
    }

    fn update_animation_weights(self: *Self, move_vec: Vec2, aim_theta: f32, frame_time: f32) [6]WeightedAnimation {
        const is_moving = move_vec.lengthSquared() > 0.1;
        const move_theta = math.atan(move_vec.x / move_vec.y) + if (move_vec.y < @as(f32, 0.0)) math.pi else @as(f32, 0.0);
        const theta_delta = move_theta - aim_theta;
        const anim_move = vec2(math.sin(theta_delta), math.cos(theta_delta));

        const anim_delta_time = frame_time - self.anim_weights.last_anim_time;
        self.anim_weights.last_anim_time = frame_time;

        const is_dead = self.death_time >= 0.0;

        self.anim_weights.prev_idle_weight = max(0.0, self.anim_weights.prev_idle_weight - anim_delta_time / ANIM_TRANSITION_TIME);
        self.anim_weights.prev_right_weight = max(0.0, self.anim_weights.prev_right_weight - anim_delta_time / ANIM_TRANSITION_TIME);
        self.anim_weights.prev_forward_weight = max(0.0, self.anim_weights.prev_forward_weight - anim_delta_time / ANIM_TRANSITION_TIME);
        self.anim_weights.prev_back_weight = max(0.0, self.anim_weights.prev_back_weight - anim_delta_time / ANIM_TRANSITION_TIME);
        self.anim_weights.prev_left_weight = max(0.0, self.anim_weights.prev_left_weight - anim_delta_time / ANIM_TRANSITION_TIME);

        var dead_weight: f32 = if (is_dead) @as(f32, 1.0) else @as(f32, 0.0);
        var idle_weight = self.anim_weights.prev_idle_weight + if (is_moving or is_dead) @as(f32, 0.0) else @as(f32, 1.0);
        var right_weight = self.anim_weights.prev_right_weight + if (is_moving) clamp0(-anim_move.x) else @as(f32, 0.0);
        var forward_weight = self.anim_weights.prev_forward_weight + if (is_moving) clamp0(anim_move.y) else @as(f32, 0.0);
        var back_weight = self.anim_weights.prev_back_weight + if (is_moving) clamp0(-anim_move.y) else @as(f32, 0.0);
        var left_weight = self.anim_weights.prev_left_weight + if (is_moving) clamp0(anim_move.x) else @as(f32, 0.0);

        const weight_sum = dead_weight + idle_weight + forward_weight + back_weight + right_weight + left_weight;
        dead_weight /= weight_sum;
        idle_weight /= weight_sum;
        forward_weight /= weight_sum;
        back_weight /= weight_sum;
        right_weight /= weight_sum;
        left_weight /= weight_sum;

        self.anim_weights.prev_idle_weight = max(self.anim_weights.prev_idle_weight, idle_weight);
        self.anim_weights.prev_right_weight = max(self.anim_weights.prev_right_weight, right_weight);
        self.anim_weights.prev_forward_weight = max(self.anim_weights.prev_forward_weight, forward_weight);
        self.anim_weights.prev_back_weight = max(self.anim_weights.prev_back_weight, back_weight);
        self.anim_weights.prev_left_weight = max(self.anim_weights.prev_left_weight, left_weight);

        // weighted animations
        return .{
            WeightedAnimation.new(idle_weight, 55.0, 130.0, 0.0, 0.0),
            WeightedAnimation.new(forward_weight, 134.0, 154.0, 0.0, 0.0),
            WeightedAnimation.new(back_weight, 159.0, 179.0, 10.0, 0.0),
            WeightedAnimation.new(right_weight, 184.0, 204.0, 10.0, 0.0),
            WeightedAnimation.new(left_weight, 209.0, 229.0, 0.0, 0.0),
            WeightedAnimation.new(dead_weight, 234.0, 293.0, 0.0, self.death_time),
        };
    }
};

fn clamp0(value: f32) f32 {
    if (value < 0.0001) {
        return 0.0;
    }
    return value;
}

fn max(a: f32, b: f32) f32 {
    if (a > b) {
        return a;
    } else {
        return b;
    }
}