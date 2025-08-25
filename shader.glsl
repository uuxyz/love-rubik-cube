#pragma language glsl3

uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

#ifdef VERTEX

in vec4 InstanceTransform0;
in vec4 InstanceTransform1;
in vec4 InstanceTransform2;
in vec4 InstanceTransform3;
in vec3 CubePosition;

out vec4 vertexColor;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    mat4 InstanceTransform = mat4(
        InstanceTransform0,
        InstanceTransform1,
        InstanceTransform2,
        InstanceTransform3
    );

    vec4 instance_transformed_position = InstanceTransform * vertex_position;

    vec4 clip_space = projectionMatrix * viewMatrix * modelMatrix * instance_transformed_position;
    clip_space.y *= -1;

    vertexColor = vec4(((CubePosition + vertex_position.xyz + 1.5) / 3.0).xyz, 1);
    return clip_space;
}
#endif

#ifdef PIXEL
in vec4 vertexColor;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
    return vertexColor;
}
#endif
