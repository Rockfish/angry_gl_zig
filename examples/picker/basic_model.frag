#version 330 core
out vec4 FragColor;

in vec2 TexCoords;

uniform int mesh_id;
uniform sampler2D texture_diffuse;

void main()
{
    FragColor = texture(texture_diffuse, TexCoords);
}
