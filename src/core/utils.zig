
const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;

pub fn mat4_from_aiMatrix(aiMatrix: Assimp.aiMatrix4x4) zm.Mat4 {
    // todo: implement mat4_from_aiMatrix
    _ = aiMatrix;
    return zm.identity();
}

pub fn vec3_from_aiVector3D(vec3d: Assimp.aiVector3D) zm.Vec3 {
    return .{vec3d.x, vec3d.y, vec3d.z };
}

pub fn quat_from_aiQuaternion(ai_quad: Assimp.aiQuaternion) zm.Quat {
    // todo: implment quat_from_aiQuaternion
    _ = ai_quad;
    return .{0.0, 0.0, 0.0, 1.0};
}