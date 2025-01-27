const std = @import("std");
const math = @import("math");
const core = @import("core");
const world = @import("world.zig");
const geom = @import("geom.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const State = world.State;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Shader = core.Shader;
const Random = core.Random;
const Texture = core.texture.Texture;
const TextureConfig = core.texture.TextureConfig;
const TextureType = core.texture.TextureType;
const TextureWrap = core.texture.TextureWrap;
const TextureFilter = core.texture.TextureFilter;

pub const Enemy = struct {
    position: Vec3,
    dir: Vec3,
    is_alive: bool,

    const Self = @This();

    pub fn new(position: Vec3, dir: Vec3) Self {
        return .{
            .position = position,
            .dir = dir,
            .is_alive = true,
        };
    }
};

pub const EnemySystem = struct {
    count_down: f32,
    monster_y: f32,
    enemy_model: *Model,
    random: Random,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.enemy_model.deinit();
    }

    pub fn init(allocator: Allocator, texture_cache: *ArrayList(*Texture)) !Self {
        const builder = try ModelBuilder.init(allocator, texture_cache, "enemy", "angrybots_assets/Models/Eeldog/EelDog.FBX");
        defer builder.deinit();

        builder.skipModelTextures();
        const texture_diffuse = .{ .texture_type = .Diffuse, .filter = .Linear, .flip_v = true, .gamma_correction = false, .wrap = .Clamp };
        try builder.addTexture("Eeldog", texture_diffuse, "Eeldog_Albedo.png");

        std.debug.print("enemy builder created\n", .{});

        const enemy_model = builder.build() catch |err| {
            std.debug.print("EnemySystem model build error: {any}\n", .{err});
            @panic(@errorName(err));
        };

        std.debug.print("enemy model built\n", .{});
        return .{
            .count_down = world.ENEMY_SPAWN_INTERVAL,
            .monster_y = world.MONSTER_Y,
            .enemy_model = enemy_model,
            .random = Random.init(),
            .allocator = allocator,
        };
    }

    pub fn update(self: *Self, state: *State) !void {
        self.count_down -= state.delta_time;
        if (self.count_down <= 0.0) {
            for (0..world.SPAWNS_PER_INTERVAL) |_| {
                const rand_num = self.random.rand_float();
                try self.spawnEnemy(state, rand_num);
            }
            self.count_down += world.ENEMY_SPAWN_INTERVAL;
        }
    }

    pub fn spawnEnemy(self: *Self, state: *State, rand_num: f32) !void {
        const theta = math.degreesToRadians(rand_num * 360.0);
        const x = state.player.position.x + math.sin(theta) * world.SPAWN_RADIUS;
        const z = state.player.position.z + math.cos(theta) * world.SPAWN_RADIUS;

        const enemy = Enemy.new(vec3(x, self.monster_y, z), vec3(0.0, 0.0, 1.0));
        try state.enemies.append(enemy);
    }

    pub fn chase_player(self: *Self, state: *State) void {
        _ = self;
        const player_collision_position = vec3(state.player.position.x, world.MONSTER_Y, state.player.position.z);

        for (0..state.enemies.items.len) |i| {
            const enemy = &state.enemies.items[i].?;
            var dir = state.player.position.sub(&enemy.position);
            dir.y = 0.0;
            enemy.dir = dir.normalize();
            enemy.position = enemy.position.add(&enemy.dir.mulScalar(state.delta_time * world.MONSTER_SPEED));

            if (state.player.is_alive) {
                const p1 = enemy.position.sub(&enemy.dir.mulScalar(world.ENEMY_COLLIDER.height / 2.0));
                const p2 = enemy.position.sub(&enemy.dir.mulScalar(world.ENEMY_COLLIDER.height / 2.0));
                const dist = geom.distance_between_point_and_line_segment(&player_collision_position, &p1, &p2);

                if (dist <= (world.PLAYER_COLLISION_RADIUS + world.ENEMY_COLLIDER.radius)) {
                    // println!("GOTTEM!");
                    state.player.is_alive = false;
                    state.player.setPlayerDeathTime(state.frame_time);
                    state.player.direction = vec2(0.0, 0.0);
                }
            }
        }
    }

    pub fn drawEnemies(self: *Self, shader: *Shader, state: *State) void {
        shader.useShader();
        shader.setVec3("nosePos", &vec3(1.0, world.MONSTER_Y, -2.0));
        shader.setFloat("time", state.frame_time);

        for (state.enemies.items) |e| {
            const zero: f32 = 0.0;
            const val = if (e.?.dir.z < zero) zero else math.pi;
            const monster_theta = math.atan(e.?.dir.x / e.?.dir.z) + val;

            var model_transform = Mat4.fromTranslation(&e.?.position);

            model_transform = model_transform.mulMat4(&Mat4.fromScale(&Vec3.splat(0.01)));
            model_transform = model_transform.mulMat4(&Mat4.fromAxisAngle(&vec3(0.0, 1.0, 0.0), monster_theta));
            model_transform = model_transform.mulMat4(&Mat4.fromAxisAngle(&vec3(0.0, 0.0, 1.0), math.pi));
            model_transform = model_transform.mulMat4(&Mat4.fromAxisAngle(&vec3(1.0, 0.0, 0.0), math.degreesToRadians(90)));

            // var rot_only = Mat4.from_axis_angle(vec3(0.0, 1.0, 0.0), monster_theta);
            // rot_only = Mat4.from_axis_angle(vec3(0.0, 0.0, 1.0), PI);
            const rot_only = Mat4.fromAxisAngle(&vec3(1.0, 0.0, 0.0), math.degreesToRadians(90));

            shader.setMat4("aimRot", &rot_only);
            shader.setMat4("model", &model_transform);

            self.enemy_model.render(shader);
        }
    }
};
