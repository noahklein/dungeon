package game

import glm "core:math/linalg/glsl"

PointLight :: struct {
	pos: glm.vec3,
	color: glm.vec3,
	ambient, diffuse, specular: f32,
	radius: f32,
}
