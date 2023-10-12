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


SCREEN :: [2]i32{1200, 800}
ASPECT :: f32(SCREEN.x) / f32(SCREEN.y)
TITLE :: "Dungeon"

cam := render.Camera{
	fov = 70,
	aspect = ASPECT,
	near = 0.1, far = 1000,

	pos = {0, 0, 20},
	forward = {0, 0, 1}, right = {1, 0, 0},
	yaw = -90, pitch = 0,
	sensitivity = {0.01, 0.01},
	speed = 10000,
}

cursor_hidden := true


PointLight :: struct {
	pos: glm.vec3,
	ambient, diffuse, specular: glm.vec3,
}

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

	// glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
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

	shader, shader_err := render.shader_load("src/shaders/main.glsl")
	if shader_err != nil {
		fmt.eprintln("Failed to load shaders/main.glsl:", shader_err)
		return
	}

	brick_tex := render.texture_load(0, "assets/brick.jpg")
	brick_norm_tex := render.texture_load(1, "assets/brick_norm.jpg")
	ground_tex := render.texture_load(2, "assets/ground.png")
	ground_norm_tex := render.texture_load(3, "assets/ground_norm.png")
	textures := [?]i32{0, 1, 2, 3}

	projection := render.projection(cam)

    frames : i64
	prev_second : f32
	prev_frame_time : f32

	point_light := PointLight{
		pos = {0, 0, 0},
		ambient = {0.2, 0.2, 0.2},
		diffuse = {0.5, 0.5, 0.5},
		specular = {1, 1, 1},
	}

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

		if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
			cam.pos -= cam.right * cam.speed * dt 
		} else if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
			cam.pos += cam.right * cam.speed * dt
		}
		if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
			cam.pos += cam.forward * cam.speed * dt
		} else if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
			cam.pos -= cam.forward * cam.speed * dt
		}
		if glfw.GetKey(window, glfw.KEY_Q) == glfw.PRESS {
			cam.pos += glm.vec3{0, 1, 0} * cam.speed * dt
		}
		if glfw.GetKey(window, glfw.KEY_E) == glfw.PRESS {
			cam.pos -= glm.vec3{0, 1, 0} * cam.speed * dt
		}
		if glfw.GetKey(window, glfw.KEY_Z) == glfw.PRESS {
			cam.pos.y = 1
		}
		point_light.ambient = glm.vec3(gui.state.ambient)
		point_light.diffuse = glm.vec3(gui.state.diffuse)
		point_light.specular = glm.vec3(gui.state.specular)

		view := render.look_at(cam)

        glfw.PollEvents()

        gl.ClearColor(0, 0, 0, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

		// Draw cube
		gl.UseProgram(shader.id)
		render.setMat4(shader.id, "projection", &projection[0, 0])
		render.setMat4(shader.id, "view", &view[0, 0])
		render.setStruct(shader.id, "pointLight", PointLight, point_light)
		render.setFloat3(shader.id, "camPos", cam.pos);
		render.setIntArray(shader.id, "textures", len(textures), &textures[0])

		// gl.ActiveTexture(brick_tex.id)
		gl.BindTextureUnit(brick_tex.unit, brick_tex.id)
		gl.BindTextureUnit(brick_norm_tex.unit, brick_norm_tex.id)
		gl.BindTextureUnit(ground_tex.unit, ground_tex.id)
		gl.BindTextureUnit(ground_norm_tex.unit, ground_norm_tex.id)
		for wall in game.world.walls {
			model := game.entity_model(wall)
			render.mesh_draw(&cube_mesh, model, brick_tex.unit, 10)
		}
		for ground in game.world.grounds {
			// model := glm.mat4Scale({100, 0.1, 100}) * glm.mat4Translate({0, -1, 0})
			model := game.entity_model(ground)
			render.mesh_draw(&cube_mesh, model, ground_tex.unit, 100)
		}

		// Draw light
		render.mesh_draw(&cube_mesh, glm.mat4Translate(point_light.pos), brick_tex.unit, 10)

		render.mesh_flush(&cube_mesh)

		gui.render()

		render.watch(&shader)
        glfw.SwapBuffers(window)
        free_all(context.temp_allocator)

		if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
			break
		}
    }
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()
	if cursor_hidden {
		render.on_mouse_move(&cam, {f32(xpos), f32(ypos)})
	}
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()

	if button == glfw.MOUSE_BUTTON_RIGHT && action == glfw.PRESS {
		cursor_hidden = !cursor_hidden
		render.init_mouse = false

		if cursor_hidden {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_DISABLED)
		} else {
			glfw.SetInputMode(window, glfw.CURSOR, glfw.CURSOR_NORMAL)
		}
	}
}

print_mat :: proc(m: glm.mat4) {
	fmt.println(m[0])
	fmt.println(m[1])
	fmt.println(m[2])
	fmt.println(m[3])
}