package debug

import "vendor:glfw"
import "../libs/imgui"
import imgui_glfw "../libs/imgui/imgui_impl_glfw"
import imgui_gl "../libs/imgui/imgui_impl_opengl3"

gui_init :: proc(window: glfw.WindowHandle) {
    imgui.CHECKVERSION()
	imgui.CreateContext(nil)

	gui_io := imgui.GetIO()
	gui_io.ConfigFlags += {.NavEnableKeyboard, .NavEnableSetMousePos}
	when imgui.IMGUI_BRANCH == "docking" {
		gui_io.ConfigFlags += {.DockingEnable}
		gui_io.ConfigFlags += {.ViewportsEnable}

		style := imgui.GetStyle()
		style.WindowRounding = 0
		style.Colors[imgui.Col.WindowBg].w = 1
	}
	imgui.StyleColorsDark(nil)

	imgui_glfw.InitForOpenGL(window, true)
	imgui_gl.Init("#version 450 core")
}

gui_shutdown :: proc() {
	imgui_gl.Shutdown()
	imgui_glfw.Shutdown()
    imgui.DestroyContext(nil)
}

gui_render :: proc() {
    imgui_gl.NewFrame()
    imgui_glfw.NewFrame()
    imgui.NewFrame()
    imgui.ShowDemoWindow(nil)

    imgui.Render()
    imgui_gl.RenderDrawData(imgui.GetDrawData())

    when imgui.IMGUI_BRANCH == "docking" {
        backup_current_window := glfw.GetCurrentContext()
        imgui.UpdatePlatformWindows()
        imgui.RenderPlatformWindowsDefault()
        glfw.MakeContextCurrent(backup_current_window)
    }
}