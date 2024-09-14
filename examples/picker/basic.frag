#version 330 core

in vec2 TexCoord;

out vec4 FragColor;

uniform uint object_id;
uniform uint mesh_id;
uniform int primative_id;

uniform sampler2D texture_diffuse;

void main()
{
    FragColor = texture(texture_diffuse, TexCoord);

    if (gl_PrimitiveID + 1 == primative_id) {
        FragColor = vec4(1.0, FragColor.g, FragColor.b, FragColor.a);
    }
}
