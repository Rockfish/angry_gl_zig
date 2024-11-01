#version 330 core

in vec2 fragTexCoord;
in vec3 fragNormal;

uniform int mesh_id;

uniform vec3 ambient_color;
uniform vec3 light_color;
uniform vec3 light_dir;

uniform int has_color;
uniform vec4 diffuse_color;

uniform sampler2D texture_diffuse;

uniform vec4 hit_color;

// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 color = vec4(1.0);

    if (has_color == 1) {
        color = diffuse_color + hit_color;
    } else {
        color = texture(texture_diffuse, fragTexCoord) + hit_color;
    }

    if (color.a < 0.1) {
        discard;
    }

    vec3 ambient = 0.25 * ambient_color;
    vec3 diffuse = max(dot(fragNormal, light_dir), 0.0) * light_color;

    finalColor = color; // * vec4((ambient + diffuse), 1.0f);
}
