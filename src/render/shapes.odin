package render

import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

Shapes :: struct {
    vao, vbo: u32,
    line: [2]LineVertex,
}

LineVertex :: struct {
    pos: glm.vec3,
}

shapes_init :: proc() -> (s: Shapes) {
    gl.CreateVertexArrays(1, &s.vao)
    gl.BindVertexArray(s.vao)

    gl.CreateBuffers(1, &s.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, s.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 2 * size_of(LineVertex), &s.line, gl.DYNAMIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0,  3, gl.FLOAT, false, size_of(LineVertex), offset_of(LineVertex, pos))

    return s
}

draw_line :: proc(s: ^Shapes, start, end: glm.vec3) {
    gl.BindVertexArray(s.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, s.vbo)

    line := [2]LineVertex{
        { start },
        { end },
    }
    s.line[0].pos = start
    s.line[1].pos = end
    gl.BufferSubData(gl.ARRAY_BUFFER, 0, 2 * size_of(LineVertex), &s.line[0])

    gl.DrawArrays(gl.LINES, 0, 2)
}


QuadRenderer :: struct {
    vao, vbo: u32,
    shader: Shader,
    quad: [6]QuadVertex
}

QuadVertex :: struct {
    pos, tex_coord: glm.vec2,
}


quad_renderer : QuadRenderer

quad_renderer_init :: proc(shader: Shader) {
    qr : QuadRenderer
    gl.CreateVertexArrays(1, &qr.vao)
    gl.BindVertexArray(qr.vao)
    defer gl.BindVertexArray(0)

    qr.shader = shader
    qr.quad = {
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1, -1}, tex_coord = {0, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},

        {pos = { 1,  1}, tex_coord = {1, 1}},
        {pos = { 1, -1}, tex_coord = {1, 0}},
        {pos = {-1,  1}, tex_coord = {0, 1}},
    }

    gl.CreateBuffers(1, &qr.vbo)
    gl.BindBuffer(gl.ARRAY_BUFFER, qr.vbo)
    gl.BufferData(gl.ARRAY_BUFFER, 6 * size_of(QuadVertex), &qr.quad, gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, pos))
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 2, gl.FLOAT, false, size_of(QuadVertex), offset_of(QuadVertex, tex_coord))

    quad_renderer = qr
}

draw_quad :: proc(tex: u32) {
    // gl.BindTextureUnit(0, tex)
    gl.BindTexture(gl.TEXTURE_2D, tex)
    gl.UseProgram(quad_renderer.shader.id)
    setInt(quad_renderer.shader.id, "tex", 0)

    gl.BindVertexArray(quad_renderer.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, quad_renderer.vbo)

    // gl.BufferSubData(gl.ARRAY_BUFFER, 0, 6 * size_of(QuadVertex), &quad_renderer.quad[0])

    gl.DrawArrays(gl.TRIANGLES, 0, 6)
}