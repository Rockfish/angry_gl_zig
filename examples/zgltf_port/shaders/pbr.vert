#version 330 core

// Input attributes
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


// Output
out vec3 fragWorldPos;
out vec2 fragTexCoord;
out vec3 fragTangent;
out vec4 fragColor;
out vec3 fragNormal;
out vec4 fragPosLightSpace;

void main() {

    mat4 matTest = finalBonesMatrices[0];
    mat4 nodeMat = nodeTransform;

    gl_Position = matProjection * matView * matModel * vec4(inPosition, 1.0f);

    fragTexCoord = inTexCoord;
    fragColor = inColor;
    fragTangent = inTangent;

    //fragNormal = vec3(aimRot * vec4(inNormal, 1.0));
    mat4 matNormal = transpose(inverse(matModel));
    fragNormal = normalize(vec3(matNormal * vec4(inNormal, 1.0)));

    fragWorldPos = vec3(matModel * vec4(inPosition, 1.0));
    fragPosLightSpace = matLightSpace * vec4(fragWorldPos, 1.0);
}

