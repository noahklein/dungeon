package game

import glm "core:math/linalg/glsl"
import "../storage"

EPSILON :: 0.0001
C :: 100 // Speed of light

Physics :: struct {
    gravity: glm.vec3,
    rigidbodies: storage.Dense(Rigidbody),
}

physics := Physics{
    gravity = {0, -9.81, 0},
}

Rigidbody :: struct {
    mass: f32,
    velocity, force: glm.vec3,
}

physics_deinit :: proc() {
    storage.dense_deinit(physics.rigidbodies)
}

physics_add_rigidbody :: proc(ent_id: int, mass: f32) {
    ent := &entities[ent_id]
    ent.rigidbody_id = storage.dense_add(&physics.rigidbodies, Rigidbody{
        mass = mass,
    })
}

physics_update :: proc(dt: f32) {
    for &ent in entities {
        rigidbody_id, ok := ent.rigidbody_id.?
        if !ok {
            continue
        }

        rb := storage.dense_get(physics.rigidbodies, rigidbody_id)
        if rb == nil {
            continue // TODO: handle deletion?
        }
        rb.force += rb.mass * physics.gravity
        rb.velocity += rb.force / rb.mass * dt
        rb.velocity = glm.clamp_vec3(rb.velocity, {-C, -C, -C}, {C, C, C})

        ent.pos += rb.velocity * dt
        // @HACK: replace with plane collision
        if ent.pos.y < 1 {
            ent.pos.y = 1
        }

        rb.force = 0
    }
}

Plane :: struct {
    center, normal: glm.vec3,
}

raycast_plane :: proc(plane: Plane, origin, dir: glm.vec3) -> bool {
    denom := glm.dot(plane.normal, dir)
    if abs(denom) <= EPSILON {
        return false // We're perpendicular.
    }

    t := glm.dot(plane.center - origin, plane.normal) / denom
    return t > EPSILON
}

Box :: struct {
    min, max: glm.vec3,
}

// See https://tavianator.com/2011/ray_box.html.
raycast_box :: proc(box: Box, origin, dir: glm.vec3) -> (glm.vec3, bool) {
    min_dist := (box.min - origin) / dir
    max_dist := (box.max - origin) / dir

    // Normalize
    mins := glm.min(min_dist, max_dist)
    maxs := glm.max(min_dist, max_dist)

    smallest := min(mins.x, mins.y, mins.z)
    biggest  := max(maxs.x, maxs.y, maxs.z)

    is_hit := biggest >= 0 && biggest >= smallest
    hit_point := origin + (smallest * dir)
    return hit_point, is_hit
}