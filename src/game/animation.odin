package game

import glm "core:math/linalg/glsl"
import "core:math/ease"
import "core:fmt"
import "../storage"

Keyframe :: struct {
    transform: Transform,
    duration: f32,
    curve: ease.Ease,
}

Animation :: struct {
    start_transform: Transform,
    keyframes: [dynamic]Keyframe,
    curr_keyframe: int,
    elapsed: f32,
    on_complete: proc(),
}

animation_update :: proc(dt: f32) {
    for &ent in entities {
        anim := &ent.animation
        if len(anim.keyframes) == 0 {
            continue
        }

        // First frame initialization.
        if anim.elapsed == 0 {
            anim.start_transform = ent.transform
        }

        keyframe := anim.keyframes[anim.curr_keyframe]
        anim.elapsed += dt
        if anim.elapsed >= keyframe.duration {
            anim.elapsed -= keyframe.duration

            // Clamp entity to previous keyframe.
            anim.start_transform = anim.keyframes[anim.curr_keyframe].transform
            ent.transform = anim.start_transform

            // Next keyframe.
            anim.curr_keyframe += 1
            if anim.curr_keyframe >= len(anim.keyframes) {
                // Finished.
                clear(&anim.keyframes)
                if anim.on_complete != nil {
                    anim.on_complete()
                }

                continue
            }

            keyframe = anim.keyframes[anim.curr_keyframe]
        }

        // Interpolate
        target := anim.keyframes[anim.curr_keyframe].transform
        t := ease.ease(keyframe.curve, anim.elapsed / keyframe.duration)
        ent.pos = glm.lerp(anim.start_transform.pos, target.pos, t)
        ent.rot = glm.lerp(anim.start_transform.rot, target.rot, t)
        ent.scale = glm.lerp(anim.start_transform.scale, target.scale, t)
    }
}

animation_play :: proc(entity_id: int) {
    ent := &entities[entity_id]
    anim := &ent.animation

    anim.curr_keyframe = 0
    anim.elapsed = 0
}

animation_play_one_frame :: proc(entity_id: int, keyframe: Keyframe) {
    anim := &entities[entity_id].animation
    clear(&anim.keyframes)
    append(&anim.keyframes, keyframe)

    animation_play(entity_id)
}