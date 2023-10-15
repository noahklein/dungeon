package gui

import "core:fmt"
import "core:strings"
import glm "core:math/linalg/glsl"
import "core:reflect"

import "vendor:glfw"
import "../libs/imgui"
import imgui_glfw "../libs/imgui/imgui_impl_glfw"
import imgui_gl "../libs/imgui/imgui_impl_opengl3"

import "../game"

State :: struct {
	entity: game.Thing,
	rotation: [3]f32, // Euler angles
}

state : State

init :: proc(window: glfw.WindowHandle) {
    imgui.CHECKVERSION()
	imgui.CreateContext(nil)

	io := imgui.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableSetMousePos}
	when imgui.IMGUI_BRANCH == "docking" {
		io.ConfigFlags += {.DockingEnable}
		io.ConfigFlags += {.ViewportsEnable}

		style := imgui.GetStyle()
		style.WindowRounding = 0
		style.Colors[imgui.Col.WindowBg].w = 1
	}
	imgui.StyleColorsDark(nil)

	imgui_glfw.InitForOpenGL(window, true)
	imgui_gl.Init("#version 450 core")
}

shutdown :: proc() {
	imgui_gl.Shutdown()
	imgui_glfw.Shutdown()
    imgui.DestroyContext(nil)
}

render :: proc() {
    imgui_gl.NewFrame()
    imgui_glfw.NewFrame()
    imgui.NewFrame()

	imgui.ShowMetricsWindow(nil)

	using game.world

	imgui.Begin("Entities", nil, {.NoMove, .NoCollapse, .MenuBar})
	if imgui.BeginMenuBar() {
		if imgui.BeginMenu("New") {
			if imgui.MenuItem("Ground") {
				append(&grounds, game.Ground{scale = glm.vec3(1)})
				state.entity = &grounds[len(grounds) - 1]
			}
			if imgui.MenuItem("Walls") {
				append(&walls, game.Wall{scale = glm.vec3(1)})
				state.entity = &walls[len(walls) - 1]
			}
			if imgui.MenuItem("Point Light") {
				append(&point_lights, game.PointLight{
					radius = 10,
					ambient = glm.vec3(0.25),
					diffuse = glm.vec3(0.5),
					specular = glm.vec3(0.75),
				})
				state.entity = &point_lights[len(point_lights) - 1]
			}
			imgui.EndMenu()
		}
	}
	imgui.EndMenuBar()

	if imgui.CollapsingHeader("Ground", nil) {
		for ground, i in grounds {
			label := fmt.ctprintf("ground-%d", i)
			if imgui.Button(label) {
				state.entity = &grounds[i]
			}
			imgui.SameLine()
			delete_label := fmt.ctprintf("X##%s", label)
			if imgui.SmallButton(delete_label) {
				unordered_remove(&grounds, i)
				state.entity = nil
			}
		}
	}
	if imgui.CollapsingHeader("Walls", nil) {
		for wall, i in walls {
			label := fmt.ctprintf("wall-%d", i)
			if imgui.Button(label) {
				state.entity = &walls[i]
			}
		}
	}
	if imgui.CollapsingHeader("Point Lights", nil) {
		for wall, i in point_lights {
			label := fmt.ctprintf("light-%d", i)
			if imgui.Button(label) {
				state.entity = &point_lights[i]
			}
		}
	}
	imgui.End()

	enitity_window(state.entity)

    imgui.Render()
    imgui_gl.RenderDrawData(imgui.GetDrawData())

    when imgui.IMGUI_BRANCH == "docking" {
        backup_current_window := glfw.GetCurrentContext()
        imgui.UpdatePlatformWindows()
        imgui.RenderPlatformWindowsDefault()
        glfw.MakeContextCurrent(backup_current_window)
    }
}

enitity_window :: proc(entity: game.Thing) {
	imgui.Begin("Entity", nil, nil)
	defer imgui.End()

	if entity == nil {
		return
	}


	switch v in entity {
	case ^game.PointLight:
		imgui.DragFloat3("Position", transmute(^[3]f32)&v.pos)
		imgui.DragInt("Radius", &v.radius)
		imgui.ColorEdit3("Ambient", transmute(^[3]f32)&v.ambient, nil)
		imgui.ColorEdit3("Diffuse", transmute(^[3]f32)&v.diffuse, nil)
		imgui.ColorEdit3("Specular", transmute(^[3]f32)&v.specular, nil)
	case ^game.Ground:
		imgui.DragFloat3("Position", transmute(^[3]f32)&v.pos)
		imgui.DragFloat3("Scale", transmute(^[3]f32)&v.scale)
	case ^game.Wall:
		imgui.DragFloat3("Position", transmute(^[3]f32)&v.pos)
		imgui.DragFloat3("Scale", transmute(^[3]f32)&v.scale)
	case ^game.Door:
	}
}

quaternion_editor :: proc(q: ^glm.quat) {
	if imgui.DragFloat3("Rotation", &state.rotation) {
		// ^q = glm.quat
	}
}