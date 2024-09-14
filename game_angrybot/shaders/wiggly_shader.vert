#version 330 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inTangent;
layout(location = 4) in vec3 inBiTangent;
layout(location = 5) in ivec4 inBoneIds;
layout(location = 6) in vec4 inWeights;

out vec2 TexCoord;
out vec3 Norm;
out vec4 FragPosLightSpace;
out vec3 FragWorldPos;

uniform mat4 projectionView;
uniform mat4 model;
uniform mat4 aimRot;
uniform mat4 lightSpaceMatrix;

uniform vec3 nosePos;
uniform float time;

uniform bool depth_mode;

const float wiggleMagnitude = 3.0;
const float wiggleDistModifier = 0.12;
const float wiggleTimeModifier = 9.4;

void main() {
    float xOffset = sin(wiggleTimeModifier * time + wiggleDistModifier * distance(nosePos, inPosition)) * wiggleMagnitude;

    if (depth_mode) {
        gl_Position = lightSpaceMatrix * model * vec4(inPosition.x + xOffset, inPosition.y, inPosition.z, 1.0);
    } else {
        gl_Position = projectionView * model * vec4(inPosition.x + xOffset, inPosition.y, inPosition.z, 1.0);
    }

    TexCoord = inTexCoord;

    FragPosLightSpace = lightSpaceMatrix * model * vec4(inPosition, 1.0);

    // TODO fix norm for wiggle
    Norm = vec3(aimRot * vec4(inNormal, 1.0));

    FragWorldPos = vec3(model * vec4(inPosition, 1.0));
}
