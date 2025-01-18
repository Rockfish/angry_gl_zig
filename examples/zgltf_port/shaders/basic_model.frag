#version 330 core

in vec2 fragTexCoord;
in vec3 fragNormal;
in vec4 fragColor;

uniform int mesh_id;

uniform vec3 ambient_light;
uniform vec3 light_color;
uniform vec3 light_dir;
uniform vec4 hit_color;

uniform int has_color;
uniform int has_texture;

uniform vec4 diffuse_color;
uniform vec4 ambient_color;
uniform vec4 specular_color;
uniform vec4 emissive_color;

uniform sampler2D texture_diffuse;


// Output fragment color
out vec4 finalColor;

void main()
{
    vec4 color = vec4(1.0, 0.0, 0.0, 1.0);

    if (has_texture == 1) {
        color = texture(texture_diffuse, fragTexCoord);
    }  else {
        if (has_color == 1) {
           color = diffuse_color;
        } else {
           color = fragColor;
        }
    }

    if (color.a < 0.1) {
        discard;
    }

    vec3 ambient = 0.5 * ambient_light;
    vec3 diffuse = max(dot(fragNormal, light_dir), 0.0) * light_color;

    finalColor = color * vec4((ambient + diffuse), 1.0f);
    // finalColor = texture(texture_diffuse, fragTexCoord);
    // finalColor = color + texture(texture_diffuse, fragTexCoord) + hit_color;
    // finalColor = vec4(0.8, 0.2, 0.2, 1.0);
    // finalColor = fragColor;
}
