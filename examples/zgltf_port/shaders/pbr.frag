#version 400 core

in vec3 fragWorldPosition;
in vec2 fragTexCoord;
in vec3 fragTangent;
in vec4 fragColor;
in vec3 fragNormal;
in mat3 fragTBN;

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

// Texture samplers
uniform sampler2D baseColorTexture;
uniform sampler2D metallicRoughnessTexture;
uniform sampler2D normalTexture;
uniform sampler2D occlusionTexture;
uniform sampler2D emissiveTexture;

// Flags indicating texture availability
uniform bool has_baseColorTexture;
uniform bool has_metallicRoughnessTexture;
uniform bool has_normalTexture;
uniform bool has_occlusionTexture;
uniform bool has_emissiveTexture;

// Output fragment color
out vec4 finalColor;

const float PI = 3.14159265359;

void main() {
    // Base Color
    vec4 baseColor = material.baseColorFactor;
    if (has_baseColorTexture) {
        baseColor *= texture(baseColorTexture, fragTexCoord);
    }

    // Metallic-Roughness
    vec4 metallicRoughness = vec4(1.0);
    if (has_metallicRoughnessTexture) {
        metallicRoughness = texture(metallicRoughnessTexture, fragTexCoord);
    }
    // glTF: metallic is in the blue channel and roughness is in the green channel
    float metallic = material.metallicFactor * metallicRoughness.b;
    float roughness = material.roughnessFactor * metallicRoughness.g;
 
    // Normal Mapping
    vec3 normal = fragNormal;
    if (has_normalTexture) {
        vec3 normalMap = texture(normalTexture, fragTexCoord).xyz * 2.0 - 1.0;
        normal = normalize(fragTBN * normalMap);
    }

    // Lighting calculations
    vec3 lightDir = normalize(lightPosition - fragWorldPosition);
    vec3 viewDir = normalize(viewPosition - fragWorldPosition);
    vec3 halfDir = normalize(lightDir + viewDir);

    float dist = length(lightPosition - fragWorldPosition);
    float attenuation = 1.0 / (dist * dist);
    vec3 radiance = lightColor * lightIntensity * attenuation;

    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float NdotH = max(dot(normal, halfDir), 0.0);

    // Fresnel-Schlick approximation
    vec3 F0 = mix(vec3(0.04), baseColor.rgb, metallic);
    vec3 F = F0 + (1.0 - F0) * pow(1.0 - NdotV, 5.0);

    // Microfacet Distribution (GGX)
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
    float denom = (NdotH * NdotH * (alpha2 - 1.0) + 1.0);
    float D = alpha2 / (PI * denom * denom);

    // Geometry function (Schlick-GGX)
    float k = alpha / 2.0;  // Alternative formulations exist (e.g., k = (roughness + 1)^2 / 8)
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    float G = G_V * G_L;

    // Specular term
    vec3 specular = (F * D * G) / (4.0 * NdotV * NdotL + 0.0001);

    // Diffuse term (energy conservation: non-metallic surfaces contribute to diffuse)
    vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);
    vec3 diffuse = kD * baseColor.rgb / PI;

    // Combined lighting contribution
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

    finalColor = vec4(color + emissive, baseColor.a);
}
