package gui

import "core:fmt"
import "core:strings"
import glm "core:math/linalg/glsl"
import "core:reflect"

import "vendor:glfw"
import "../../libs/imgui"
import imgui_glfw "../../libs/imgui/imgui_impl_glfw"
import imgui_gl "../../libs/imgui/imgui_impl_opengl3"

import "../game"
import "../render"

EntityType :: enum {
	Entity,
	Light,
}
State :: struct {
	io: ^imgui.IO,
	entity_id: int,
	entity_type: EntityType,
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
	state.io = io
	imgui.StyleColorsDark(nil)

	imgui_glfw.InitForOpenGL(window, true)
	imgui_gl.Init("#version 450 core")
}

shutdown :: proc() {
	imgui_gl.Shutdown()
	imgui_glfw.Shutdown()
	imgui.DestroyContext(nil)
}

draw :: proc() {
	imgui_gl.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()

	imgui.ShowMetricsWindow(nil)

	// using game.world

	imgui.Begin("Entities", nil, {.NoMove, .NoCollapse, .MenuBar})
	if imgui.BeginMenuBar() {
		if imgui.BeginMenu("New") {
			if imgui.MenuItem("Cube") {
				append(&game.entities, game.Ent{})
				state.entity_id = len(game.entities) - 1
				state.entity_type = .Entity
			}
			if imgui.MenuItem("Point Light") {
				append(&game.lights, game.PointLight{
					radius = 10,
					ambient = 0.25, diffuse = 0.5, specular = 0.75,
					color = glm.vec3(1),
				})
				state.entity_type = .Light
			}
			imgui.EndMenu()
		}
	}
	imgui.EndMenuBar()

	if imgui.CollapsingHeader("Entities", nil) {
		for ent, i in game.entities {
			label := fmt.ctprintf("entity-%d", i)
			if imgui.Button(label) {
				state.entity_id = i
				state.entity_type = .Entity
			}
			imgui.SameLine()
			delete_label := fmt.ctprintf("X##%s", label)
			if imgui.SmallButton(delete_label) {
				unordered_remove(&game.entities, i)
				if state.entity_id == i {
					state.entity_id = -1
				}
			}
		}
	}

	if imgui.CollapsingHeader("Lights", nil) {
		for light, i in game.lights {
			label := fmt.ctprintf("light-%d", i)
			if imgui.Button(label) {
				state.entity_id = i
				state.entity_type = .Light
			}
			imgui.SameLine()
			delete_label := fmt.ctprintf("X##%s", label)
			if imgui.SmallButton(delete_label) {
				unordered_remove(&game.lights, i)
				if state.entity_id == i {
					state.entity_id = -1
				}
			}
		}
	}

	imgui.End()

	enitity_window()

	imgui.Render()
	imgui_gl.RenderDrawData(imgui.GetDrawData())

	when imgui.IMGUI_BRANCH == "docking" {
		backup_current_window := glfw.GetCurrentContext()
		imgui.UpdatePlatformWindows()
		imgui.RenderPlatformWindowsDefault()
		glfw.MakeContextCurrent(backup_current_window)
	}
}

enitity_window :: proc() {
	imgui.Begin("Entity", nil, nil)
	defer imgui.End()

	if state.entity_id == -1 {
		return
	}

	switch state.entity_type {
		case .Entity:
			entity_edit(&game.entities[state.entity_id])
		case .Light:
			point_light_edit(&game.lights[state.entity_id])
	}
}

entity_edit :: proc(e: ^game.Ent) {
	transform_edit(&e.transform)
	if imgui.CollapsingHeader("Texture", nil) {
		texture_edit(&e.texture)
		// imgui.ComboChar("Texture", &idx, &items[0], i32(len(items)))
		// unit := i32(e.texture.unit)
		// if imgui.ComboChar("Texture", &unit, &render.TEXTURE_PATHS[0], i32(len(render.TEXTURE_PATHS))) {
		// 	e.texture.unit = u32(unit)
		// }
	}
}

transform_edit :: proc(e: ^game.Transform) {
	imgui.DragFloat3Ex("Position", transmute(^[3]f32)&e.pos, 0.2, -99999, 99999, nil, nil)
	imgui.DragFloat3Ex("Rotation", transmute(^[3]f32)&e.rot, 0.2, -180, 180, nil, nil)
	imgui.DragFloat3Ex("Scale", transmute(^[3]f32)&e.scale, 0.2, -99999, 99999, nil, nil)
}

texture_edit :: proc(tex: ^game.Texture) {
	unit := i32(tex.unit)
	// imgui.ComboChar("Texture", &unit, raw_data(render.TEXTURE_PATHS[:]), i32(len(render.TEXTURE_PATHS)))
	imgui.Combo("Texture", &unit, render.TEXTURE_PATHS[0])
	// if imgui.BeginCombo("Texture", render.TEXTURE_PATHS[tex.unit], nil) {
	// 	for path, unit in render.TEXTURE_PATHS {
	// 		if imgui.Selectable(path) {
	// 			tex.unit = u32(unit)
	// 		}
	// 	}
	// 	imgui.EndCombo()
	// }

	imgui.DragScalar("Unit", .U32, &tex.unit)
	imgui.DragScalar("Tiling", .U32, &tex.tiling)
}

point_light_edit :: proc(p: ^game.PointLight) {
	imgui.DragFloat3("Position", transmute(^[3]f32)&p.pos)
	imgui.ColorEdit3("Color", transmute(^[3]f32)&p.color, nil)
	imgui.DragFloatEx("Radius", &p.radius, 0.2, 0, 500, nil, nil)
	imgui.DragFloatEx("Ambient", &p.ambient, 0.05, 0, 120, nil, nil)
	imgui.DragFloatEx("Diffuse", &p.diffuse, 0.05, 0, 120, nil, nil)
	imgui.DragFloatEx("Specular", &p.specular, 0.05, 0, 120, nil, nil)
}

is_selected :: proc(type: EntityType, id: int) -> bool {
	return state.entity_type == type && state.entity_id == id
}

want_capture_mouse :: proc() -> bool {
	return state.io.WantCaptureMouse
}