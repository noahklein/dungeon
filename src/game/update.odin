package game

import glm "core:math/linalg/glsl"

MAX_SWORD_RADIUS :: 15

Event :: enum {
    Forward, Backward, Left, Right,
    FlyUp, FlyDown,
}

update :: proc(dt: f32, input: bit_set[Event]) -> (view: glm.mat4) {
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

    return look_at(cam)
}