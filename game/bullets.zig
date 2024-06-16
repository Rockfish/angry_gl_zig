const std = @import("std");
const core = @import("core");
const math = @import("math");
const geom = @import("geom.zig");

const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap;

const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Texture = core.Texture;
const Animation = core.Animation;
const WeightedAnimation = core.Animation.WeightedAnimation;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const TextureType = Texture.TextureType;
const Animator = Animation.Animator;
const AnimationClip = Animation.AnimationClip;
const AnimationRepeat = Animation.AnimationRepeat;

const Allocator = std.mem.Allocator;

pub const BulletGroup = struct {
    start_index: usize,
    group_size: i32,
    time_to_live: f32,

    const Self = @This();

    pub fn new(start_index: usize, group_size: i32, time_to_live: f32) Self {
        return .{
            .start_index = start_index,
            .group_size = group_size,
            .time_to_live = time_to_live,
        };
    }
};


// const BULLET_SCALE: f32 = 0.3;
const BULLET_SCALE: f32 = 0.3;
const BULLET_LIFETIME: f32 = 1.0;
// seconds
const BULLET_SPEED: f32 = 15.0;
// const BULLET_SPEED: f32 = 1.0;
// Game units per second
const ROTATION_PER_BULLET: f32 = 3.0 * PI / 180.0;

const SCALE_VEC: Vec3 = vec3(BULLET_SCALE, BULLET_SCALE, BULLET_SCALE);
const BULLET_NORMAL: Vec3 = vec3(0.0, 1.0, 0.0);
const CANONICAL_DIR: Vec3 = vec3(0.0, 0.0, 1.0);

const BULLET_COLLIDER: Capsule = Capsule { .height = 0.3, .radius = 0.03 };

const BULLET_ENEMY_MAX_COLLISION_DIST: f32 = BULLET_COLLIDER.height / 2.0 + BULLET_COLLIDER.radius + ENEMY_COLLIDER.height / 2.0 + ENEMY_COLLIDER.radius;

// Trim off margin around the bullet image
// const TEXTURE_MARGIN: f32 = 0.0625;
// const TEXTURE_MARGIN: f32 = 0.2;
const TEXTURE_MARGIN: f32 = 0.1;


const BULLET_VERTICES_H: [20]f32 = .{
    // Positions                                        // Tex Coords
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};

// vertical surface to see the bullets from the side

const BULLET_VERTICES_V: [20]f32 = .{
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};


const BULLET_VERTICES_H_V: [40]f32 = .{
    // Positions                                        // Tex Coords
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * 0.0,     0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * (-1.0),  1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};

const BULLET_INDICES: [6]f32 = .{
    0, 1, 2,
    0, 2, 3
};

const BULLET_INDICES_H_V: [12]f32 = .{
    0, 1, 2,
    0, 2, 3,
    4, 5, 6,
    4, 6, 7,
};


pub const BulletStore = struct {
    all_bullet_positions: ArrayList(Vec3),
    all_bullet_rotations: ArrayList(Quat),
    all_bullet_directions: ArrayList(Vec3),
    // thread_pool
    bullet_vao: gl.Uint,
    rotation_vbo: gl.Uint,
    offset_vbo: gl.Uint,
    bullet_groups: ArrayList(BulletGroup),
    bullet_texture: Texture,
    bullet_impact_spritesheet: SpriteSheet,
    bullet_impact_sprites: ArrayList(SpriteSheetSprite),
    unit_square_vao: i32,
    allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator, unit_square_vao: i32) Self {
        // initialize_buffer_and_create
        var bullet_vao: gl.Uint = 0;
        var bullet_vertices_vbo: gl.Uint = 0;
        var bullet_indices_ebo: gl.Uint = 0;

        var instance_rotation_vbo: gl.Uint = 0;
        var instance_offset_vbo: gl.Uint = 0;

        const texture_config = TextureConfig {
            .flip_v = false,
            .flip_h = true,
            .gamma_correction = false,
            .filter = TextureFilter.Nearest,
            .texture_type = TextureType.None,
            .wrap = TextureWrap.Repeat,
        };

        const bullet_texture = Texture.new("angrygl_assets/bullet/bullet_texture_transparent.png", &texture_config);
        // const bullet_texture = Texture.new("angrygl_assets/bullet/red_bullet_transparent.png", &texture_config);
        // const bullet_texture = Texture.new("angrygl_assets/bullet/red_and_green_bullet_transparent.png", &texture_config);

        const vertices = BULLET_VERTICES_H_V;
        const indices = BULLET_INDICES_H_V;

        gl.genVertexArrays(1, &bullet_vao);

        gl.genBuffers(1, &bullet_vertices_vbo);
        gl.genBuffers(1, &bullet_indices_ebo);

        gl.bindVertexArray(bullet_vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, bullet_vertices_vbo);

        // vertices data
        gl.bufferData(
            gl.ARRAY_BUFFER,
            (vertices.len() * SIZE_OF_FLOAT),
            vertices.as_ptr(),
            gl.STATIC_DRAW,
        );

        // indices data
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, bullet_indices_ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            (indices.len() * SIZE_OF_FLOAT),
            indices.as_ptr(),
            gl.STATIC_DRAW,
        );

        // location 0: vertex positions
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, (5 * SIZE_OF_FLOAT), null);

        // location 1: texture coordinates
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, (5 * SIZE_OF_FLOAT), (3 * SIZE_OF_FLOAT));

        // Per instance data

        // per instance rotation vbo
        gl.genBuffers(1, &instance_rotation_vbo);
        gl.bindBuffer(gl.ARRAY_BUFFER, instance_rotation_vbo);

        // location: 2: bullet rotations
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(2, 4, gl.FLOAT, gl.FALSE, SIZE_OF_QUAT, null);
        gl.vertexAttribDivisor(2, 1); // one rotation per bullet instance

        // per instance position offset vbo
        gl.genBuffers(1, &instance_offset_vbo);
        gl.bindBuffer(gl.ARRAY_BUFFER, instance_offset_vbo);

        // location: 3: bullet position offsets
        gl.enableVertexAttribArray(3);
        gl.vertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, SIZE_OF_VEC3, null);
        gl.vertexAttribDivisor(3, 1); // one offset per bullet instance

        const texture_impact_sprite_sheet = Texture.new("angrygl_assets/bullet/impact_spritesheet_with_00.png", &texture_config);
        const bullet_impact_spritesheet = SpriteSheet.new(texture_impact_sprite_sheet, 11, 0.05);

        return .{
            .all_bullet_positions = ArrayList(Vec3).init(allocator),
            .all_bullet_rotations = ArrayList(Quat).init(allocator),
            .all_bullet_directions = ArrayList(Vec3).init(allocator),
            .bullet_vao = bullet_vao,
            .rotation_vbo = instance_rotation_vbo,
            .offset_vbo = instance_offset_vbo,
            .bullet_groups = ArrayList(BulletGroup).init(allocator),
            .bullet_texture = bullet_texture,
            .bullet_impact_spritesheet = bullet_impact_spritesheet,
            .bullet_impact_sprites = ArrayList(SpriteSheetSprite).init(allocator),
            .unit_square_vao = unit_square_vao,
        };
    }

    pub fn create_bullets(self: *Self, dx: f32, dz: f32, muzzle_transform: *Mat4, spread_amount: i32) void {
        // const spreadAmount = 100;

        const muzzle_world_position = *muzzle_transform * vec4(0.0, 0.0, 0.0, 1.0);

        const projectile_spawn_point = muzzle_world_position.xyz();

        const mid_direction = vec3(dx, 0.0, dz).normalize();

        const normalized_direction = mid_direction.normalize_or_zero();

        const rot_vec = vec3(0.0, 1.0, 0.0); // rotate around y

        const x = vec3(CANONICAL_DIR.x, 0.0, CANONICAL_DIR.z).normalize_or_zero();
        const y = vec3(normalized_direction.x, 0.0, normalized_direction.z).normalize_or_zero();

        // direction angle with respect to the canonical direction
        const theta = oriented_angle(x, y, rot_vec) * -1.0;

        var mid_dir_quat = Quat.from_xyzw(1.0, 0.0, 0.0, 0.0);

        mid_dir_quat *= Quat.from_axis_angle(rot_vec, theta.to_radians());

        const start_index = self.all_bullet_positions.len();

        const bullet_group_size = spread_amount * spread_amount;

        const bullet_group = BulletGroup.new(start_index, bullet_group_size, BULLET_LIFETIME);

        self.all_bullet_positions.resize(start_index + bullet_group_size, Vec3.default());
        self.all_bullet_rotations.resize(start_index + bullet_group_size, Quat.default());
        self.all_bullet_directions.resize(start_index + bullet_group_size, Vec3.default());

        const i_start = 0;
        const i_end = spread_amount;

        const spread_centering = ROTATION_PER_BULLET * (spread_amount - 1.0) / 4.0;

        for (i_start..i_end) |i| {
            const y_quat = mid_dir_quat
                * Quat.from_axis_angle(
                    vec3(0.0, 1.0, 0.0),
                    ROTATION_PER_BULLET.mul_add((i - spread_amount) / 2.0, spread_centering),
                );

            for (0..spread_amount) |j| {
                const rot_quat = y_quat
                    * Quat.from_axis_angle(
                        vec3(1.0, 0.0, 0.0),
                        ROTATION_PER_BULLET.mul_add((j - spread_amount) / 2.0, spread_centering),
                    );

                const direction = rot_quat.mul_vec3(CANONICAL_DIR * -1.0);

                const index = (i * spread_amount + j) + start_index;

                self.all_bullet_positions[index] = projectile_spawn_point;
                self.all_bullet_directions[index] = direction;
                self.all_bullet_rotations[index] = rot_quat;
            }
        }

        self.bullet_groups.push(bullet_group);
    }

    pub fn update_bullets(self: *Self, state: *State) void {
        //}, bulletImpactSprites: &ArrayList(SpriteSheetSprite>) {

        const use_aabb = !state.enemies.is_empty();
        var num_sub_groups = undefined;
        
        if (use_aabb) { 
            num_sub_groups = 9; 
        } else { 
            num_sub_groups = 1;
        }

        const delta_position_magnitude = state.delta_time * BULLET_SPEED;

        var first_live_bullet_group: usize = 0;

        for (self.bullet_groups.items) |group| {
            group.time_to_live -= state.delta_time;

            if (group.time_to_live <= 0.0) {
                first_live_bullet_group += 1;
            } else {
                // could make this async
                const bullet_group_start_index = group.start_index;
                const num_bullets_in_group = group.group_size;
                const sub_group_size = num_bullets_in_group / num_sub_groups;

                for (0..num_sub_groups) |sub_group| {
                    var bullet_start = sub_group_size * sub_group;

                    var bullet_end = if (sub_group == (num_sub_groups - 1))
                        num_bullets_in_group
                    else
                        (bullet_start + sub_group_size);

                    bullet_start += bullet_group_start_index;
                    bullet_end += bullet_group_start_index;

                    for (bullet_start..bullet_end) |bullet_index| {
                        self.all_bullet_positions[bullet_index] += self.all_bullet_directions[bullet_index] * delta_position_magnitude;
                    }

                    var subgroup_bound_box = Aabb.new();

                    if (use_aabb) {
                        for (bullet_start..bullet_end) |bullet_index| {
                            subgroup_bound_box.expand_to_include(self.all_bullet_positions[bullet_index]);
                        }

                        subgroup_bound_box.expand_by(BULLET_ENEMY_MAX_COLLISION_DIST);
                    }

                    for (0..state.enemies.len) |i| {
                        const enemy = &state.enemies[i];

                        if (use_aabb and !subgroup_bound_box.contains_point(enemy.position)) {
                            continue;
                        }
                        for (bullet_start..bullet_end) |bullet_index| {
                            if (bullet_collides_with_enemy(
                                &self.all_bullet_positions[bullet_index],
                                &self.all_bullet_directions[bullet_index],
                                enemy,
                            )) {
                                // println!("killed enemy!");
                                enemy.is_alive = false;
                                break;
                            }
                        }
                    }
                }
            }
        }

        var first_live_bullet: usize = 0;

        if (first_live_bullet_group != 0) {
            first_live_bullet =
                self.bullet_groups[first_live_bullet_group - 1].start_index + self.bullet_groups[first_live_bullet_group - 1].group_size;
            self.bullet_groups.drain(0..first_live_bullet_group);
        }

        if (first_live_bullet != 0) {
            self.all_bullet_positions.drain(0..first_live_bullet);
            self.all_bullet_directions.drain(0..first_live_bullet);
            self.all_bullet_rotations.drain(0..first_live_bullet);

            for (self.bullet_groups.items) |group| {
                group.start_index -= first_live_bullet;
            }
        }

        if (self.bullet_impact_sprites.len != 0) {
            for (self.bullet_impact_sprites.items) |sheet| {
                sheet.age += &state.delta_time;
            }
            const sprite_duration = self.bullet_impact_spritesheet.num_columns * self.bullet_impact_spritesheet.time_per_sprite;

            self.bullet_impact_sprites.retain(|sprite| sprite.age < sprite_duration);
        }

        for (state.enemies.items) |enemy| {
            if (!enemy.is_alive) {
                self.bullet_impact_sprites.push(SpriteSheetSprite.new(enemy.position));
                state.burn_marks.add_mark(enemy.position);
                state.sound_system.play_enemy_destroyed();
            }
        }

        state.enemies.retain(|e| e.is_alive);
    }

    pub fn draw_bullets(self: *Self, shader: *Shader, projection_view: *Mat4) void {
        if (self.all_bullet_positions.len == 0) {
            return;
        }

        gl.enable(gl.BLEND);
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        // gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

        gl.depthMask(gl.FALSE);
        gl.disable(gl.CULL_FACE);

        shader.use_shader();
        shader.set_mat4("PV", projection_view);
        shader.set_bool("useLight", false);

        bind_texture(shader, 0, "texture_diffuse", self.bullet_texture);
        bind_texture(shader, 1, "texture_normal", self.bullet_texture);

        self.render_bullet_sprites();


        gl.disable(gl.BLEND);
        gl.enable(gl.CULL_FACE);
        gl.depthMask(gl.TRUE);
    }

    pub fn render_bullet_sprites(self: *Self) void {
        gl.bindVertexArray(self.bullet_vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.rotation_vbo);

        gl.bufferData(
            gl.ARRAY_BUFFER,
            (self.all_bullet_rotations.len() * SIZE_OF_QUAT),
            self.all_bullet_rotations.ptr,
            gl.STREAM_DRAW,
        );

        gl.bindBuffer(gl.ARRAY_BUFFER, self.offset_vbo);

        gl.bufferData(
            gl.ARRAY_BUFFER,
            (self.all_bullet_positions.len() * SIZE_OF_VEC3),
            self.all_bullet_positions.ptr,
            gl.STREAM_DRAW,
        );

        gl.drawElementsInstanced(
            gl.TRIANGLES,
            12, // 6,
            gl.UNSIGNED_INT,
            NULL,
            self.all_bullet_positions.len(),
        );
    }

    pub fn draw_bullet_impacts(self: *Self, sprite_shader: *Shader, projection_view: *Mat4) void {
        sprite_shader.use_shader();
        sprite_shader.set_mat4("PV", projection_view);

        sprite_shader.set_int("numCols", self.bullet_impact_spritesheet.num_columns);
        sprite_shader.set_float("timePerSprite", self.bullet_impact_spritesheet.time_per_sprite);

        bind_texture(sprite_shader, 0, "spritesheet", &self.bullet_impact_spritesheet.texture);

        gl.enable(gl.BLEND);
        // gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
        gl.depthMask(gl.FALSE);
        gl.disable(gl.CULL_FACE);

        gl.bindVertexArray(self.unit_square_vao);

        const scale: f32 = 2.0; // 0.25f32;

        for (self.bullet_impact_sprites.items) |sprite| {
            var model = Mat4.from_translation(sprite.world_position);
            model *= Mat4.from_rotation_x(math.degressToRadians(-90.0));

            // TODO: Billboarding
            // for (int i = 0; i < 3; i++)
            // {
            //     for (int j = 0; j < 3; j++)
            //     {
            //         model[i][j] = viewTransform[j][i];
            //     }
            // }

            model *= Mat4.from_scale(vec3(scale, scale, scale));

            sprite_shader.set_float("age", sprite.age);
            sprite_shader.set_mat4("model", &model);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        gl.disable(gl.BLEND);
        gl.enable(gl.CULL_FACE);
        gl.depthMask(gl.TRUE);
    }
};

fn bullet_collides_with_enemy(position: *Vec3, direction: *Vec3, enemy: *Enemy) bool {
    if (position.distance(enemy.position) > BULLET_ENEMY_MAX_COLLISION_DIST) {
        return false;
    }

    const a0 = *position - *direction * (BULLET_COLLIDER.height / 2.0);
    const a1 = *position + *direction * (BULLET_COLLIDER.height / 2.0);
    const b0 = enemy.position - enemy.dir * (ENEMY_COLLIDER.height / 2.0);
    const b1 = enemy.position + enemy.dir * (ENEMY_COLLIDER.height / 2.0);

    const closet_distance = geom.distance_between_line_segments(&a0, &a1, &b0, &b1);

    return closet_distance <= (BULLET_COLLIDER.radius + ENEMY_COLLIDER.radius);
}

pub fn rotate_by_quat(v: *Vec3, q: *Quat) Vec3 {
    const q_prime = Quat.from_xyzw(q.w, -q.x, -q.y, -q.z);
    partial_hamilton_product(&partial_hamilton_product2(q, v), &q_prime)
}

pub fn partial_hamilton_product2(quat: *Quat, vec: *Vec3) Quat {
    return Quat.from_xyzw(
        quat.w * vec.x + quat.y * vec.z - quat.z * vec.y,
        quat.w * vec.y - quat.x * vec.z + quat.z * vec.x,
        quat.w * vec.z + quat.x * vec.y - quat.y * vec.x,
        -quat.x * vec.x - quat.y * vec.y - quat.z * vec.z,
    );
}

pub fn partial_hamilton_product(q1: *Quat, q2: *Quat) Vec3 {
    return vec3(
        q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
        q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
        q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
    );
}

fn hamilton_product_quat_vec(quat: *Quat, vec: *Vec3) Quat {
    return Quat.from_xyzw(
        quat.w * vec.x + quat.y * vec.z - quat.z * vec.y,
        quat.w * vec.y - quat.x * vec.z + quat.z * vec.x,
        quat.w * vec.z + quat.x * vec.y - quat.y * vec.x,
        -quat.x * vec.x - quat.y * vec.y - quat.z * vec.z,
    );
}

fn hamilton_product_quat_quat(first: Quat, other: *Quat) Quat {
    return Quat.from_xyzw(
        first.w * other.x + first.x * other.w + first.y * other.z - first.z * other.y,
        first.w * other.y - first.x * other.z + first.y * other.w + first.z * other.x,
        first.w * other.z + first.x * other.y - first.y * other.x + first.z * other.w,
        first.w * other.w - first.x * other.x - first.y * other.y - first.z * other.z,
    );
}

// #[cfg(test)]
// mod tests {
//     use crate::geom::oriented_angle;
//     use glam::vec3;
//
//     #[test]
//     fn test_oriented_rotation() {
//         const canonical_dir = vec3(0.0, 0.0, -1.0);
//
//         for angle in 0..361 {
//             const (sin, cos) = (angle).to_radians().sin_cos();
//             const x = sin;
//             const z = cos;
//
//             const direction = vec3(x, 0.0, z);
//
//             const normalized_direction = direction; //.normalize_or_zero();
//
//             const rot_vec = vec3(0.0, 1.0, 0.0); // rotate around y
//
//             const x = vec3(canonical_dir.x, 0.0, canonical_dir.z).normalize_or_zero();
//             const y = vec3(normalized_direction.x, 0.0, normalized_direction.z).normalize_or_zero();
//
//             // direction angle with respect to the canonical direction
//             const theta = oriented_angle(x, y, rot_vec) * -1.0;
//
//             println!("angle: {}  direction: {:?}   theta: {:?}", angle, normalized_direction, theta);
//         }
//     }
// }
