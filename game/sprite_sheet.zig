const core = @import("core");
const Texture = core.Texture;

pub const SpriteSheet = struct {
    texture: Texture,
    num_columns: i32,
    time_per_sprite: f32,

    const Self = @This();

    pub fn new(texture_unit: Texture, num_columns: i32, time_per_sprite: f32) Self {
        return .{
            .texture = texture_unit,
            .num_columns = num_columns,
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
