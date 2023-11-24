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
import "../storage"

EntityType :: enum {
	Entity,
	Light,
}
State :: struct {
	io: ^imgui.IO,
	entity_id: game.EntityId,
	entity_type: EntityType,
	editor_mode: bool, // Enable clicking on an entity to select.

	console: Console,
}

state : State

init :: proc(window: glfw.WindowHandle) {
	imgui.CHECKVERSION()
	imgui.CreateContext(nil)

	io := imgui.GetIO()
	io.ConfigFlags += {.NavEnableSetMousePos}
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

	console_init()
}

shutdown :: proc() {
	imgui_gl.Shutdown()
	imgui_glfw.Shutdown()
	imgui.DestroyContext(nil)
	console_deinit()
}

draw :: proc() {
	imgui_gl.NewFrame()
	imgui_glfw.NewFrame()
	imgui.NewFrame()

	// @TODO: stats window (FPS, etc.)

	imgui.Begin("Entities", nil, {.NoMove, .NoCollapse, .MenuBar, .NoFocusOnAppearing})
	if imgui.BeginMenuBar() {
		if imgui.BeginMenu("New") {
			if imgui.MenuItem("Cube") {
				append(&game.entities, game.Ent{})
				state.entity_id = game.EntityId(len(game.entities) - 1)
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
	console_window()

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
	imgui.Begin("Entity", nil, {.NoFocusOnAppearing})
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
	}

	if imgui.CollapsingHeader("Collider", nil) {
		collider_edit(state.entity_id)
	}

	if imgui.CollapsingHeader("Rigidbody", nil) {
		rb_id, ok := e.rigidbody_id.?
		if ok {
			rigidbody_edit(rb_id)
			return
		}

		if imgui.Button("Add Rigidbody") {
			game.physics_add_rigidbody(state.entity_id, 1)
			// e.rigidbody_id = storage.dense_add(&game.physics.rigidbodies, game.Rigidbody{})
		}
	}

}

transform_edit :: proc(e: ^game.Transform) {
	imgui.DragFloat3Ex("Position", transmute(^[3]f32)&e.pos, 0.2, -99999, 99999, nil, nil)
	imgui.DragFloat3Ex("Rotation", transmute(^[3]f32)&e.rot, 0.2, -180, 180, nil, nil)
	imgui.DragFloat3Ex("Scale", transmute(^[3]f32)&e.scale, 0.2, -99999, 99999, nil, nil)
}

texture_edit :: proc(tex: ^game.Texture) {
	paths := render.TEXTURE_PATHS

	unit := i32(tex.unit)
	if imgui.ComboChar("Texture", &unit, &paths[0], i32(len(paths))) {
		tex.unit = u32(unit)

	}

	imgui.DragScalar("Unit", .U32, &tex.unit)
	imgui.DragScalar("Tiling", .U32, &tex.tiling)
}

rigidbody_edit :: proc(rb_id: storage.DenseID) {
	rb := storage.dense_get(game.physics.rigidbodies, rb_id)
	if rb == nil {
		return
	}

	imgui.DragFloat3("Velocity", transmute(^[3]f32)&rb.velocity)
}

collider_edit :: proc(ent_id: game.EntityId) {
	collider, exists := game.physics_find_collider(ent_id)
	if !exists {
		if imgui.Button("Add Sphere Collider") {
			append(&game.physics.spheres, game.SphereCollider{
				ent_id = ent_id,
				radius = 1,
			})
		}
		if imgui.Button("Add Plane Collider") {
			append(&game.physics.planes, game.PlaneCollider{
				ent_id = ent_id,
			})
		}
		return
	}

	switch c in collider {
		case ^game.SphereCollider:
			imgui.DragFloat3("Center", transmute(^[3]f32)&c.center)
			imgui.DragFloatEx("Radius", &c.radius, 0.05, 0.1, 20, nil, nil)
		case ^game.PlaneCollider:
			imgui.DragFloat3("Normal", transmute(^[3]f32)&c.normal)
	}
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

want_capture_mouse :: #force_inline proc() -> bool {
	when !ODIN_DEBUG {
		return false
	}
	return state.io.WantCaptureMouse
}

// Unfocus all imgui windows.
unfocus :: #force_inline proc() {
	imgui.SetWindowFocusStr(nil)
}