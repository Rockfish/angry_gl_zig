#version 330 core
out vec4 FragColor;

in vec2 TexCoord;

uniform int mesh_id;

uniform int has_color;
uniform vec4 diffuse_color;

//uniform int has_texture;
uniform sampler2D texture_diffuse;

uniform vec4 hit_color;

void main()
{
    if (has_color == 1) {
        FragColor = diffuse_color + hit_color;
    } else {
        FragColor = texture(texture_diffuse, TexCoord) + hit_color;
    }
}
