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
    vec4 color = vec4(1.0);

    if (has_color == 1) {
        color = diffuse_color + hit_color;
    } else {
        color = texture(texture_diffuse, TexCoord) + hit_color;
    }

    if (color.a < 0.1) {
        discard;
    }

    FragColor = color;
}
