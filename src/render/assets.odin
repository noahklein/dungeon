package render

import "core:mem"
import "core:fmt"
import gl "vendor:OpenGL"

AssetLoadError :: enum{
    None,
    MeshError,
    ShaderError,
}

TEXTURE_PATHS := []cstring{
    "assets/brick.jpg",
    "assets/brick_norm.jpg",
    "assets/ground.png",
    "assets/ground_norm.png",
}

MESH_PATHS := [MeshId]cstring{
    .Cube = "assets/cube.obj",
    .Quad = "assets/quad.obj",
    .Ninja = "assets/ninja.obj",
    .Sphere = "assets/sphere.obj",
}

MeshId :: enum u8 {
    Cube,
    Quad,
    Ninja,
    Sphere,
}

mesh :: #force_inline proc(id: MeshId) -> ^Mesh {
    return &assets.meshes[id]
}

Assets :: struct {
    textures: [dynamic]Texture,
    // For shaders Just a range of numbers [0..<len(textures)]
    texture_units: [dynamic]i32,
    meshes: [MeshId]Mesh,

    shaders: ShaderMap,
}

ShaderMap :: struct {
    main: Shader,
    line: Shader,
    quad: Shader,
    terrain: Shader,
}

// Order must match ShaderMap!
SHADER_PATHS :: [?]string{
    "assets/shaders/main.glsl",
    "assets/shaders/line.glsl",
    "assets/shaders/quad.glsl",
    "assets/shaders/terrain.glsl",
}

assets : Assets

assets_init :: proc() -> AssetLoadError {
    for path, i in TEXTURE_PATHS {
        fmt.println("Loading texture", path)
        tex := texture_load(u32(i), path)
        append(&assets.textures, tex)
        append(&assets.texture_units, i32(i))
    }

    {
        // Border texture
        SIZE :: 100
        COLOR :: 0xFFFFFFFF

        id := len(TEXTURE_PATHS)
        border_tex := texture_init(u32(id), TextureOptions{
            format = .RGBA, width = SIZE, height = SIZE,
            mag_filter = .LINEAR, min_filter = .NEAREST,
            wrap_s = .REPEAT, wrap_t = .REPEAT,
        })

        border_tex_data := [SIZE * SIZE]u32{}
        for _, i in border_tex_data {
            row, col := i / SIZE, i % SIZE
            if row == 0 || row == SIZE - 1 || col == 0 || col == SIZE - 1 {
                border_tex_data[i] = COLOR
            }
        }

        gl.TextureSubImage2D(border_tex.id, 0, 0, 0, SIZE, SIZE, gl.RGBA, gl.UNSIGNED_INT_8_8_8_8, &border_tex_data[0])

        append(&assets.textures, border_tex)
        append(&assets.texture_units, i32(id))
    }

    for path, i in MESH_PATHS {
        obj, obj_err := load_obj(string(path))
        if obj_err != nil {
            fmt.eprintln("❌ Failed to load .obj file:", path, obj_err)
            return .MeshError
        }

        m := mesh_init(obj)
        assets.meshes[i] = m
    }

    shaders : [len(SHADER_PATHS)]Shader
    for path, i in SHADER_PATHS {
        shader, shader_err := shader_load(path)
        if shader_err != nil {
            fmt.eprintf("Failed to load %q: %v\n", path, shader_err)
            return .ShaderError
        }
        shaders[i] = shader
    }

    assets.shaders.main = shaders[0]
    assets.shaders.line = shaders[1]
    assets.shaders.quad = shaders[2]
    assets.shaders.terrain = shaders[3]

    return nil
}

assets_deinit :: proc() {
    delete(assets.textures)
    delete(assets.texture_units)

    for &mesh in assets.meshes {
        mesh_deinit(&mesh)
    }
}