#version 330 core

layout(location = 0) in vec3 pos;
layout(location = 1) in vec3 norm;
layout(location = 2) in vec2 inTex;
layout(location = 3) in vec3 tangent;
layout(location = 4) in vec3 bitangent;
layout(location = 5) in ivec4 boneIds;
layout(location = 6) in vec4 weights;

out vec2 TexCoords;

// animation
const int MAX_BONES = 100;
const int MAX_BONE_INFLUENCE = 4;
uniform mat4 finalBonesMatrices[MAX_BONES];
uniform mat4 nodeTransform;

// Transformation matrices
uniform mat4 projectionView;
uniform mat4 model;

vec4 get_animated_position() {
  vec4 totalPosition = vec4(0.0f);
//  vec3 localNormal = vec3(0.0f);
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

//    localNormal = mat3(finalBonesMatrices[boneIds[i]]) * norm;
  }
  if (totalPosition == vec4(0.0f)) {
    totalPosition = nodeTransform * vec4(pos, 1.0f);
  }
  return totalPosition;
}

void main() {
  vec4 final_position = get_animated_position();

  gl_Position = projectionView * model * final_position;

  TexCoords = inTex;
}

