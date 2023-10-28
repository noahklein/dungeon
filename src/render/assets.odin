package render

import "core:mem"
import "core:fmt"

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
    // "assets/katana/katana.png",
    // "assets/katana/katana_norm.png",
}

MESH_PATHS := []cstring{
    "assets/cube.obj",
    // "assets/katana/katana.obj",
}

Assets :: struct {
    textures: [dynamic]Texture,
    // For shaders Just a range of numbers [0..<len(textures)]
    texture_units: [dynamic]i32, 
    meshes: [dynamic]Mesh,

    shaders: ShaderMap,
}

ShaderMap :: struct {
    main: Shader,
    line: Shader,
    quad: Shader,
}

// Order must match ShaderMap!
SHADER_PATHS :: [?]string{
    "assets/shaders/main.glsl",
    "assets/shaders/line.glsl",
    "assets/shaders/quad.glsl",
}

assets : Assets

assets_init :: proc() -> AssetLoadError {
    for path, i in TEXTURE_PATHS {
        fmt.println("Loading texture", path)
        tex := texture_load(u32(i), path)
        append(&assets.textures, tex)
        append(&assets.texture_units, i32(i))
    }

    for path, i in MESH_PATHS {
        obj, obj_err := load_obj(string(path))
        if obj_err != nil {
            fmt.eprintln("❌ Failed to load .obj file:", path, obj_err)
            return .MeshError
        }

        m := mesh_init(obj)
        append(&assets.meshes, m)
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

    return nil
}

assets_deinit :: proc() {
    delete(assets.textures)
    delete(assets.texture_units)

    for &mesh in assets.meshes {
        mesh_deinit(&mesh)
    }
    delete(assets.meshes)
}