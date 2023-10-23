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
					ambient = 0.25, diffuse = 0.5, specular = 0.75,
					color = glm.vec3(1),
					// ambient = glm.vec3(0.25),
					// diffuse = glm.vec3(0.5),
					// specular = glm.vec3(0.75),
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
			imgui.SameLine()
			delete_label := fmt.ctprintf("X##%s", label)
			if imgui.SmallButton(delete_label) {
				unordered_remove(&walls, i)
				state.entity = nil
			}
		}
	}
	if imgui.CollapsingHeader("Point Lights", nil) {
		for wall, i in point_lights {
			label := fmt.ctprintf("light-%d", i)
			if imgui.Button(label) {
				state.entity = &point_lights[i]
			}
			imgui.SameLine()
			delete_label := fmt.ctprintf("X##%s", label)
			if imgui.SmallButton(delete_label) {
				unordered_remove(&point_lights, i)
				state.entity = nil
			}
		}
	}

	if imgui.Button("Sword") {
		state.entity = &sword
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
		point_light_edit(v)
	case ^game.Ground:
		transform_edit(&v.entity)
	case ^game.Wall:
		transform_edit(&v.entity)
	case ^game.Door:
		transform_edit(&v.entity)
	case ^game.Sword:
		transform_edit(&v.entity)
	}
}

transform_edit :: proc(e: ^game.Entity) {
	imgui.DragFloat3Ex("Position", transmute(^[3]f32)&e.pos, 0.2, -99999, 99999, nil, nil)
	imgui.DragFloat3Ex("Rotation", transmute(^[3]f32)&e.rot, 0.2, -180, 180, nil, nil)
	imgui.DragFloat3Ex("Scale", transmute(^[3]f32)&e.scale, 0.2, -99999, 99999, nil, nil)
}

point_light_edit :: proc(p: ^game.PointLight) {
	imgui.DragFloat3("Position", transmute(^[3]f32)&p.pos)
	imgui.ColorEdit3("Color", transmute(^[3]f32)&p.color, nil)
	imgui.DragFloatEx("Radius", &p.radius, 0.2, 0, 500, nil, nil)
	imgui.DragFloatEx("Ambient", &p.ambient, 0.05, 0, 120, nil, nil)
	imgui.DragFloatEx("Diffuse", &p.diffuse, 0.05, 0, 120, nil, nil)
	imgui.DragFloatEx("Specular", &p.specular, 0.05, 0, 120, nil, nil)
}