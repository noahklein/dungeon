package game

import glm "core:math/linalg/glsl"

GRAVITY :: -9.81

Rigidbody :: struct {
    velocity, force: glm.vec3,
    mass: f32,
}

Collider :: union{
    // Capsule,
    Sphere,
}

Sphere :: struct {
    radius: f32,
}
Capsule :: struct {
    radius: f32,
}