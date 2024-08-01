#version 330

layout(location = 0) in vec3 Position;

// the built-in gl_InstanceID provides the instance id

uniform mat4 projection_view;
uniform mat4 model_transform;

void main()
{
    gl_Position = projection_view * model_transform * vec4(Position, 1.0);
}
