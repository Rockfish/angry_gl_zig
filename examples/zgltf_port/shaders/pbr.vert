#version 400 core

// Input attributes
layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inTangent;
layout(location = 4) in vec4 inColor;

// Uniforms
uniform mat4 matProjection;
uniform mat4 matView;
uniform mat4 matModel;
uniform mat4 nodeTransform;

// Outputs to the fragment shader
out vec3 fragWorldPosition;
out vec2 fragTexCoord;
out vec3 fragTangent;
out vec4 fragColor;
out vec3 fragNormal;
out mat3 fragTBN;

void main() {
    // Compute the normal matrix from the model matrix for correct normal transformation.
    mat3 normalMatrix = transpose(inverse(mat3(matModel)));

    // Transform the normal and tangent into world space.
    vec3 N = normalize(normalMatrix * inNormal);
    vec3 T = normalize(normalMatrix * inTangent);

    // Re-orthogonalize the tangent relative to the normal.
    T = normalize(T - dot(T, N) * N);

    // Compute the bitangent using the cross product.
    vec3 B = cross(N, T);

    // Compute the world-space position using both matModel and nodeTransform.
    vec4 worldPos = matModel * nodeTransform * vec4(inPosition, 1.0);
    fragWorldPosition = worldPos.xyz;

    // Pass through texture coordinates and vertex color.
    fragTexCoord = inTexCoord;
    fragColor = inColor;

    // Output the transformed normal.
    fragNormal = N;

    // Construct the TBN matrix to transform normals from tangent space to world space.
    fragTBN = mat3(T, B, N);

    // Compute the final vertex position in clip space.
    gl_Position = matProjection * matView * matModel * nodeTransform * vec4(inPosition, 1.0);
}
