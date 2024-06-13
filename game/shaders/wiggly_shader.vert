#version 330 core

layout(location = 0) in vec3 pos;
layout(location = 1) in vec3 norm;
layout(location = 2) in vec2 tex;
layout(location = 3) in vec3 tangent;
layout(location = 4) in vec3 bitangent;
layout(location = 5) in ivec4 boneIds;
layout(location = 6) in vec4 weights;

out vec2 TexCoords;
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
  float xOffset = sin(wiggleTimeModifier * time + wiggleDistModifier * distance(nosePos, pos)) * wiggleMagnitude;

  if (depth_mode) {
    gl_Position = lightSpaceMatrix * model * vec4(pos.x + xOffset, pos.y, pos.z, 1.0);
  } else {
    gl_Position = projectionView * model * vec4(pos.x + xOffset, pos.y, pos.z, 1.0);
  }

  TexCoords = tex;

  FragPosLightSpace = lightSpaceMatrix * model * vec4(pos, 1.0);

  // TODO fix norm for wiggle
  Norm = vec3(aimRot * vec4(norm, 1.0));

  FragWorldPos = vec3(model * vec4(pos, 1.0));
}

