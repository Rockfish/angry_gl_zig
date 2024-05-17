const std = @import("std");
const zm = @import("zmath");

const Allocator = std.mem.Allocator;

pub const Transform = struct {
    translation: zm.Vec3,
    rotation: zm.Quat,
    scale: zm.Vec3,

    pub fn from_matrix(m: zm.Mat4) Transform {
        return Transform {
            .translation = zm.util.getTranslationVec(m),
            .rotation = zm.util.getRotationQuat(m),
            .scale = zm.util.getScaleVec(m),
        };
    }
};

