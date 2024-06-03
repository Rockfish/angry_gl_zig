pub const Assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});
const zm = @import("zmath");

pub fn mat4_from_aiMatrix(aiMat: Assimp.aiMatrix4x4) zm.Mat4 {
    const mat4 = zm.Mat4 {
        zm.f32x4(aiMat.a1, aiMat.b1, aiMat.c1, aiMat.d1), // m00, m01, m02, m03
        zm.f32x4(aiMat.a2, aiMat.b2, aiMat.c2, aiMat.d2), // m10, m11, m12, m13
        zm.f32x4(aiMat.a3, aiMat.b3, aiMat.c3, aiMat.d3), // m20, m21, m22, m23
        zm.f32x4(aiMat.a4, aiMat.b4, aiMat.c4, aiMat.d4), // m30, m31, m32, m33
    };
    return mat4;
}

pub fn vec4_from_aiVector3D(vec3d: Assimp.aiVector3D) zm.Vec4 {
    return .{vec3d.x, vec3d.y, vec3d.z, 0.0 };
}

pub fn quat_from_aiQuaternion(aiQuat: Assimp.aiQuaternion) zm.Quat {
    return .{aiQuat.x, aiQuat.y, aiQuat.z, aiQuat.w};
}

// transform = Transform.from_matrix(mat4_from_aiMatrix(aiMat));
// pub fn transfrom_from_aiMatrix(aiMat: Assimp.aiMatrix4x4) Transform {
//     const mat = mat4_from_aiMatrix(aiMat);
//     const transform = Transform.from_matrix(mat);
//     return transform;
// }