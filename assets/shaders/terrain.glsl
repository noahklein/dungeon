#type vertex
#version 450 core

layout (location = 0) in vec3 pos;

uniform mat4 projection;
uniform mat4 view;
// uniform sampler2D heightMap;


out vec3 vPos;

void main() {
    // vec4 y = texture(heightMap, coord);
    // vec3 pos = vec3(coord.x, y.x, coord.y);

    gl_Position = projection * view * vec4(pos, 1.0);
    vPos = pos;
}

#type fragment
#version 450 core

in vec3 vPos;

uniform vec4 color;

out vec4 FragColor;

void main() {
    // FragColor = color;
    FragColor = vec4(vPos.y, vPos.y, 1, 1);
}