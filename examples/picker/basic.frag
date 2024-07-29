#version 330 core
out vec4 FragColor;

in vec2 TexCoords;

//uniform uint gObjectIndex;
//uniform uint gDrawIndex;

uniform int primative_id;
uniform sampler2D texture1;

void main()
{
    FragColor = texture(texture1, TexCoords);

    if (gl_PrimitiveID + 1 == primative_id) {
        FragColor = vec4(1.0, FragColor.g, FragColor.b, FragColor.a);
    }
}

