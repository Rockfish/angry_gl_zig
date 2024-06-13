#version 330 core

in vec2 TexCoords;
in vec3 Norm;
in vec4 FragPosLightSpace;
in vec3 FragWorldPos;

out vec4 FragColor;

struct DirectionLight {
  vec3 dir;
  vec3 color;
};

uniform DirectionLight directionLight;

struct PointLight {
  vec3 worldPos;
  vec3 color;
};

uniform PointLight pointLight;
uniform bool usePointLight;

uniform sampler2D texture_diffuse;
uniform sampler2D texture_specular;
uniform sampler2D texture_normals;
uniform sampler2D texture_emissive;

uniform sampler2D shadow_map;

uniform bool useLight;
uniform bool useEmissive;
uniform vec3 ambient;
uniform vec3 viewPos;

float ShadowCalculation(float bias, vec4 fragPosLightSpace) {

  vec3 projCoords = fragPosLightSpace.xyz / fragPosLightSpace.w;
  projCoords = projCoords * 0.5 + 0.5;

  float closestDepth = texture(shadow_map, projCoords.xy).r;
  float currentDepth = projCoords.z;

  bias = 0.001;
  float shadow = (currentDepth - bias) > closestDepth ? 1.0 : 0.0;
  return shadow;
}

void main() {
  vec4 color = texture(texture_diffuse, TexCoords);

  if (useLight) {

    vec3 normal = normalize(Norm);

    float shadow = 0.0;

    { // direction light

      vec3 lightDir = normalize(-directionLight.dir);

      // TODO use normal texture as well
      float diff = max(dot(normal, lightDir), 0.0);
      vec3 amb = ambient * vec3(texture(texture_diffuse, TexCoords));
      float bias = max(0.05 * (1.0 - dot(normal, lightDir)), 0.005);

      shadow = ShadowCalculation(bias, FragPosLightSpace);

      color = (1.0 - shadow) * vec4(directionLight.color, 1.0) * color * diff + vec4(amb, 1.0);
    }

    if (usePointLight) {
      vec3 lightDir = normalize(pointLight.worldPos - FragWorldPos);
      float diff = max(dot(normal, lightDir), 0.0);
      vec3 diffuse  = 0.7 * pointLight.color  * diff * vec3(texture(texture_diffuse, TexCoords));
      color += vec4(diffuse.xyz, 1.0);
    }

    if (shadow < 0.1) {  // Spec
      vec3 reflectDir = reflect(-directionLight.dir, normal);
      vec3 viewDir = normalize(viewPos - FragWorldPos);
      float shininess = 24;
      float str = 1;//0.88;
      float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
      color += str * spec * texture(texture_specular, TexCoords) * vec4(directionLight.color, 1.0);
      color += spec * 0.1 * vec4(1.0,1.0,1.0,1.0);
    }

    if (useEmissive) {
      vec4 emission = texture(texture_emissive, TexCoords);//.rgb;
      color += emission;
    }
  }

//  color = vec4(0.2, 0.8, 0.2, 1.0);
  FragColor = color;
}

