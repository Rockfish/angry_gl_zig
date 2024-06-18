const math = @import("math");
const core = @import("core");

const Vec3 = math.Vec3;

const Texture = core.texture.Texture;
const TextureConfig = core.texture.TextureConfig;
const TextureType = core.texture.TextureType;
const TextureWrap = core.texture.TextureWrap;
const TextureFilter = core.texture.TextureFilter;

pub const SpriteSheet = struct {
    texture: Texture,
    num_columns: f32,
    time_per_sprite: f32,

    const Self = @This();

    pub fn new(texture_unit: Texture, num_columns: i32, time_per_sprite: f32) Self {
        return .{
            .texture = texture_unit,
            .num_columns = @floatFromInt(num_columns),
            .time_per_sprite = time_per_sprite,
        };
    }
};

pub const SpriteSheetSprite = struct {
    world_position: Vec3,
    age: f32,

    const Self = @This();

    pub fn new(world_position: Vec3) Self {
        return .{ .world_position = world_position, .age = 0.0 };
    }
};
