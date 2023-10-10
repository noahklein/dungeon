package render

import glm "core:math/linalg/glsl"
import "core:fmt"

CAM_SPEED :: 1.0

init_mouse : bool

Camera :: struct {
    fov, aspect, near, far: f32,
    pos, target, forward, right: glm.vec3,

    pitch, yaw: f32, // horizontal, vertical
    sensitivity, mouse_pos: glm.vec2,
    speed: f32,
}

projection :: proc(c: Camera) -> glm.mat4 {
    return glm.mat4Perspective(c.fov, c.aspect, c.near, c.far)
}

look_at :: proc(c: Camera) -> glm.mat4 {
    up := glm.normalize(glm.cross(c.right, c.forward))
    return glm.mat4LookAt(c.pos, c.pos + c.forward, up)
}

on_mouse_move :: proc(c: ^Camera, mouse: glm.vec2) {
    if !init_mouse {
        c.mouse_pos = mouse
        init_mouse = true
    }

    diff := c.sensitivity * glm.vec2{
        mouse.x - c.mouse_pos.x,
        c.mouse_pos.y - mouse.y,
    }
    c.mouse_pos = mouse

    c.yaw += diff.x
    c.pitch = clamp(c.pitch + diff.y, -89, 89)

    yaw, pitch := glm.radians(c.yaw), glm.radians(c.pitch)
    c.forward = glm.normalize_vec3({
        glm.cos(yaw) * glm.cos(pitch),
        glm.sin(pitch),
        glm.sin(yaw) * glm.cos(pitch),
    })
    c.right = glm.normalize(glm.cross(c.forward, glm.vec3{0, 1, 0}))
}