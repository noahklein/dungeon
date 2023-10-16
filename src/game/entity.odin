package game

import glm "core:math/linalg/glsl"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:io"

import "vendor:glfw"

Entity :: struct {
    pos: glm.vec3,
    scale: glm.vec3,
    rot: glm.vec3, // euler angles
}

Chunk :: struct {
    grounds: [dynamic]Ground,
    walls: [dynamic]Wall,
    doors: [dynamic]Door,
    point_lights: [dynamic]PointLight,
    sword: Sword,
}

world := Chunk{
}

entity_model :: proc(e: Entity) -> glm.mat4 {
    quat := glm.quatFromEuler(e.rot)
    return  glm.mat4Translate(e.scale / 2) * glm.mat4Translate(e.pos) * glm.mat4FromQuat(quat) * glm.mat4Scale(e.scale)
}

Ground :: struct {
    using entity: Entity
}

Wall :: struct {
    using entity: Entity
}

Door :: struct {
    using entity: Entity
}

Sword :: struct {
    using entity: Entity,
    light: PointLight,
}

Thing :: union {
    ^PointLight,
    ^Ground, ^Wall, ^Door,
    ^Sword,
}

deinit_world :: proc() {
    delete(world.doors)
    delete(world.grounds)
    delete(world.walls)
    delete(world.point_lights)
}

world_save_to_file :: proc(path: string) {
    context.allocator = context.temp_allocator

    text, marshal_err := json.marshal(world)
    if marshal_err != nil {
        fmt.eprintln("failed to marshal JSON:", marshal_err)
        return
    }

    f, file_err := os.open(path, os.O_WRONLY)
    defer os.close(f)
    if file_err != os.ERROR_NONE {
        fmt.eprintln("failed to open file:", path, file_err)
        return
    }

    if !os.write_entire_file(path, text) {
        fmt.eprintln("Failed to write file:", path)
    }

    fmt.println("💾 Wrote world to", path)
}


// @Bug: memory leak!
world_load :: proc(path: string) {
    bytes, read_ok := os.read_entire_file(path, context.temp_allocator)
    if !read_ok {
        fmt.eprintln("Failed to load world: file read error")
        return
    }

    if err := json.unmarshal(bytes, &world); err != nil {
        fmt.eprintln("Failed to unmarshal world file:", err)
        return
    }

    fmt.println("📂 Loaded world from", path)
}

repeat :: proc(time, length: f32) -> f32{
    return clamp(time - glm.floor_f32(time / length) * length, 0, length)
}

pingpong :: proc(time, length: f32) -> f32 {
    t := repeat(time, length * 2)
    return length - glm.abs_f32(t - length)
}