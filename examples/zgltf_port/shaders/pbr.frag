#version 400 core

in vec3 fragWorldPosition;
in vec2 fragTexCoord;
in vec3 fragTangent;
in vec4 fragColor;
in vec3 fragNormal;
in mat3 fragTBN;

// Light source
// struct PointLight
// {
//     vec3 position;
//     vec3 color;
//     float intensity;
// };
//
// uniform PointLight pointLight;

uniform vec3 lightPosition;
uniform vec3 lightColor;
uniform float lightIntensity;

uniform vec3 viewPosition;

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
// GLTF 2.0 spec: metallicRoughness
// the green channel contains roughness values
// the blue channel contains metalness values
uniform sampler2D metallicRoughnessTexture;
uniform sampler2D normalTexture;
uniform sampler2D occlusionTexture;
uniform sampler2D emissiveTexture;

// Flags
uniform bool has_baseColorTexture;
uniform bool has_metallicRoughnessTexture;
uniform bool has_normalTexture;
uniform bool has_occlusionTexture;
uniform bool has_emissiveTexture;

// Output fragment color
out vec4 finalColor;

void main() {

    // Base Color
    vec4 baseColor = texture(baseColorTexture, fragTexCoord) * material.baseColorFactor;

    vec4 metallicRoughness = texture(metallicRoughnessTexture, fragTexCoord);

    float metallic = material.metallicFactor * metallicRoughness.r;
    float roughness = material.roughnessFactor * metallicRoughness.g;

    // Normal Mapping
    vec3 normalMap = texture(normalTexture, fragTexCoord).xyz * 2.0 - 1.0; // [-1, 1]

    vec3 normal = normalize(fragTBN * normalMap);

    // Lighting (Basic PBR)
    vec3 lightDir = normalize(lightPosition - fragWorldPosition);
    vec3 viewDir = normalize(viewPosition - fragWorldPosition);
    vec3 halfDir = normalize(lightDir + viewDir);

    float dist = length(lightPosition - fragWorldPosition);
    float attenuation = 1.0 / (dist * dist);
    vec3 radiance = lightColor * lightIntensity; //  * attenuation;

    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float NdotH = max(dot(normal, halfDir), 0.0);

    // Fresnel-Schlick Approximation
    vec3 F0 = mix(vec3(0.04), baseColor.rgb, metallic);
    vec3 F = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);

    // Distribution and Geometry
    float alpha = roughness * roughness;
    float D = (alpha * alpha) / (3.14159 * pow(NdotH * NdotH * (alpha * alpha - 1.0) + 1.0, 2.0));
    float G = min(1.0, 2.0 * NdotH * min(NdotV, NdotL) / (dot(viewDir, halfDir) + 0.0001));

    vec3 specular = F * D * G / (4.0 * NdotV * NdotL + 0.0001);
    vec3 diffuse = (1.0 - F) * baseColor.rgb / 3.14159;

    // temp
    diffuse = baseColor.rgb;

    // testing adding radiance

    vec3 color = (diffuse + specular) * NdotL * radiance;

    // Occlusion
    if (has_occlusionTexture) {
      float occlusion = texture(occlusionTexture, fragTexCoord).r;
      color *= occlusion;
    }

    // Emissive
    vec3 emissive = vec3(0.0);
    if (has_emissiveTexture) {
      emissive = material.emissiveFactor * texture(emissiveTexture, fragTexCoord).rgb;
    }

    // Final color
    finalColor = vec4(color + emissive, baseColor.a);
}


