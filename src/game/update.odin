package game

import glm "core:math/linalg/glsl"

ABSORB_SPEED :: 5000
MAX_SWORD_RADIUS :: 15

Event :: enum {
    Forward, Backward, Left, Right,
    FlyUp, FlyDown,
    Absorb_Light,
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

    if .Absorb_Light in input {
        // Find nearest light and start sucking.
        nearest: ^PointLight
        min_dist := f32(999999999999999)
        for light, i in world.point_lights {
            dist := glm.distance(light.pos, cam.pos)
            if dist < min_dist {
                min_dist = dist                                                
                nearest = &world.point_lights[i]
            }
        }

        if nearest.radius > 0 && world.sword.light.radius < MAX_SWORD_RADIUS {
            nearest.radius -= ABSORB_SPEED * dt
            world.sword.light.radius += ABSORB_SPEED * dt
        }
    }

    return look_at(cam)
}