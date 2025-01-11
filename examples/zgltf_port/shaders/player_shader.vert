#version 330 core

layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertNormal;
layout(location = 2) in vec2 vertTexCoord;
layout(location = 3) in vec3 vertTangent;
layout(location = 4) in vec4 vertColor;
layout(location = 5) in ivec4 vertBoneIds;
layout(location = 6) in vec4 vertWeights;

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
    //     if (vertBoneIds[i] == -1) {
    //         continue;
    //     }
    //
    //     if (vertBoneIds[i] >= MAX_BONES) {
    //         totalPosition = vec4(vertPosition, 1.0f);
    //         break;
    //     }
    //
    //     vec4 localPosition = finalBonesMatrices[vertBoneIds[i]] * vec4(vertPosition, 1.0f);
    //     totalPosition += localPosition * vertWeights[i];
    //
    //     vec3 localNormal = mat3(finalBonesMatrices[vertBoneIds[i]]) * vertNormal;
    // }

    // if (totalPosition == vec4(0.0f)) {
    //     totalPosition = nodeTransform * vec4(vertPosition, 1.0f);
    // }
    //
    // gl_Position = matProjection * matView * matModel * totalPosition;

    gl_Position = matProjection * matView * matModel * vec4(vertPosition, 1.0f);

    fragTexCoord = vertTexCoord;
    fragColor = vertColor;

    //fragNormal = vec3(aimRot * vec4(vertNormal, 1.0));
    mat4 matNormal = transpose(inverse(matModel));
    fragNormal = normalize(vec3(matNormal * vec4(vertNormal, 1.0)));

    fragWorldPos = vec3(matModel * vec4(vertPosition, 1.0));
    fragPosLightSpace = matLightSpace * vec4(fragWorldPos, 1.0);
}
