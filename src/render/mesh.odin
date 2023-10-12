package render

import gl "vendor:OpenGL"
import "core:fmt"

// Mesh renderer
Mesh :: struct {
    vao, vbo, ibo: u32,
    verts: []Vertex,
    instances: [dynamic]Instance,
}

Vertex :: struct {
    pos: [3]f32,
    norm: [3]f32,
    uv: [2]f32,
}

Instance :: struct {
    texture: [2]u32,
    transform: matrix[4, 4]f32,
}

MAX_INSTANCES :: 30

mesh_init :: proc(obj: Obj) -> Mesh {
    m := Mesh{
        instances = make([dynamic]Instance, 0, MAX_INSTANCES),
        verts = make([]Vertex, len(obj.faces)),
    }
    for face, i in obj.faces {
        m.verts[i] = Vertex{
            pos = obj.vertices[face.vertex_index - 1],
            norm = obj.normals[face.normal_index - 1],
            uv = obj.tex_coords[face.tex_coord_index - 1],
        }
    }

    gl.CreateVertexArrays(1, &m.vao)
    gl.BindVertexArray(m.vao)

    // Vertex buffer, loaded into VRAM.
    gl.CreateBuffers(1, &m.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, len(m.verts) * size_of(Vertex), &m.verts[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, norm))
    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))

    // Instance buffer
    gl.CreateBuffers(1, &m.ibo)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.ibo)
    gl.BufferData(gl.ARRAY_BUFFER, MAX_INSTANCES * size_of(Instance), nil, gl.DYNAMIC_DRAW)
    gl.EnableVertexAttribArray(3)
    gl.VertexAttribIPointer(3, 2, gl.UNSIGNED_INT, size_of(Instance), offset_of(Instance, texture))
    gl.VertexAttribDivisor(3, 1)

    for i in 0..<4 {
        id := u32(4 + i)
        gl.EnableVertexAttribArray(id)
        offset := offset_of(Instance, transform) + (uintptr(i * 4) * size_of(f32))
        gl.VertexAttribPointer(id, 4, gl.FLOAT, false, size_of(Instance), offset)
        gl.VertexAttribDivisor(id, 1)
    }

    return m
}

mesh_deinit :: proc(m: ^Mesh) {
    gl.DeleteVertexArrays(1, &m.vao)
    gl.DeleteBuffers(1, &m.vbo)
    gl.DeleteBuffers(1, &m.ibo)
    delete(m.instances)
    delete(m.verts)
}

mesh_draw :: proc(m: ^Mesh, transform: matrix[4, 4]f32, tex_unit, tiling: u32) {
    if len(m.instances) + 1 >= MAX_INSTANCES {
        mesh_flush(m)
    }

    append(&m.instances, Instance{
        texture = [2]u32{tex_unit, tiling},
        transform = transform,
    })
}

mesh_flush :: proc(m: ^Mesh) {
    if len(m.instances) == 0 {
        return
    }

    gl.BindVertexArray(m.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, m.ibo)
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(len(m.instances) * size_of(Instance)), &m.instances[0])

    gl.DrawArraysInstanced(gl.TRIANGLES, 0, i32(len(m.verts)), i32(len(m.instances)))

    clear(&m.instances)
}