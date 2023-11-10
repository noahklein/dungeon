package game

import glm "core:math/linalg/glsl"
import "core:fmt"
import "../storage"

Animation :: struct {
    start_transform: Transform,
    keyframes: [dynamic]Transform,
    curr_keyframe: int,
    elapsed, duration: f32,
}


update_animations :: proc(dt: f32) {
    for &ent in entities {
        anim := &ent.animation
        if len(anim.keyframes) == 0 {
            continue
        }

        anim.elapsed += dt
        if anim.elapsed >= anim.duration {
            anim.elapsed = 0
            anim.curr_keyframe += 1
            anim.start_transform = ent.transform

            if anim.curr_keyframe >= len(anim.keyframes) {
                clear(&anim.keyframes)
                continue
            }
        }

        // Interpolate
        target := anim.keyframes[anim.curr_keyframe]
        ent.pos = glm.lerp(anim.start_transform.pos, target.pos, anim.elapsed / anim.duration)
    }
}

play_animation :: proc(entity_id: int, duration: f32) {
    ent := &entities[entity_id]
    anim := &ent.animation

    anim.curr_keyframe = 0
    anim.duration = duration
    anim.elapsed = 0
    anim.start_transform = ent.transform
}
