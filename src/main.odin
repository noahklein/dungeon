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
import "storage"
import "physics"

SCREEN :: glm.vec2{1600, 1200}
ASPECT :: f32(SCREEN.x) / f32(SCREEN.y)
TITLE :: "Dungeon"

cursor_hidden := true
mouse_coords : glm.vec2

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

    window := glfw.CreateWindow(i32(SCREEN.x), i32(SCREEN.y), TITLE, nil, nil)
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
	if err := render.assets_init(); err != nil {
		return
	}
	defer render.assets_deinit()

    cube_obj, cube_obj_err := render.load_obj("assets/cube.obj")
    if cube_obj_err != nil {
        fmt.eprintln("Failed to load cube.obj:", cube_obj_err)
        return
    }
	cube_mesh := render.mesh_init(cube_obj)
	defer render.mesh_deinit(&cube_mesh)

	
	shape_renderer := render.shapes_init()

	render.quad_renderer_init(render.assets.shaders.quad)

	mouse_pick, mouse_pick_ok := render.mouse_picking_init(SCREEN)
	if !mouse_pick_ok {
		return
	}

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
	
		view := game.update(dt, input)

        glfw.PollEvents()

		// @Cleanup: move to centralized input handler.
		if !gui.want_capture_mouse() && glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
			hovered_id := render.mouse_picking_read(mouse_pick, mouse_coords)
			if hovered_id > 0 && hovered_id < 999999 {
				gui.state.entity_id = hovered_id - 1
			} else {
				gui.state.entity_id = -1
			}
		}

		// Draw scene to framebuffer
		gl.BindFramebuffer(gl.FRAMEBUFFER, mouse_pick.fbo)

        gl.ClearColor(0.1, 0.1, 0.1, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT) 
		gl.Enable(gl.DEPTH_TEST)

		// Draw cube
		main_shader := render.assets.shaders.main
		gl.UseProgram(main_shader.id)
		render.setMat4(main_shader.id, "projection", &projection[0, 0])
		render.setMat4(main_shader.id, "view", &view[0, 0])
		for light, i in game.lights {
			name := fmt.tprintf("pointLights[%d]", i)
			render.setStruct(main_shader.id, name, game.PointLight, light)
		}
		render.setFloat3(main_shader.id, "camPos", game.cam.pos);
		render.setIntArray(main_shader.id, "textures", i32(len(render.assets.texture_units)), &render.assets.texture_units[0])

		for tex in render.assets.textures {
			gl.BindTextureUnit(tex.unit, tex.id)
		}

		for entity, i in game.entities {
			ent_id := i32(i + 1)
			model := game.transform_model(entity.transform)
			render.mesh_draw(&cube_mesh, model, entity.texture.unit, entity.texture.tiling, ent_id)

			when ODIN_DEBUG {
				if gui.is_selected(.Entity, i) {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(&cube_mesh, m, 100, 1, ent_id)
				}
			}
		}

		// Draw light
		for light, i in game.lights {
			// Draw editor outline.
			when ODIN_DEBUG {
				model := glm.mat4Translate(light.pos) * glm.mat4Scale(glm.vec3(0.1))
				if gui.is_selected(.Light, i) {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(&cube_mesh, m, 100, 1, -1)
				}
			}
		}

		render.mesh_flush(&cube_mesh)

		{
			line_shader := render.assets.shaders.line
			// Draw lines
			gl.UseProgram(line_shader.id)
			render.setMat4(line_shader.id, "projection", &projection[0, 0])
			render.setMat4(line_shader.id, "view", &view[0, 0])
			render.setFloat4(line_shader.id, "color", [4]f32{1, 1, 1, 1})

			// Cone
			start := glm.vec3{0, 3, 0}
			for i in 0..=10 {
				end := glm.vec3{glm.sin(f32(i)), 0, glm.cos(f32(i))}
				render.draw_line(&shape_renderer, start, end)
			}
		}

		{
			// Draw to screen
			gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
			gl.ClearColor(1.0, 1.0, 1.0, 1.0); 
			gl.Clear(gl.COLOR_BUFFER_BIT);
			gl.Disable(gl.DEPTH_TEST)
			render.draw_quad(mouse_pick.tex)
		}

		// {
		// 	// Draw sword.
		// 	camera_transform := glm.inverse(view)
		// 	using game.world.sword
		// 	transform := game.Transform{pos = pos, rot = rot, scale = scale}
		// 	model := camera_transform * game.transform_model(transform)
		// 	render.mesh_draw(&katana_mesh, model, 6, 1)
		// 	render.mesh_flush(&katana_mesh)
		// }



		when ODIN_DEBUG {
			gui.draw()
			render.watch(&main_shader)
			render.watch(&render.assets.shaders.quad)
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
		return
	}

	mouse_coords.x = f32(xpos)
	mouse_coords.y = SCREEN.y - f32(ypos)
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

