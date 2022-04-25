#version 330

uniform mat4 p3d_ModelViewProjectionMatrix;
uniform mat4 p3d_ModelMatrix;
uniform mat4 p3d_ViewMatrixInverse;
uniform mat4 p3d_ModelViewMatrix;

uniform struct {
    vec4 position;
    vec3 color;
    vec3 attenuation;
    vec3 spotDirection;
    float spotCosCutoff;
    float spotExponent;
    sampler2DShadow shadowMap;
    mat4 shadowViewMatrix;
} p3d_LightSource[1];

in vec4 p3d_Vertex;
in vec3 p3d_Normal;
in vec2 p3d_MultiTexCoord0;

out vec3 normal;
out vec2 uv;
out vec3 fragPos;
out vec3 camPos;
out vec4 shad;

void main() {
    gl_Position = p3d_ModelViewProjectionMatrix * p3d_Vertex;

    normal = p3d_Normal;
    uv = p3d_MultiTexCoord0;
    fragPos = vec3(p3d_ModelMatrix * p3d_Vertex);
    shad = p3d_LightSource[0].shadowViewMatrix * p3d_ModelViewMatrix * p3d_Vertex;

    camPos = p3d_ViewMatrixInverse[3].xyz;
}