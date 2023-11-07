#type vertex
#version 450 core

layout (location = 0) in vec3 pos;

uniform mat4 projection;
uniform mat4 view;

void main() {
    gl_Position = projection * view * vec4(pos, 1.0);
}

#type fragment
#version 450 core

uniform vec4 color;

out vec4 FragColor;

void main() {
    FragColor = color;
}