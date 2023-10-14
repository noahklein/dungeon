#type vertex
#version 450 core

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec2 texCoord;

layout (location = 3) in ivec2 texture; // {unit, tiling}
layout (location = 4) in mat4 transform;

uniform mat4 projection;
uniform mat4 view;

out vec2 vTexCoord;
out vec3 vNormal;
out vec3 vPos;
flat out ivec2 vTexture;

void main() {
    vPos = vec3(transform * vec4(pos, 1));
    gl_Position = projection * view * transform * vec4(pos, 1);
    vTexCoord = texCoord;
    vNormal = normal;
    vTexture = texture;
}

#type fragment
#version 450 core

struct PointLight {
    vec3 pos;
    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
    int radius;
};

in vec3 vPos;
in vec2 vTexCoord;
in vec3 vNormal;
flat in ivec2 vTexture;

#define LIGHTS 4
uniform PointLight pointLights[LIGHTS];
uniform vec3 camPos;
uniform sampler2D textures[6];

layout (location = 0) out vec4 color;

vec3 calcPointLight(PointLight light, vec3 normal, vec3 viewDir) {
    float attenuation = smoothstep(light.radius, 0, length(light.pos - vPos));

    vec3 lightDir = normalize(light.pos - vPos);
    float diffAmount = max(dot(normal, lightDir), 0);
    vec3 diffuse = light.diffuse * diffAmount * vec3(texture(textures[vTexture.x], vTexCoord * vTexture.y));
    diffuse *= attenuation;

    vec3 halfwayDir = normalize(lightDir + viewDir);
    // vec3 reflectDir = reflect(-lightDir, normal);
    // float specAmount = pow(max(dot(viewDir, reflectDir), 0), 5);
    float specAmount = pow(max(dot(normal, halfwayDir), 0), 5);
    vec3 specular = light.specular * specAmount;
    specular *= attenuation;

    return (light.ambient * attenuation) + specular + diffuse;

}

void main() {
    // Outline object.
    if (vTexture.x >= 100) {
        color = vec4(1, 1, 1, 0.2);
        return;
    }

    vec3 viewDir = normalize(camPos - vPos);
    vec3 normal = texture(textures[vTexture.x + 1], vTexCoord * vTexture.y).rgb;
    normal = normalize(normal * 2 - 1);

    vec3 result = vec3(0, 0, 0);
    for (int i = 0; i < LIGHTS; i++) {
        result += calcPointLight(pointLights[i], normal, viewDir);
    }
    color = vec4(result, 1);
}