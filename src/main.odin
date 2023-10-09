package main

import "core:fmt"
import "core:mem"

import "vendor:glfw"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import "render"
import "debug"


SCREEN :: [2]i32{1200, 800}
ASPECT :: f32(SCREEN.x) / f32(SCREEN.y)
TITLE :: "Dungeon"

main :: proc() {
	when ODIN_DEBUG {
		// Report memory leaks
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	// Initialize glfw and window
    if glfw.Init() == 0 {
        fmt.eprintln("GLFW init failed")
    }
    defer glfw.Terminate()

    window := glfw.CreateWindow(SCREEN.x, SCREEN.y, TITLE, nil, nil)
	if window == nil {
		fmt.eprint("GLFW failed to create window")
		return
	}
	defer glfw.DestroyWindow(window)
	glfw.MakeContextCurrent(window)

	// Initialize OpenGL
	GL_MAJOR_VERSION :: 4
	GL_MINOR_VERSION :: 5
	gl.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, glfw.gl_set_proc_address)

	gl.Enable(gl.DEBUG_OUTPUT)
	gl.DebugMessageCallback(debug.on_debug_msg, nil)

	gl.Enable(gl.BLEND)
	// gl.BlendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ONE, gl.ZERO)

    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)

    // Assets
    cube_obj, cube_obj_err := render.load_obj("assets/cube.obj")
    if cube_obj_err != nil {
        fmt.eprintln("Failed to load cube.obj:", cube_obj_err)
        return
    }
	cube_mesh := render.mesh_init(cube_obj)
	defer render.mesh_deinit(&cube_mesh)

	shader, shader_err := render.shader_load("src/shaders/main.glsl")
	if shader_err != nil {
		fmt.eprintln("Failed to load shaders/main.glsl:", shader_err)
		return
	}

    frames := i64(0)
	prev_frame_time := 0.0

	projection := glm.mat4Perspective(glm.radians(f32(70.0)), ASPECT, 0.1, 100)
	camera := glm.vec3{0, 0, -9}
	// Game loop
	for !glfw.WindowShouldClose(window) {
		// Calculate FPS
		frames += 1
		if now := glfw.GetTime(); now - prev_frame_time >= 1 {
			fmt.println(1000/f32(frames), "ms/frame", frames, "FPS")
			frames = 0
			prev_frame_time = now
        }

		cam_speed := f32(0.01)
		if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
			camera.x -= cam_speed
		} else if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
			camera.x += cam_speed
		} else if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
			camera.y -= cam_speed
		} else if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
			camera.y += cam_speed
		}

		view := glm.mat4LookAt(camera, camera + {0, 0, 1}, {0, 1, 0})

        glfw.PollEvents()

        gl.ClearColor(0.1, 0.1, 0.1, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// Draw cube
		gl.UseProgram(shader.id)
		render.setMat4(shader.id, "projection", &projection[0, 0])
		render.setMat4(shader.id, "view", &view[0, 0])

		// model := glm.mat4Rotate({1, 0, 0}, glm.radians(f32(-55.0)))
		model := glm.mat4(1)
		model *= glm.mat4Translate(2 * {glm.sin_f32(f32(glfw.GetTime())), glm.cos_f32(f32(glfw.GetTime())), 0})
		model *= glm.mat4Rotate({0.5, 1, 0}, f32(glfw.GetTime()) * glm.radians_f32(50))

		render.mesh_draw(&cube_mesh,  model, 0)
		render.mesh_flush(&cube_mesh)

		render.watch(&shader)
        glfw.SwapBuffers(window)
        free_all(context.temp_allocator)
    }
}

print_mat :: proc(m: glm.mat4) {
	fmt.println(m[0])
	fmt.println(m[1])
	fmt.println(m[2])
	fmt.println(m[3])
}