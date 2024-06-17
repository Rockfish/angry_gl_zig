const std = @import("std");
const core = @import("core");
const math = @import("math");
const gl = @import("zopengl").bindings;
const SpriteSheet = @import("sprite_sheet.zig").SpriteSheet;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const vec3 = math.vec3;
const Mat4 = math.Mat4;
const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureConfig = core.texture.TextureConfig;
const TextureType = core.texture.TextureType;
const TextureWrap = core.texture.TextureWrap;
const TextureFilter = core.texture.TextureFilter;


pub const MuzzleFlash = struct {
    unit_square_vao: c_uint,
    muzzle_flash_impact_sprite: SpriteSheet,
    muzzle_flash_sprites_age: ArrayList(f32),
    // allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator, unit_square_vao: c_uint) !Self {
        var texture_config = TextureConfig.default();
        texture_config.set_wrap(TextureWrap.Repeat);

        const texture_muzzle_flash_sprite_sheet = try Texture.new(allocator, "angrygl_assets/Player/muzzle_spritesheet.png", texture_config);
        const muzzle_flash_impact_sprite = SpriteSheet.new(texture_muzzle_flash_sprite_sheet, 6, 0.03);

        return .{
            .unit_square_vao = unit_square_vao,
            .muzzle_flash_impact_sprite = muzzle_flash_impact_sprite,
            .muzzle_flash_sprites_age = ArrayList(f32).init(allocator),
            // .allocator = allocator,
        };
    }

    pub fn update(self: *Self, delta_time: f32) void {
        if (self.muzzle_flash_sprites_age.len != 0) {
            for (0..self.muzzle_flash_sprites_age.len) |i| {
                self.muzzle_flash_sprites_age[i] += delta_time;
            }
            const max_age = self.muzzle_flash_impact_sprite.num_columns * self.muzzle_flash_impact_sprite.time_per_sprite;

            const predicate = struct {
                pub fn func (age: f32) bool {
                    return age < max_age;
                }
           };

           self.muzzle_flash_sprites_age.retain(predicate.func);
        }
    }

    pub fn get_min_age(self: *Self) f32 {
        var min_age: f32 = 1000;
        for (self.muzzle_flash_sprites_age.items) |age| {
            min_age = min_age.min(age);
        }
        return min_age;
    }

    pub fn add_flash(self: *Self) void {
        self.muzzle_flash_sprites_age.push(0.0);
    }

    pub fn draw(self: *Self, sprite_shader: *Shader, projection_view: *Mat4, muzzle_transform: *Mat4) void {
        if (self.muzzle_flash_sprites_age.len == 0) {
            return;
        }

        sprite_shader.use_shader();
        sprite_shader.set_mat4("PV", projection_view);

        gl.enable(gl.BLEND);
        gl.depthMask(gl.FALSE);
        gl.bindVertexArray(self.unit_square_vao);

        sprite_shader.bind_texture(0, "spritesheet", &self.muzzle_flash_impact_sprite.texture);

        sprite_shader.set_int("numCols", self.muzzle_flash_impact_sprite.num_columns);
        sprite_shader.set_float("timePerSprite", self.muzzle_flash_impact_sprite.time_per_sprite);

        const scale: f32 = 50.0;

        var model = *muzzle_transform * Mat4.from_scale(vec3(scale, scale, scale));

        model *= Mat4.from_rotation_x(math.degreeToRadians(-90.0));
        model *= Mat4.from_translation(vec3(0.7, 0.0, 0.0)); // adjust for position in the texture

        sprite_shader.set_mat4("model", &model);

        for (self.muzzle_flash_sprites_age.items) |sprite_age| {
            sprite_shader.set_float("age", sprite_age);
            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        gl.disable(gl.BLEND);
        gl.depthMask(gl.TRUE);
    }
};
