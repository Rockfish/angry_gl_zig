#version 330 core

in vec3 fragWorldPos;
in vec2 fragTexCoord;
in vec3 fragTangent;
in vec4 fragColor;
in vec3 fragNormal;

// Light source
uniform vec3 lightPosition;
uniform vec3 viewPosition;

// Flags
uniform int has_normalTexture;
uniform int has_occlusion;
uniform int has_emissive;

// Material uniforms
// uniform Material {
//     vec4 baseColorFactor;         // Base color multiplier
//     float metallicFactor;         // Scalar metallic factor
//     float roughnessFactor;        // Scalar roughness factor
//     vec3 emissiveFactor;          // Emissive color
// } material;

struct Material {
    vec4 baseColorFactor;
    float metallicFactor;
    float roughnessFactor;
    vec3 emissiveFactor;
};

uniform Material material;

uniform vec4 material_baseColorFactor;

// Texture samplers
uniform sampler2D baseColorTexture;
uniform sampler2D metallicRoughnessTexture;
uniform sampler2D normalTexture;
uniform sampler2D occlusionTexture;
uniform sampler2D emissiveTexture;

// Output fragment color
out vec4 finalColor;

void main() {

    // Base Color
    vec4 baseColor = texture(baseColorTexture, fragTexCoord) * material.baseColorFactor;
    //vec3 color = baseColor.xyz;

    // if (has_normalTexture) {
      // Metallic and Roughness
      vec4 metallicRoughness = texture(metallicRoughnessTexture, fragTexCoord);
      float metallic = material.metallicFactor * metallicRoughness.r;
      float roughness = material.roughnessFactor * metallicRoughness.g;

      // Normal Mapping
      vec3 normalMap = texture(normalTexture, fragTexCoord).xyz * 2.0 - 1.0; // [-1, 1]
      vec3 T = normalize(fragTangent);
      vec3 N = normalize(fragNormal);
      vec3 B = cross(N, T);
      mat3 TBN = mat3(T, B, N); // Tangent space to world space
      vec3 normal = normalize(TBN * normalMap);

      // Lighting (Basic PBR)
      vec3 lightDir = normalize(lightPosition - fragWorldPos);
      vec3 viewDir = normalize(viewPosition - fragWorldPos);
      vec3 halfDir = normalize(lightDir + viewDir);

      float NdotL = max(dot(normal, lightDir), 0.0);
      float NdotV = max(dot(normal, viewDir), 0.0);
      float NdotH = max(dot(normal, halfDir), 0.0);

      // Fresnel-Schlick Approximation
      vec3 F0 = mix(vec3(0.04), baseColor.rgb, metallic);
      vec3 F = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);

      // Distribution and Geometry
      float alpha = roughness * roughness;
      float D = (alpha * alpha) / (3.14159 * pow(NdotH * NdotH * (alpha * alpha - 1.0) + 1.0, 2.0));
      float G = min(1.0, 2.0 * NdotH * min(NdotV, NdotL) / (dot(viewDir, halfDir) + 1e-5));

      vec3 specular = F * D * G / (4.0 * NdotV * NdotL + 1e-5);
      vec3 diffuse = (1.0 - F) * baseColor.rgb / 3.14159;

      vec3 color = (diffuse + specular) * NdotL;
    // }

    // Occlusion
    // if (has_occlusion == 1) {
      float occlusion = texture(occlusionTexture, fragTexCoord).r;
      color *= occlusion;
    // }

    // Emissive
    vec3 emissive = vec3(0.0);
    // if (has_emissive == 1) {
      emissive = material.emissiveFactor * texture(emissiveTexture, fragTexCoord).rgb;
    // }

    // Final color
    finalColor = vec4(color + emissive, baseColor.a);
    //finalColor = baseColor;
}


