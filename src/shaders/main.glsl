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
};

in vec3 vPos;
in vec2 vTexCoord;
in vec3 vNormal;
flat in ivec2 vTexture;

uniform PointLight pointLight;
uniform vec3 camPos;
uniform sampler2D textures[4];

layout (location = 0) out vec4 color;



vec4 lighting() {
    vec3 normal = texture(textures[vTexture.x + 1], vTexCoord * vTexture.y).rgb;
    normal = normalize(normal * 2 - 1);

    vec3 lightDir = normalize(pointLight.pos - vPos);
    float diffAmount = max(dot(normal, lightDir), 0);
    vec3 diffuse = pointLight.diffuse * diffAmount;

    vec3 viewDir = normalize(camPos - vPos);
    vec3 reflectDir = reflect(-lightDir, normal);
    float specAmount = pow(max(dot(viewDir, reflectDir), 0), 5);
    vec3 specular = pointLight.specular * specAmount;

    return vec4(pointLight.ambient + specular + diffuse, 1);

}

void main() {
    // color = texture(textures[vTexUnit], vTexCoord * tiling) * lighting();
    color = texture(textures[vTexture.x], vTexCoord * vTexture.y) * lighting();
    // color = vec4(vTexCoord, 1, 1) * lighting();
}