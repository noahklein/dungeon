package render

import glm "core:math/linalg/glsl"
import "core:math/noise"
import "core:math"

import gl "vendor:OpenGL"

Terrain :: struct {
    vao, vbo: u32,
    size: i32,
    pos: glm.vec3,

    shader: Shader,

    vertices: [dynamic]glm.vec3,
    noise_map: [][]f32,
}


TERRAIN_SEED :: 100

terrain_init :: proc(size: i32, shader: Shader) -> Terrain {
    t := Terrain{
        size = size,
        shader = shader,
    }

    vertex :: #force_inline proc(x, y: f32) -> glm.vec3 {
        return {x, terrain_height({f64(x), f64(y), 0}), y}
    }

    for x in 0..<size {
        for y in 0..<size {
            x, y := f32(x), f32(y)
            append(&t.vertices,
                // Triangle 1
                vertex(x, y),
                vertex(x + 1, y),
                vertex(x, y + 1),

                // Triangle 2
                vertex(x + 1, y),
                vertex(x, y + 1),
                vertex(x + 1, y + 1),
            )
            // @TODO: index buffer would improve memory/performance
        }
    }

    gl.CreateVertexArrays(1, &t.vao)
    gl.BindVertexArray(t.vao)

    gl.CreateBuffers(1, &t.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, t.vbo)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(glm.vec3), 0)

    gl.NamedBufferData(t.vbo, len(t.vertices) * size_of(glm.vec3), &t.vertices[0], gl.STATIC_DRAW)

    return t
}

terrain_deinit :: proc(t: ^Terrain) {
    delete(t.vertices)
}

terrain_draw :: proc(t: ^Terrain, projection, view: [^]f32) {
    gl.BindVertexArray(t.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, t.vbo)

    gl.UseProgram(t.shader.id)
    setMat4(t.shader.id, "projection", projection)
    setMat4(t.shader.id, "view", view)

    // gl.NamedBufferData(t.vbo, len(t.vertices) * size_of(glm.vec3), &t.vertices[0], gl.STATIC_DRAW)
    // gl.BufferSubData(gl.ARRAY_BUFFER, 0, len(t.vertices) * size_of(glm.vec3), &t.vertices[0])
    gl.DrawArrays(gl.TRIANGLES, 0, i32(len(t.vertices)))
}

@(private="file")
terrain_height :: #force_inline proc(coord: noise.Vec3) -> f32 {
    // return noise.noise_2d(TERRAIN_SEED, {f64(x), f64(y)})

    e := noise.noise_3d_improve_xy(TERRAIN_SEED, coord) +
        0.5 * noise.noise_3d_improve_xy(TERRAIN_SEED, 2 * coord) +
        0.25 * noise.noise_3d_improve_xy(TERRAIN_SEED, 4 * coord)
    e /= (1 + 0.5 + 0.25)

    return math.pow(e, 1)
}


terrain_gen_noise :: proc(noise_map : [][]f32, width, height: i32, scale: f64) {
    assert(scale >= 0.0001)

    for y in 0..<height {
        for x in 0..<width {
            coord := noise.Vec2{f64(x), f64(y)} / scale
            sample := noise.noise_2d(TERRAIN_SEED, coord)
            noise_map[y][x] = sample
        }
    }

}