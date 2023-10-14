package game

import glm "core:math/linalg/glsl"

PointLight :: struct {
	pos: glm.vec3,
	ambient, diffuse, specular: glm.vec3,
	radius: i32,
}
