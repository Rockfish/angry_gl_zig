#version 330 core
out vec4 fragColor;

in vec2 TexCoords;

//
uniform uint object_id;
uniform uint mesh_i;
uniform int primative_id;

uniform sampler2D texture1;

void main()
{
    fragColor = texture(texture1, TexCoords);

    if (gl_PrimitiveID + 1 == primative_id) {
        fragColor = vec4(1.0, fragColor.g, fragColor.b, fragColor.a);
    }
}
