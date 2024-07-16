const std = @import("std");
const tomlz = @import("tomlz");
const math = @import("math");

const Vec3 = math.Vec3;
const vec3 = math.vec3;

const Allocator = std.mem.Allocator;

var file_stat: ?std.fs.File.Stat = null;
var settings: ?GameSettings = null;

pub const Capsule = struct {
    height: f32,
    radius: f32,

    const Self = @This();

    pub fn new(height: f32, radius: f32) Self {
        return .{ .height = height, .radius = radius };
    }
};
const PlayerSettings = struct {
    player_speed: f32 = 5.0,
    fire_interval: f32 = 0.1,
    player_collision_radius: f32 = 0.35,
    player_model_scale: f32 = 0.0044,
    player_model_gun_height: f32 = 110.0,
    player_model_gun_muzzle_offset: f32 = 100.0,
    anim_transition_time: f32 = 0.2,
};

const EnemySettings = struct {
    monster_speed: f32 = 0.6,
    enemy_spawn_interval: f32 = 1.0, // seconds
    spawns_per_interval: i32 = 1,
    spawn_radius: f32 = 10.0, // from player
    enemy_collider: Capsule = Capsule{ .height = 0.4, .radius = 0.08 },
};

const BulletSettings = struct {
    spread_amount: i32 = 20, // bullet spread
    bullet_scale: f32 = 0.3,
    bullet_lifetime: f32 = 1.0,
    bullet_speed: f32 = 15.0,
    rotation_per_bullet: f32 = 3.0, // in degrees
    burn_mark_time: f32 = 5.0, // seconds
};

const LightingSettings = struct {
    light_factor: f32 = 0.8,
    non_blue: f32 = 0.9,
    blur_scale: i32 = 2,
    floor_light_factor: f32 = 0.35,
    floor_non_blue: f32 = 0.7,
    light_direction: Vec3 = Vec3{ .x = -0.8, .y = 0.0, .z = -1.0 },
    player_light_direction: Vec3 = Vec3{ .x = -1.0, .y = -1.0, .z = -1.0 },
    muzzle_point_light_color: Vec3 = Vec3{ .x = 1.0, .y = 0.2, .z = 0.0 },
};

const GameSettings = struct {
    player_settings: PlayerSettings = PlayerSettings{},
    enemy_settings: EnemySettings = EnemySettings{},
    bullet_settings: BulletSettings = BulletSettings{},
    lighting_settings: LightingSettings = LightingSettings{},

    const Self = @This();

    pub fn get_monster_y(self: *const Self) f32 {
        return self.player_settings.player_model_scale * self.player_settings.player_model_gun_height;
    }

    pub fn getLightColor(self: *Self) Vec3 {
        return vec3(self.lighting_settings.non_blue * 0.406, self.lighting_settings.non_blue * 0.723, 1.0).mulScalar(self.lighting_settings.light_factor * 1.0);
    }

    pub fn getLightDirection(self: *Self) Vec3 {
        return self.lighting_settings.light_direction.normalize();
    }

    pub fn getPlayerLightDirection(self: *Self) Vec3 {
        return self.player_light_direction.normalize();
    }

    pub fn getAmbientColor(self: *Self) Vec3 {
        return vec3(self.lighting_settings.non_blue * 0.7, self.lighting_settings.non_blue * 0.7, 0.7).mulScalar(self.lighting_settings.light_factor * 0.10);
    }

    pub fn getFloorLightColor(self: *Self) Vec3 {
        return vec3(self.lighting_settings.floor_non_blue * 0.406, self.lighting_settings.floor_non_blue * 0.723, 1.0).mulScalar(self.lighting_settings.floor_light_factor * 1.0);
    }

    pub fn getFloorAmbientColor(self: *Self) Vec3 {
        return vec3(self.lighting_settings.floor_non_blue * 0.7, self.lighting_settings.floor_non_blue * 0.7, 0.7).mulScalar(self.lighting_settings.floor_light_factor * 0.50);
    }
};

pub fn getSettings(allocator: Allocator, path: []const u8) !GameSettings {
    var file: ?std.fs.File = null;
    file = std.fs.cwd().openFile(path, .{}) catch blk: {
        const g = GameSettings{};
        file = try std.fs.cwd().createFile(path, .{ .truncate = true });
        // var buff_out = std.io.bufferedWriter(file.?.writer());
        const writer = file.?.writer();
        try tomlz.serialize(allocator, writer, g);
        file.?.close();
        file = try std.fs.cwd().openFile(path, .{});
        break :blk file;
    };

    defer file.?.close();
    const stat = try file.?.stat();

    if (file_stat == null or file_stat.?.mtime != stat.mtime) {
        file_stat = stat;

        const toml = try file.?.readToEndAlloc(allocator, 256 * 1024);
        defer allocator.free(toml);
        settings = try tomlz.decode(GameSettings, allocator, toml);
        std.debug.print("stat = {any}\n", .{stat});
        std.debug.print("settings = {any}\n", .{settings});
    }

    return settings.?;
    // file = std.fs.cwd().createFile("./hash_log", .{ .truncate = true }) catch unreachable;
    // file = std.fs.cwd().openFile("./hash_log", .{ .read = true }) catch unreachable;

}
