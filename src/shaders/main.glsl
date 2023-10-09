#type vertex
#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoord;

// layout (location = 3) in uint texUnit;
layout (location = 3) in mat4 transform;

uniform mat4 projection;
uniform mat4 view;

out vec2 vTexCoord;
out vec3 vNormal;

void main() {
    gl_Position = projection * view * transform * vec4(pos, 1);
    vTexCoord = texCoord;
    vNormal = normal;
}

#type fragment
#version 450 core

in vec2 vTexCoord;
in vec3 vNormal;

layout (location = 0) out vec4 color;

void main() {
    color = vec4(vTexCoord, 1, 1);
}