pub const Assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

const std = @import("std");
const math = @import("math");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub fn mat4_from_aiMatrix(aiMat: *const Assimp.aiMatrix4x4) Mat4 {
    const data: [4][4]f32 = .{
        .{aiMat.a1, aiMat.b1, aiMat.c1, aiMat.d1}, // m00, m01, m02, m03
        .{aiMat.a2, aiMat.b2, aiMat.c2, aiMat.d2}, // m10, m11, m12, m13
        .{aiMat.a3, aiMat.b3, aiMat.c3, aiMat.d3}, // m20, m21, m22, m23
        .{aiMat.a4, aiMat.b4, aiMat.c4, aiMat.d4}, // m30, m31, m32, m33
    };
    //std.debug.print("aiMatrix = {any}\nmat = {any}\n", .{aiMat, zm.matToArr(mat4)});
    return Mat4 { .data = data };
}

pub fn vec3_from_aiVector3D(vec3d: Assimp.aiVector3D) Vec3 {
    return .{.x = vec3d.x, .y = vec3d.y, .z = vec3d.z };
}

pub fn quat_from_aiQuaternion(aiQuat: Assimp.aiQuaternion) Quat {
    return Quat { .data =.{aiQuat.x, aiQuat.y, aiQuat.z, aiQuat.w} };
}

// transform = Transform.from_matrix(mat4_from_aiMatrix(aiMat));
// pub fn transfrom_from_aiMatrix(aiMat: Assimp.aiMatrix4x4) Transform {
//     const mat = mat4_from_aiMatrix(aiMat);
//     const transform = Transform.from_matrix(mat);
//     return transform;
// }