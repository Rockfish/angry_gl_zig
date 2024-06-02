#version 330 core

layout(location = 0) in vec3 pos;
layout(location = 1) in vec3 norm;
layout(location = 2) in vec2 tex;
layout(location = 3) in vec3 tangent;
layout(location = 4) in vec3 bitangent;
layout(location = 5) in ivec4 boneIds;
layout(location = 6) in vec4 weights;

const int MAX_BONES = 100;
const int MAX_BONE_INFLUENCE = 4;

uniform mat4 finalBonesMatrices[MAX_BONES];
uniform mat4 nodeTransform;

uniform mat4 projection;
uniform mat4 view;
uniform mat4 model;

out vec2 TexCoords;
out vec3 Norm;
out vec4 FragPosLightSpace;
out vec3 FragWorldPos;

// player Transformation matrices
uniform mat4 aimRot;
uniform mat4 lightSpaceMatrix;

void main() {

  vec4 totalPosition = vec4(0.0f);

  for(int i = 0 ; i < MAX_BONE_INFLUENCE ; i++)
  {
    if(boneIds[i] == -1) {
      continue;
    }

    if(boneIds[i] >= MAX_BONES) {
      totalPosition = vec4(pos, 1.0f);
      break;
    }

    vec4 localPosition = finalBonesMatrices[boneIds[i]] * vec4(pos, 1.0f);
    totalPosition += localPosition * weights[i];
    vec3 localNormal = mat3(finalBonesMatrices[boneIds[i]]) * norm;
  }

  if (totalPosition == vec4(0.0f)) {
    totalPosition = nodeTransform * vec4(pos, 1.0f);
  }

  gl_Position = projection * view * model * totalPosition;
//  gl_Position = projection * view * model * vec4(pos, 1.0f);

  TexCoords = tex;

  Norm = vec3(aimRot * vec4(norm, 1.0));

  FragWorldPos = vec3(model * vec4(pos, 1.0));

  FragPosLightSpace = lightSpaceMatrix * vec4(FragWorldPos, 1.0);
}
