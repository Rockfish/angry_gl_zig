#version 330

layout(location = 0) in vec3 Position;

uniform mat4 projectionView;
uniform mat4 model_transform;

// uniform mat4 gWVP;

void main()
{
    // gl_Position = gWVP * vec4(Position, 1.0);
    gl_Position = projectionView * model_transform * vec4(Position, 1.0);
}
