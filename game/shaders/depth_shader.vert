#version 330 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inTangent;
layout(location = 4) in vec3 inBiTangent;
layout(location = 5) in ivec4 inBoneIds;
layout(location = 6) in vec4 inWeights;

// player animation
const int MAX_BONES = 100;
const int MAX_BONE_INFLUENCE = 4;

uniform mat4 finalBonesMatrices[MAX_BONES];
uniform mat4 nodeTransform;

uniform mat4 lightSpaceMatrix;
uniform mat4 model;

vec4 get_animated_position() {
    vec4 totalPosition = vec4(0.0f);
    vec3 localNormal = vec3(0.0f);

    for (int i = 0; i < MAX_BONE_INFLUENCE; i++)
    {
        if (inBoneIds[i] == -1) {
            continue;
        }

        if (inBoneIds[i] >= MAX_BONES) {
            totalPosition = vec4(inPosition, 1.0f);
            break;
        }

        vec4 localPosition = finalBonesMatrices[inBoneIds[i]] * vec4(inPosition, 1.0f);
        totalPosition += localPosition * inWeights[i];

        localNormal = mat3(finalBonesMatrices[inBoneIds[i]]) * inNormal;
    }

    if (totalPosition == vec4(0.0f)) {
        totalPosition = nodeTransform * vec4(inPosition, 1.0f);
    }

    return totalPosition;
}

void main() {
    vec4 final_position = get_animated_position();

    gl_Position = lightSpaceMatrix * model * final_position;
}
