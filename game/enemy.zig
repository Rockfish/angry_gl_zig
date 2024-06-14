const std = @import("std");
const core = @import("core");
const math = @import("math");

const Model = core.Model;
const ModelBuilder = core.ModelBuilder;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

pub const ENEMY_COLLIDER: Capsule = Capsule { .height = 0.4, .radius = 0.08 };

pub const Enemy = struct {
    position: Vec3,
    dir: Vec3,
    is_alive: bool,

    const Self = @This();

    pub fn new(position: Vec3, dir: Vec3) Self {
        return . {
            .position = position,
            .dir = dir,
            .is_alive = true
        };
    }
};

const ENEMY_SPAWN_INTERVAL: f32 = 1.0; // seconds
const SPAWNS_PER_INTERVAL: i32 = 1;
const SPAWN_RADIUS: f32 = 10.0; // from player

pub const EnemySystem = struct {
    count_down: f32,
    monster_y: f32,
    enemy_model: Model,

    const Self = @This();

    pub fn new() Self {
        const enemy_model = ModelBuilder.new("enemy", "assets/Models/Eeldog/EelDog.FBX").build();
        return .{
            .count_down = ENEMY_SPAWN_INTERVAL,
            .monster_y = MONSTER_Y,
            .enemy_model = enemy_model,
        };
    }

    pub fn update(self: *Self, state: *State) void {
        self.count_down -= state.delta_time;
        if (self.count_down <= 0.0) {
            for (0..SPAWNS_PER_INTERVAL) |_| {
                self.spawn_enemy(state);
            }
            self.count_down += ENEMY_SPAWN_INTERVAL;
        }
    }

    pub fn spawn_enemy(self: *Self, state: *State) void {
        const theta = (rand_float() * 360.0).to_radians();
        // const x = state.player.borrow().position.x + theta.sin() * SPAWN_RADIUS;
        // const z = state.player.borrow().position.z + theta.cos() * SPAWN_RADIUS;
        const x = theta.sin().mul_add(SPAWN_RADIUS, state.player.borrow().position.x);
        const z = theta.cos().mul_add(SPAWN_RADIUS, state.player.borrow().position.z);
        state.enemies.push(Enemy.new(vec3(x, self.monster_y, z), vec3(0.0, 0.0, 1.0)));
    }

    pub fn chase_player(self: *Self, state: *State) void {
        var player = state.player.borrow_mut();
        const player_collision_position = vec3(player.position.x, MONSTER_Y, player.position.z);

        for (state.enemies.items) |enemy| {
            var dir = player.position - enemy.position;
            dir.y = 0.0;
            enemy.dir = dir.normalize_or_zero();
            enemy.position += enemy.dir * state.delta_time * MONSTER_SPEED;

            if (player.is_alive) {
                const p1 = enemy.position - enemy.dir * (ENEMY_COLLIDER.height / 2.0);
                const p2 = enemy.position + enemy.dir * (ENEMY_COLLIDER.height / 2.0);
                const dist = distance_between_point_and_line_segment(&player_collision_position, &p1, &p2);

                if (dist <= (PLAYER_COLLISION_RADIUS + ENEMY_COLLIDER.radius)) {
                    // println!("GOTTEM!");
                    player.is_alive = false;
                    player.set_player_death_time(state.frame_time);
                    player.direction = vec2(0.0, 0.0);
                }
            }
        }
    }

    pub fn draw_enemies(self: *Self, shader: *Shader, state: *State) void {
        shader.use_shader();
        shader.set_vec3("nosePos", &vec3(1.0, MONSTER_Y, -2.0));
        shader.set_float("time", state.frame_time);

        for (state.enemies.items) |e| {
            var val = math.pi;
            if (e.dir.z < 0.0) {
                val = 0.0;
            }
            const monster_theta = (e.dir.x / e.dir.z).atan() + val;

            var model_transform = Mat4.from_translation(e.position);

            model_transform *= Mat4.from_scale(Vec3.splat(0.01));
            model_transform *= Mat4.from_axis_angle(vec3(0.0, 1.0, 0.0), monster_theta);
            model_transform *= Mat4.from_axis_angle(vec3(0.0, 0.0, 1.0), PI);
            model_transform *= Mat4.from_axis_angle(vec3(1.0, 0.0, 0.0), math.degreesToRadians(90));

            // var rot_only = Mat4.from_axis_angle(vec3(0.0, 1.0, 0.0), monster_theta);
            // rot_only = Mat4.from_axis_angle(vec3(0.0, 0.0, 1.0), PI);
            const rot_only = Mat4.from_axis_angle(vec3(1.0, 0.0, 0.0), math.degreesToRadians(90));

            shader.set_mat4("aimRot", &rot_only);
            shader.set_mat4("model", &model_transform);

            self.enemy_model.render(shader);
        }
    }
};
