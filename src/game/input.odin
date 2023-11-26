package game

import glm "core:math/linalg/glsl"
import "core:math/rand"

Event :: enum {
    Forward, Backward, Left, Right,
    FlyUp, FlyDown,
    Fire,
}

input_update :: proc(dt: f32, input: bit_set[Event]) -> (view: glm.mat4) {
    if .Forward in input {
        cam.pos += cam.forward * cam.speed * dt
    } else if .Backward in input {
        cam.pos -= cam.forward * cam.speed * dt
    }
    if .Left in input {
        cam.pos -= cam.right * cam.speed * dt
    } else if .Right in input {
        cam.pos += cam.right * cam.speed * dt
    }

    if .FlyUp in input {
        cam.pos += glm.vec3{0, 1, 0} * cam.speed * dt
    } else if .FlyDown in input {
        cam.pos -= glm.vec3{0, 1, 0} * cam.speed * dt
    }

    if .Fire in input {
        // fire_ball()
    }

    return look_at(cam)
}

fire_ball :: proc() -> EntityId {
    append(&entities, Ent{
        pos = {
            rand.float32() * 10 - 5,
            rand.float32() * 10 + 3,
            rand.float32() * 10 - 5,
        },
        scale = glm.vec3(1),
        texture = {tiling = 3},
        mesh_id = .Sphere,
    })
    ball_id := len(entities) - 1
    physics_add_rigidbody(ball_id, mass = 10)
    rb := physics_get_rigidbody(ball_id) or_else panic("missing rigidbody after adding rigidbody")
    rb.force = {rand.float32(), 15, rand.float32()}

    append(&physics.spheres, SphereCollider{radius = 1, ent_id = ball_id})

    return ball_id
}