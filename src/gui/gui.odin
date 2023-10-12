package gui

import "core:fmt"
import "core:strings"
import glm "core:math/linalg/glsl"

import "vendor:glfw"
import "../libs/imgui"
import imgui_glfw "../libs/imgui/imgui_impl_glfw"
import imgui_gl "../libs/imgui/imgui_impl_opengl3"

import "../game"

State :: struct {
	open: bool,
	ambient: [3]f32,
	diffuse: [3]f32,
	specular: [3]f32,

	entity: ^game.Entity,
	position: [3]f32,
}

state := State{
	open = true,
	ambient = {0.2, 0.2, 0.2},
	diffuse = {0.5, 0.5, 0.5},
	specular = {1, 1, 1},
}

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

	imgui.Begin("Entities", nil, nil)
	if imgui.CollapsingHeader("Ground", nil) {
		for ground, i in game.world.grounds {
			label := fmt.ctprintf("ground-%d", i)
			if imgui.Button(label) {
				state.entity = &game.world.grounds[i]
			}
		}
	}
	if imgui.CollapsingHeader("Walls", nil) {
		for wall, i in game.world.walls {
			label := fmt.ctprintf("wall-%d", i)
			if imgui.Button(label) {
				state.entity = &game.world.walls[i]
			}
		}
	}
	imgui.End()

	imgui.Begin("Entity", nil, nil)
	if state.entity != nil {
		imgui.DragFloat3("Position", transmute(^[3]f32)&state.entity.pos)
		imgui.DragFloat3("Scale", transmute(^[3]f32)&state.entity.scale)
	}
	imgui.End()

	if imgui.Begin("Light", &state.open, {.MenuBar}) {
		imgui.ColorEdit3("Ambient", &state.ambient, nil)
		imgui.ColorEdit3("Diffuse", &state.diffuse, nil)
		imgui.ColorEdit3("Specular", &state.specular, nil)
	}
	imgui.End()

    imgui.Render()
    imgui_gl.RenderDrawData(imgui.GetDrawData())

    when imgui.IMGUI_BRANCH == "docking" {
        backup_current_window := glfw.GetCurrentContext()
        imgui.UpdatePlatformWindows()
        imgui.RenderPlatformWindowsDefault()
        glfw.MakeContextCurrent(backup_current_window)
    }
}