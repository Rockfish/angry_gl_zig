#version 330

layout(location = 0) in vec3 Position;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform mat4 gWVP;

void main()
{
    gl_Position = gWVP * vec4(Position, 1.0);
    // gl_Position = projection * view * model * vec4(Position, 1.0);
}
