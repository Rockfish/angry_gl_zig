#version 330 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inTangent;
layout(location = 4) in vec4 inColor;
layout(location = 5) in ivec4 inBoneIds;
layout(location = 6) in vec4 inWeights;

const int MAX_BONES = 100;
const int MAX_BONE_INFLUENCE = 4;

uniform mat4 finalBonesMatrices[MAX_BONES];
uniform mat4 nodeTransform;

uniform mat4 matProjection;
uniform mat4 matView;
uniform mat4 matModel;
uniform mat4 matLightSpace;

out vec2 fragTexCoord;
out vec3 fragNormal;
out vec4 fragColor;
out vec4 fragPosLightSpace;
out vec3 fragWorldPos;

//uniform mat4 aimRot;


void main() {
    vec4 totalPosition = vec4(0.0f);

    // for (int i = 0; i < MAX_BONE_INFLUENCE; i++)
    // {
    //     if (inBoneIds[i] == -1) {
    //         continue;
    //     }
    //
    //     if (inBoneIds[i] >= MAX_BONES) {
    //         totalPosition = vec4(inPosition, 1.0f);
    //         break;
    //     }
    //
    //     vec4 localPosition = finalBonesMatrices[inBoneIds[i]] * vec4(inPosition, 1.0f);
    //     totalPosition += localPosition * inWeights[i];
    //
    //     vec3 localNormal = mat3(finalBonesMatrices[inBoneIds[i]]) * inNormal;
    // }

    // This would work if the inBonesIds has zeros instead of -1
    // vec4 skinMatrix = inWeights[0] * finalBonesMatrices[inBoneIds[0]] +
    //                   inWeights[1] * finalBonesMatrices[inBoneIds[1]] +
    //                   inWeights[2] * finalBonesMatrices[inBoneIds[2]] +
    //                   inWeights[3] * finalBonesMatrices[inBoneIds[3]];
    // totalPosition = skinMatrix * vec4(inPosition, 1.0f);

    // if (totalPosition == vec4(0.0f)) {
    //     totalPosition = nodeTransform * vec4(inPosition, 1.0f);
    // }
    //
    // gl_Position = matProjection * matView * matModel * totalPosition;

    gl_Position = matProjection * matView * matModel * vec4(inPosition, 1.0f);

    fragTexCoord = inTexCoord;
    fragColor = inColor;

    //fragNormal = vec3(aimRot * vec4(inNormal, 1.0));
    mat4 matNormal = transpose(inverse(matModel));
    fragNormal = normalize(vec3(matNormal * vec4(inNormal, 1.0)));

    fragWorldPos = vec3(matModel * vec4(inPosition, 1.0));
    fragPosLightSpace = matLightSpace * vec4(fragWorldPos, 1.0);
}
