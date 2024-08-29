#version 330 core
out vec4 FragColor;

in vec2 TexCoord;
in vec3 normal;

uniform int mesh_id;

uniform vec3 ambient_color;
uniform vec3 light_color;
uniform vec3 light_dir;
// uniform mat4 light_space_matrix;

uniform int has_color;
uniform vec4 diffuse_color;

uniform sampler2D texture_diffuse;

uniform vec4 hit_color;

void main()
{
    vec3 ambient = 0.1 * ambient_color;
    vec3 diffuse = max(dot(normal, light_dir), 0.0) * light_color;

    vec4 color = vec4(1.0);

    if (has_color == 1) {
        color = diffuse_color + hit_color;
    } else {
        color = texture(texture_diffuse, TexCoord) + hit_color;
    }

    if (color.a < 0.1) {
        discard;
    }

    FragColor = vec4((ambient + diffuse), 1.0f) * color;
}
