const std = @import("std");
const glfw = @import("zglfw");
const set = @import("ziglangSet");
const core = @import("core");
const math = @import("math");

const Player = @import("player.zig").Player;
const Enemy = @import("enemy.zig").Enemy;
const EnemySystem = @import("enemy.zig").EnemySystem;
const BulletStore = @import("bullets.zig").BulletStore;
const BurnMarks = @import("burn_marks.zig").BurnMarks;
const MuzzleFlash = @import("muzzle_flash.zig").MuzzleFlash;
const Floor = @import("floor.zig").Floor;
const SoundSystem = @import("sound_system.zig").SoundSystem;
const fb = @import("framebuffers.zig");
const quads = @import("quads.zig");

const ArrayList = std.ArrayList;

const Assimp = core.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Animation = core.Animation;
const Texture = core.Texture;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.String;
const FrameCount = core.FrameCount;

// Player
pub const FIRE_INTERVAL: f32 = 0.1;
// seconds
pub const SPREAD_AMOUNT: i32 = 20;

pub const PLAYER_COLLISION_RADIUS: f32 = 0.35;

// Models
pub const PLAYER_MODEL_SCALE: f32 = 0.0044;
//const PLAYER_MODEL_GUN_HEIGHT: f32 = 120.0; // un-scaled
pub const PLAYER_MODEL_GUN_HEIGHT: f32 = 110.0;
// un-scaled
pub const PLAYER_MODEL_GUN_MUZZLE_OFFSET: f32 = 100.0;
// un-scaled
pub const MONSTER_Y: f32 = PLAYER_MODEL_SCALE * PLAYER_MODEL_GUN_HEIGHT;
// Enemies
pub const MONSTER_SPEED: f32 = 0.6;

const CameraType = enum {
    Game,
    Floating,
    TopDown,
    Side,
};

pub const State = struct {
    game_camera: *Camera,
    floating_camera: *Camera,
    ortho_camera: *Camera,
    active_camera: CameraType,
    player: *Player,
    enemies: std.ArrayList(*Enemy),
    burn_marks: *BurnMarks,
    sound_system: *SoundSystem,
    game_projection: math.Mat4,
    floating_projection: math.Mat4,
    orthographic_projection: math.Mat4,
    key_presses: set.Set(glfw.Key),
    light_postion: math.Vec3,
    mouse_x: f32,
    mouse_y: f32,
    delta_time: f32,
    frame_time: f32,
    last_frame: f32,
    first_mouse: bool,
    last_x: f32,
    last_y: f32,
    run: bool,
};

