package game

import glm "core:math/linalg/glsl"

Entity :: struct {
    pos, scale: glm.vec3,
    rot: glm.quat,
}

entity_model :: proc(e: Entity) -> glm.mat4 {
    return  glm.mat4Translate(e.scale / 2) * glm.mat4Translate(e.pos) * glm.mat4Scale(e.scale)
}

Ground :: struct {
    using Entity
}

Wall :: struct {
    using Entity
}

Chunk :: struct {
    grounds: []Ground,
    walls: []Wall,
}

world := Chunk{
    grounds = []Ground{
        { pos = {0, -1, 0}, scale = {10, 0, 10} },
    },
    walls = {
        { pos = {0, 1, 0}, scale = {10, 4, 1} },
        { pos = {10, 1, 0}, scale = {1, 4, 10} },
        // { pos = {0, 3, 50}, scale = {50, 4, 1} },
        // { pos = {50, 3, 0}, scale = {1, 4, 50} },
    }
}