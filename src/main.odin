package main

import "core:fmt"
import "core:mem"
import "core:runtime"

import "vendor:glfw"
import gl "vendor:OpenGL"
import glm "core:math/linalg/glsl"

import "render"
import "debug"
import "gui"
import "game"


SCREEN :: [2]i32{1600, 1200}
ASPECT :: f32(SCREEN.x) / f32(SCREEN.y)
TITLE :: "Dungeon"

cursor_hidden := true

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
	defer free_all(context.temp_allocator)
	defer game.deinit_world()

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
	gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, false)
	gl.DebugMessageControl(gl.DEBUG_SOURCE_API, gl.DEBUG_TYPE_ERROR, gl.DONT_CARE, 0, nil, true)
	gl.DebugMessageCallback(debug.on_debug_msg, nil)

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.DEPTH_TEST)
    gl.DepthFunc(gl.LESS)

	// glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
	glfw.SetKeyCallback(window, key_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)

	// Initialize ImGUI; MUST come after input handlers.
	gui.init(window)
	defer gui.shutdown()

    // Assets
    cube_obj, cube_obj_err := render.load_obj("assets/cube.obj")
    if cube_obj_err != nil {
        fmt.eprintln("Failed to load cube.obj:", cube_obj_err)
        return
    }
	cube_mesh := render.mesh_init(cube_obj)
	defer render.mesh_deinit(&cube_mesh)

    katana_obj, katana_obj_err := render.load_obj("assets/katana/katana.obj")
    if katana_obj_err != nil {
        fmt.eprintln("Failed to load katana.obj:", katana_obj_err)
        return
    }
	katana_mesh := render.mesh_init(katana_obj)
	defer render.mesh_deinit(&katana_mesh)

	shader, shader_err := render.shader_load("src/shaders/main.glsl")
	if shader_err != nil {
		fmt.eprintln("Failed to load shaders/main.glsl:", shader_err)
		return
	}

	brick_tex := render.texture_load(0, "assets/brick.jpg")
	brick_norm_tex := render.texture_load(1, "assets/brick_norm.jpg")
	ground_tex := render.texture_load(2, "assets/ground.png")
	ground_norm_tex := render.texture_load(3, "assets/ground_norm.png")
	door_tex := render.texture_load(4, "assets/door.png")
	door_norm_tex := render.texture_load(5, "assets/door_norm.png")
	katana_tex := render.texture_load(6, "assets/katana/katana.png")
	katana_norm_tex := render.texture_load(7, "assets/katana/katana_norm.png")
	textures := [?]i32{0, 1, 2, 3, 4, 5, 6, 7}

	game.world_load("config.json")
	game.init_camera(ASPECT)

	projection := game.projection(game.cam)

    frames : i64
	prev_second : f32
	prev_frame_time : f32

	// Game loop
	for !glfw.WindowShouldClose(window) {
		// Calculate FPS
		frames += 1
		now := f32(glfw.GetTime())
		if now - prev_second >= 1 {
			fmt.println(1000/f32(frames), "ms/frame", frames, "FPS")
			frames = 0
			prev_second = now
        }

		dt := (now - prev_frame_time) / 1000
		prev_frame_time = now

		input : bit_set[game.Event]
		if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
			input += {.Left}
		} else if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
			input += {.Right}
		}
		if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
			input += {.Forward}
		} else if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
			input += {.Backward}
		}
		if glfw.GetKey(window, glfw.KEY_Q) == glfw.PRESS {
			input += {.FlyUp}
		}
		if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS {
			input += {.FlyDown}
		}
	
		if glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
			input += {.Absorb_Light}

		}
		view := game.update(dt, input)

		// view := game.look_at(game.cam)

        glfw.PollEvents()

        gl.ClearColor(0, 0, 0, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT) 

		// Draw cube
		gl.UseProgram(shader.id)
		render.setMat4(shader.id, "projection", &projection[0, 0])
		render.setMat4(shader.id, "view", &view[0, 0])
		for light, i in game.world.point_lights {
			name := fmt.tprintf("pointLights[%d]", i)
			render.setStruct(shader.id, name, game.PointLight, light)
		}
		render.setFloat3(shader.id, "camPos", game.cam.pos);
		render.setIntArray(shader.id, "textures", len(textures), &textures[0])

		gl.BindTextureUnit(brick_tex.unit, brick_tex.id)
		gl.BindTextureUnit(brick_norm_tex.unit, brick_norm_tex.id)
		gl.BindTextureUnit(ground_tex.unit, ground_tex.id)
		gl.BindTextureUnit(ground_norm_tex.unit, ground_norm_tex.id)
		gl.BindTextureUnit(katana_tex.unit, katana_tex.id)
		gl.BindTextureUnit(katana_norm_tex.unit, katana_norm_tex.id)

		for wall, i in game.world.walls {
			model := game.entity_model(wall)
			render.mesh_draw(&cube_mesh, model, brick_tex.unit, 20)

			// Draw editor outline.
			when ODIN_DEBUG {
				if gui.state.entity == &game.world.walls[i] {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(&cube_mesh, m, 100, 1)
				}
			}
		}
		for ground, i in game.world.grounds {
			model := game.entity_model(ground)
			render.mesh_draw(&cube_mesh, model, ground_tex.unit, 25)

			// Draw editor outline.
			when ODIN_DEBUG {
				if gui.state.entity == &game.world.grounds[i] {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(&cube_mesh, m, 100, 1)
				}
			}
		}

		// Draw light
		for light, i in game.world.point_lights {
			// game.world.point_lights[i].radius = i32(glm.sin(prev_frame_time) * 10 + 10)
			model := glm.mat4Translate(light.pos) * glm.mat4Scale(glm.vec3(0.1))
			render.mesh_draw(&cube_mesh, model, brick_tex.unit, 1)

			// Draw editor outline.
			when ODIN_DEBUG {
				if gui.state.entity == &game.world.point_lights[i] {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(&cube_mesh, m, 100, 1)
				}
			}
		}

		render.mesh_flush(&cube_mesh)

		{
			// Draw sword.
			camera_transform := glm.inverse(view)
			// model := glm.mat4Translate(cam.forward) * glm.mat4Translate(cam.pos)
			// model = game.entity_model(game.world.sword) * model
			model := camera_transform * game.entity_model(game.world.sword)
			render.mesh_draw(&katana_mesh, model, katana_tex.unit, 1)
			render.mesh_flush(&katana_mesh)
		}

		when ODIN_DEBUG {
			gui.render()
			render.watch(&shader)
			if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
				break
			}
		}
        glfw.SwapBuffers(window)
        free_all(context.temp_allocator)
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()
	if cursor_hidden {
		game.on_mouse_move(&game.cam, {f32(xpos), f32(ypos)})
	}
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()

	if button == glfw.MOUSE_BUTTON_RIGHT && action == glfw.PRESS {
		cursor_hidden = !cursor_hidden
		game.init_mouse = false

		if cursor_hidden {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		} else {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		}
	}
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	if key == glfw.KEY_S && mods == glfw.MOD_CONTROL && action == glfw.PRESS {
		game.world_save_to_file("config.json")
	}
}

print_mat :: proc(m: glm.mat4) {
	fmt.println(m[0])
	fmt.println(m[1])
	fmt.println(m[2])
	fmt.println(m[3])
}