package game

import glm "core:math/linalg/glsl"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:io"

import "vendor:glfw"

TransformId :: distinct u16

Transform :: struct {
    pos, scale, rot: glm.vec3,
    parent_id: Maybe(TransformId),
}

// TODO: rename to Entity
// TODO: lots of wasted bytes, sparse arrays would be more memory efficient.
Ent :: struct {
    using transform: Transform,
    texture: Texture,
    rigidbody: Maybe(Rigidbody),
    collider: Maybe(Collider),
}

EntityList :: [dynamic]Ent
entities : EntityList

lights : [dynamic]PointLight

Texture :: struct {
    unit, tiling: u32,
}


Chunk :: struct {
    sword: Sword,
}
world := Chunk{}

transform_model :: proc(e: Transform) -> glm.mat4 {
    quat := glm.quatFromEuler(e.rot)
    return  glm.mat4Translate(e.scale / 2) * glm.mat4Translate(e.pos) * glm.mat4FromQuat(quat) * glm.mat4Scale(e.scale)
}

Level :: struct {
    entities: EntityList,
    lights: [dynamic]PointLight,
}

Sword :: struct {
    using entity: Entity,
    light: PointLight,
}

Entity :: struct {
    pos: glm.vec3,
    scale: glm.vec3,
    rot: glm.vec3, // euler angles
}

Thing :: union {
    ^Sword,
}

deinit_world :: proc() {
    delete(lights)
    delete(entities)
}

world_save_to_file :: proc(path: string) {
    context.allocator = context.temp_allocator

    level := Level{entities = entities, lights = lights}

    text, marshal_err := json.marshal(level)
    if marshal_err != nil {
        fmt.eprintln("failed to marshal JSON:", marshal_err)
        return
    }

    if !os.write_entire_file(path, text) {
        fmt.eprintln("Failed to write file:", path)
    }

    fmt.println("💾 Wrote world to", path)
}

world_load :: proc(path: string) {
    bytes, read_ok := os.read_entire_file(path, context.temp_allocator)
    if !read_ok {
        fmt.eprintln("Failed to load world: file read error")
        return
    }

    level : Level
    if err := json.unmarshal(bytes, &level); err != nil {
        fmt.eprintln("Failed to unmarshal world file:", err)
        return
    }

    entities = level.entities
    lights = level.lights

    fmt.println("📂 Loaded world from", path)
}

repeat :: proc(time, length: f32) -> f32{
    return clamp(time - glm.floor_f32(time / length) * length, 0, length)
}

pingpong :: proc(time, length: f32) -> f32 {
    t := repeat(time, length * 2)
    return length - glm.abs_f32(t - length)
}