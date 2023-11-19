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

SCREEN := glm.vec2{1600, 1200}
TITLE :: "Dungeon"

RED :: [4]f32{1, 0.3, 0.3, 1}
BLUE :: [4]f32{0.3, 0.3, 1, 1}

cursor_hidden : bool
mouse_coords : glm.vec2
mouse_pick : render.MousePicking // Mouse-picking framebuffer

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
    if !glfw.Init() {
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

	gl.Enable(gl.LINE_SMOOTH)
	gl.LineWidth(3)

	// glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
	glfw.SetKeyCallback(window, key_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetFramebufferSizeCallback(window, resize_callback)

	// Initialize ImGUI; MUST come after input handlers.
	when ODIN_DEBUG {
		gui.init(window)
		defer gui.shutdown()
	}

    // Assets
	if err := render.assets_init(); err != nil {
		return
	}
	defer render.assets_deinit()

	shape_renderer := render.shapes_init()
	render.quad_renderer_init(render.assets.shaders.quad)

	mouse_pick = render.mouse_picking_init(SCREEN) or_else
		panic("Failed to init mouse_picking FBO")

	game.init_fight()
	defer game.deinit_fight()

	// game.world_load("config.json")
	game.init_camera(aspect = SCREEN.x / SCREEN.y)
	game.start_turn(0)

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
			frames = 0
			prev_second = now
        }

		dt := now - prev_frame_time
		prev_frame_time = now

        glfw.PollEvents()

		input := get_input(window)
		view := game.update(dt, input)
		game.animation_update(dt)

		hovered_id := game.TileId(render.mouse_picking_read(mouse_pick, mouse_coords))
		if hovered_id < 0 || hovered_id > 99999 { // @Hack: should clamp to valid IDs.
			hovered_id = -1
		}

		click_tile: if glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_LEFT) == glfw.PRESS {
			when ODIN_DEBUG {
				if gui.want_capture_mouse() {
					break click_tile
				}
				if gui.state.editor_mode {
					// @TODO: select in tile editor

					break click_tile
				}
			}

			game.on_click_tile(hovered_id)
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

		cube_mesh := render.mesh(.Cube)

		for tile, i in game.fight.level {
			i := i32(i)

			pos := game.fight_tile_pos(game.TileId(i))
			scale := glm.vec3(1)

			model := game.transform_model({ pos = pos, scale = scale})

			switch tile.type {
				case .Void:
					continue
				case .Ground:
					render.mesh_draw(cube_mesh, render.Instance{
						transform = model,
						texture = {2, 10},
						entity_id = i,
					})
				case .Wall:
					render.mesh_draw(cube_mesh, render.Instance{
						transform = model,
						texture = {0, 1},
						entity_id = i,
					})
			}
		}

		for entity, i in game.entities {
			ent_id := i32(i + 1)
			model := game.transform_model(entity.transform)
			mesh := render.mesh(entity.mesh_id)
			render.mesh_draw(mesh, render.Instance{
				entity_id = ent_id,
				texture = {entity.texture.unit, entity.texture.tiling},
				transform = model,
			})

			when ODIN_DEBUG {
				if gui.is_selected(.Entity, i) {
					m := model * glm.mat4Scale({1.1, 1.1, 1.1})
					render.mesh_draw(mesh, render.Instance{
						entity_id = ent_id,
						texture = {100, 1}, // @Hack: shader checks for 100 to draw the editor outline.
						transform = m,
					})
				}
			}
		}

		// Draw light
		for light, i in game.lights {
			when ODIN_DEBUG {
				model := glm.mat4Translate(light.pos) * glm.mat4Scale(glm.vec3(0.1))
				// Draw editor outline.
				if gui.is_selected(.Light, i) {
					m := model * glm.mat4Scale({1.01, 1.01, 1.01})
					render.mesh_draw(cube_mesh, render.Instance{
						transform = m,
						texture = {100, 1},
						entity_id = -1,
					})
				}
			}
		}

		render.mesh_flush(cube_mesh)

		{
			// Draw quads
			quad := render.mesh(.Quad)
			scale := glm.vec3{1, 1, 1}

			// Draw cursor border over hovered tile
			if hovered_id >= 0 {
				pos := game.fight_tile_pos(hovered_id)
				pos.y += 1.01
				render.mesh_draw(quad, render.Instance{
					transform = game.transform_model({ pos = pos, scale = scale}),
					texture = {4, 1},
					entity_id = i32(hovered_id),
				})
			}

			// Draw pathfinding results
			for id in game.path_finding.legal_moves {
				pos := game.fight_tile_pos(id)
				pos.y += 1.02

				color := game.get_player(id).team == .Enemy ? RED : BLUE
				color.a = 0.5 // Transparent

				render.mesh_draw(quad, render.Instance{
					transform = game.transform_model({pos = pos, scale = scale}),
					color = color,
					entity_id = i32(id),
				})
			}

			render.mesh_flush(quad)
		}

		// Flush all mesh render buffers
		for mesh_id in render.MeshId {
			render.mesh_flush(render.mesh(mesh_id))
		}

		{
			// Draw lines
			line_shader := render.assets.shaders.line
			gl.UseProgram(line_shader.id)
			render.setMat4(line_shader.id, "projection", &projection[0, 0])
			render.setMat4(line_shader.id, "view", &view[0, 0])
			color := [4]f32{(glm.sin(now) + 1) / 2, (glm.cos(now) + 1) / 2, 1, 1}
			render.setFloat4(line_shader.id, "color", color)

			// Draw cone at origin to help orientate in cyberspace.
			start := glm.vec3{0, 3, 0}
			n := 3
			step := 2 * glm.PI / f32(n)
			for i in 0..=n {
				end := glm.vec3{glm.sin(f32(i) * step), -1, glm.cos(f32(i) * step)}
				render.draw_line(&shape_renderer, start, end)
			}


			if len(game.path_finding.came_from) > 0 && hovered_id in game.path_finding.legal_moves {
				// Draw path from active player to hovered tile.
				current := hovered_id
				start := game.fight.players[game.fight.active_player].tile_id
				for current != start {
					next, ok := game.path_finding.came_from[current]
					if !ok {
						fmt.eprintln("😭 path-finding bug, current not in path_finding.came_from:", current)
						break
					}

					a := game.fight_tile_pos(current)
					a.y += 2
					b := game.fight_tile_pos(next)
					b.y += 2

					render.draw_line(&shape_renderer, a, b)
					current = next
				}
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

		when ODIN_DEBUG {
			gui.draw()
			render.watch(&render.assets.shaders.main)
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

		when ODIN_DEBUG {
			gui.unfocus()
		}
	}
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	context = runtime.default_context()
	when ODIN_DEBUG {
		if key == glfw.KEY_S && mods == glfw.MOD_CONTROL && action == glfw.PRESS {
			game.world_save_to_file("config.json")
		}

		if key == glfw.KEY_F1 && action == glfw.PRESS {
			gui.state.editor_mode = !gui.state.editor_mode
		}
		if key == glfw.KEY_GRAVE_ACCENT && action == glfw.PRESS {
			gui.state.console.visible = !gui.state.console.visible
			if !gui.state.console.visible {
				gui.unfocus()
			}
		}
	}
}

resize_callback :: proc "c" (window: glfw.WindowHandle, w, h: i32) {
	context = runtime.default_context()

	SCREEN = {f32(w), f32(h)}
	gl.Viewport(0, 0, w, h)
	game.cam.aspect = SCREEN.x / SCREEN.y
	render.mouse_picking_resize(&mouse_pick, {w, h})
}

get_input :: proc(window: glfw.WindowHandle) -> (input: bit_set[game.Event]) {
	when ODIN_DEBUG {
		if gui.state.io.WantCaptureKeyboard {
			return
		}
	}

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
	} else if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS {
		input += {.FlyDown}
	}

	return
}