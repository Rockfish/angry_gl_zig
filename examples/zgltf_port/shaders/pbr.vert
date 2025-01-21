#version 400 core

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
out vec3 fragWorldPosition;
out vec2 fragTexCoord;
out vec3 fragTangent;
out vec4 fragColor;
out vec3 fragNormal;
out mat3 fragTBN;

void main() {

    mat4 matTest = finalBonesMatrices[0];

    mat3 normalMatrix = transpose(inverse(mat3(matModel)));
    vec3 N = normalize(normalMatrix * inNormal);
    vec3 T = normalize(normalMatrix * inTangent);
    T = normalize(T - dot(T, N) * N);
    vec3 B = cross(N, T);

    fragWorldPosition = vec3(matModel * vec4(inPosition, 1.0));
    fragTexCoord = inTexCoord;
    fragTangent = inTangent;
    fragColor = inColor;
    fragNormal = normalize(normalMatrix * inNormal);
    fragTBN = mat3(T, B, N);

    gl_Position = matProjection * matView * matModel * nodeTransform * vec4(inPosition, 1.0f);
}

