#version 450

// Input attributes
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoords;
layout(location = 3) in vec3 inTangent;

// Output color
layout(location = 0) out vec4 outColor;

// Material uniforms
layout(set = 0, binding = 0) uniform Material {
    vec4 baseColorFactor;         // Base color multiplier
    float metallicFactor;         // Scalar metallic factor
    float roughnessFactor;        // Scalar roughness factor
    vec3 emissiveFactor;          // Emissive color
} material;

// Texture samplers
layout(set = 0, binding = 1) uniform sampler2D baseColorTexture;
layout(set = 0, binding = 2) uniform sampler2D metallicRoughnessTexture;
layout(set = 0, binding = 3) uniform sampler2D normalTexture;
layout(set = 0, binding = 4) uniform sampler2D occlusionTexture;
layout(set = 0, binding = 5) uniform sampler2D emissiveTexture;

// Light source
uniform vec3 lightPosition;
uniform vec3 viewPosition;

void main() {
    // Base Color
    vec4 baseColor = texture(baseColorTexture, inTexCoords) * material.baseColorFactor;

    // Metallic and Roughness
    vec4 metallicRoughness = texture(metallicRoughnessTexture, inTexCoords);
    float metallic = material.metallicFactor * metallicRoughness.r;
    float roughness = material.roughnessFactor * metallicRoughness.g;

    // Normal Mapping
    vec3 normalMap = texture(normalTexture, inTexCoords).xyz * 2.0 - 1.0; // [-1, 1]
    vec3 T = normalize(inTangent);
    vec3 N = normalize(inNormal);
    vec3 B = cross(N, T);
    mat3 TBN = mat3(T, B, N); // Tangent space to world space
    vec3 normal = normalize(TBN * normalMap);

    // Lighting (Basic PBR)
    vec3 lightDir = normalize(lightPosition - inPosition);
    vec3 viewDir = normalize(viewPosition - inPosition);
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

    // Occlusion
    float occlusion = texture(occlusionTexture, inTexCoords).r;
    color *= occlusion;

    // Emissive
    vec3 emissive = material.emissiveFactor * texture(emissiveTexture, inTexCoords).rgb;

    // Final color
    outColor = vec4(color + emissive, baseColor.a);
}

