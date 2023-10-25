package physics

import glm "core:math/linalg/glsl"

import "../game"

GRAVITY :: -9.81

RigidbodyId :: distinct u16

RigidBody :: struct {
    velocity, force: glm.vec3,
    mass: f32,
}

rigidbodies : [dynamic]RigidBody

update_rigidbodies :: proc(entities: []game.EntityList, dt: f32) {
    for &rb in rigidbodies {
        rb.force.y += rb.mass * GRAVITY
        rb.velocity += rb.force / rb.mass * dt
        
    }
}

ColliderId :: distinct u16

Sphere :: struct {
    center: glm.vec3,
    radius: f32,
}

BoxCollider :: struct {
    min, max: glm.vec3,
}

Capsule :: struct {
    radius: f32,
}

Collision :: struct {}

sphere_vs_sphere :: proc(sa, sb: Sphere) -> Collision {

    return {}
}