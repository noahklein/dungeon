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
out vec3 vPos;

void main() {
    vPos = vec3(transform * vec4(pos, 1));
    gl_Position = projection * view * transform * vec4(pos, 1);
    vTexCoord = texCoord;
    vNormal = normal;
}

#type fragment
#version 450 core

struct PointLight {
    vec3 pos;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

in vec3 vPos;
in vec2 vTexCoord;
in vec3 vNormal;

uniform PointLight pointLight;
uniform vec3 camPos;

layout (location = 0) out vec4 color;


vec4 lighting() {
    vec3 lightDir = normalize(pointLight.pos - vPos);
    float diffAmount = max(dot(vNormal, lightDir), 0);
    vec3 diffuse = pointLight.diffuse * diffAmount;

    vec3 viewDir = normalize(camPos - vPos);
    vec3 reflectDir = reflect(-lightDir, vNormal);
    float specAmount = pow(max(dot(viewDir, reflectDir), 0), 5);
    vec3 specular = pointLight.specular * specAmount;

    return vec4(pointLight.ambient + specular + diffuse, 1);

}

void main() {
    color = vec4(vTexCoord, 1, 1) * lighting();
}