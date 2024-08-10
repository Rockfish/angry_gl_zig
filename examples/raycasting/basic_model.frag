#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform int mesh_id;
uniform sampler2D texture_diffuse;
uniform vec4 hit_color;

void main()
{
    FragColor = texture(texture_diffuse, TexCoord) + hit_color;
}
