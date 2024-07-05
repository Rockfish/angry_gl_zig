const std = @import("std");
const glfw = @import("zglfw");
const set = @import("ziglangSet");
const core = @import("core");
const math = @import("math");

const ArrayList = std.ArrayList;
const EnumSet = std.EnumSet;

const Player = @import("player.zig").Player;
const Enemy = @import("enemy.zig").Enemy;
const EnemySystem = @import("enemy.zig").EnemySystem;
const BulletStore = @import("bullets.zig").BulletStore;
const BurnMarks = @import("burn_marks.zig").BurnMarks;
const MuzzleFlash = @import("muzzle_flash.zig").MuzzleFlash;
const Floor = @import("floor.zig").Floor;
const fb = @import("framebuffers.zig");
const quads = @import("quads.zig");
const Capsule = @import("capsule.zig").Capsule;

const Assimp = core.assimp.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Animation = core.animation;
const Texture = core.texture.Texture;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.string.String;
const FrameCount = core.FrameCount;
const SoundEngine = core.SoundEngine;

// Player
pub const FIRE_INTERVAL: f32 = 0.1;
pub const SPREAD_AMOUNT: i32 = 20; // bullet spread
pub const PLAYER_COLLISION_RADIUS: f32 = 0.35;
pub const PLAYER_MODEL_SCALE: f32 = 0.0044;
pub const PLAYER_MODEL_GUN_HEIGHT: f32 = 110.0;
pub const PLAYER_MODEL_GUN_MUZZLE_OFFSET: f32 = 100.0;

// Enemies
pub const MONSTER_Y: f32 = PLAYER_MODEL_SCALE * PLAYER_MODEL_GUN_HEIGHT;
pub const MONSTER_SPEED: f32 = 0.6;
pub const ENEMY_SPAWN_INTERVAL: f32 = 1.0; // seconds
pub const SPAWNS_PER_INTERVAL: i32 = 1;
pub const SPAWN_RADIUS: f32 = 10.0; // from player

pub const ENEMY_COLLIDER: Capsule = Capsule{ .height = 0.4, .radius = 0.08 };

pub const CameraType = enum {
    Game,
    Floating,
    TopDown,
    Side,
};

pub const ClipName = enum {
    GunFire,
    Explosion,
};

pub const ClipData = struct {
    clip: ClipName,
    file: [:0]const u8,
};

pub const State = struct {
    viewport_width: f32,
    viewport_height: f32,
    scaled_width: f32,
    scaled_height: f32,
    window_scale: [2]f32,
    game_camera: *Camera,
    floating_camera: *Camera,
    ortho_camera: *Camera,
    active_camera: CameraType,
    player: *Player,
    burn_marks: *BurnMarks,
    enemies: std.ArrayList(?Enemy),
    sound_engine: SoundEngine(ClipName, ClipData),
    game_projection: math.Mat4,
    floating_projection: math.Mat4,
    orthographic_projection: math.Mat4,
    key_presses: EnumSet(glfw.Key),
    light_postion: math.Vec3,
    mouse_x: f32,
    mouse_y: f32,
    delta_time: f32,
    frame_time: f32,
    first_mouse: bool,
    last_x: f32,
    last_y: f32,
    run: bool,
};
