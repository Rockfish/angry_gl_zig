
pub const Capsule = struct {
    height: f32,
    radius: f32,

    pub fn new(height: f32, radius: f32) Self {
        return .{ .height = height, .radius = radius };
    }
};
