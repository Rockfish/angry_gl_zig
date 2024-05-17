const std = @import("std");
const zm = @import("zmath");
// const gl = @import("zopengl").bindings;
// const Texture = @import("texture.zig").Texture;
// const ModelVertex = @import("model_mesh.zig").ModelVertex;
// const ModelMesh = @import("model_mesh.zig").ModelMesh;
// const Model = @import("model.zig").Model;
// const Animator = @import("animator.zig").Animator;
// const Assimp = @import("assimp.zig").Assimp;
// const BoneData = @import("model_animation.zig").BoneData;


const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
// const StringHashMap = std.StringHashMap;

pub const KeyPosition = struct {
    position: zm.Vec3,
    time_stamp: f32,
};

pub const KeyRotation = struct {
    orientation: zm.Quat,
    time_stamp: f32,
};

pub const KeyScale = struct {
    scale: zm.Vec3,
    time_stamp: f32,
};

pub const NodeAnimation = struct {
    name: []const u8,
    positions: ArrayList(KeyPosition),
    rotations: ArrayList(KeyRotation),
    scales: ArrayList(KeyScale),


};

