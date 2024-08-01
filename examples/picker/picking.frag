
#version 330

uniform uint object_id;
uniform uint mesh_id;

// the built-in gl_InstanceID provides the instance id

out vec3 frag_color;

void main()
{
    frag_color = vec3(float(object_id), float(mesh_id), float(gl_PrimitiveID + 1));
}
