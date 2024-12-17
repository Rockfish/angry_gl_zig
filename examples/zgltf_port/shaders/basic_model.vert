#version 330 core
layout(location = 0) in vec3 vertPosition;
layout(location = 1) in vec3 vertNormal;
layout(location = 2) in vec2 vertTexCoord;
layout(location = 3) in vec3 vertTangent;
layout(location = 4) in vec3 vertBiTangent;
layout(location = 5) in ivec4 vertBoneIds;
layout(location = 6) in vec4 vertWeights;

uniform mat4 matModel;
uniform mat4 matView;
uniform mat4 matProjection;

out vec2 fragTexCoord;
out vec3 fragNormal;

void main()
{
    fragTexCoord = vertTexCoord;
    gl_Position = matProjection * matView * matModel * vec4(vertPosition, 1.0);

    mat4 matNormal = transpose(inverse(matModel));
    fragNormal = normalize(vec3(matNormal * vec4(vertNormal, 1.0)));
}
