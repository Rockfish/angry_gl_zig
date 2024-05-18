const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;

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

    pub fn from_aiMatrix(m: Assimp.aiMatrix4x4) Transform {
        // todo!
        _ = m;

        return Transform {
            .translation = undefined,
            .rotation = undefined,
            .scale = undefined,
        };
    }
};

