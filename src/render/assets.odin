package render

import "core:mem"
import "core:fmt"

TEXTURE_PATHS := []cstring{
    "assets/brick.jpg",
    "assets/brick_norm.jpg",
    "assets/ground.png",
    "assets/ground_norm.png",
    "assets/katana/katana.png",
    "assets/katana/katana_norm.png",
}

MESH_PATHS := []cstring{
    "assets/cube.obj",
    "assets/katana/katana.obj",
}

Assets :: struct {
    textures: [dynamic]Texture,
    // For shaders Just a range of numbers [0..<len(textures)]
    texture_units: [dynamic]i32, 
    meshes: [dynamic]Mesh,
}

assets : Assets

assets_init :: proc() {
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
        }

        m := mesh_init(obj)
        append(&assets.meshes, m)
    }
}

assets_deinit :: proc() {
    delete(assets.textures)
    delete(assets.texture_units)

    for &mesh in assets.meshes {
        mesh_deinit(&mesh)
    }
    delete(assets.meshes)
}

assets_bind_textures :: proc() {

}