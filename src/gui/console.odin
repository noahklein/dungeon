package gui

import "core:fmt"
import "core:strings"
import "../game"
import "../../libs/imgui"

Console :: struct {
    visible: bool,
    history: [dynamic]ConsoleHistory,
    commands: map[string]CommandProc
}

CommandProc :: proc([]string) -> (cstring, bool)

ConsoleHistory :: struct {
    cmd, result: cstring,
    success: bool,
}
input_buf : [128]u8

console_init :: proc() {
    console_register("level", console_load_level)
    console_register("help", console_help)
}

console_deinit :: proc() {
	for entry in state.console.history{
		delete(entry.cmd)
        if entry.result != nil {
            delete(entry.result)
        }
	}
	delete(state.console.history)
	delete(state.console.commands)
}

console_window :: proc() {
    if !state.console.visible {
        return
    }

    imgui.Begin("Console", nil, {.NoTitleBar})
    defer imgui.End()

    console_scroll_region()
    console_input_region()
}

console_scroll_region :: proc() {
    height := imgui.GetStyle().ItemSpacing.y + imgui.GetFrameHeightWithSpacing()
    imgui.BeginChild("ConsoleScroll", {0, -height}, false, nil)
    defer imgui.EndChild()

    for entry, i in state.console.history {
        color: [4]f32 = entry.success ? {0, 1, 0, 1} : {1, 0, 0, 1}
        imgui.TextColored(color, "> %s", entry.cmd)
        imgui.TextUnformatted(entry.result)
    }
}

console_input_region ::  proc() {
    buf := cstring(raw_data(&input_buf))

    if imgui.IsWindowAppearing() {
        imgui.SetKeyboardFocusHere()
    }
    if imgui.InputText("Input", buf, len(input_buf), { .EnterReturnsTrue }) {
        if len(buf) == 0 {
            return
        }

        result, success := console_run_command(string(buf))

        append(&state.console.history, ConsoleHistory{
            cmd = strings.clone_to_cstring(string(input_buf[:])),
            result = result,
            success = success,
        })

        input_buf = {}
        imgui.SetKeyboardFocusHereEx(-1)
    }
}

console_run_command :: proc(cmd: string) -> (cstring, bool) {
    assert(len(cmd) != 0)

    tokens := strings.split(cmd, " ", context.temp_allocator)
    if tokens[0] not_in state.console.commands {
        return "Unsupported command", false
    }
    cmd_proc := state.console.commands[tokens[0]]

    args := len(tokens) == 1 ? nil : tokens[1:]
    return cmd_proc(args)
}

console_register :: proc(cmd: string, cmd_proc: CommandProc) {
    state.console.commands[cmd] = cmd_proc
}

console_help :: proc(_ : []string) -> (cstring, bool) {
    sb := strings.builder_make(context.temp_allocator)
    strings.write_string(&sb, "Registered commands:")
    for cmd in state.console.commands {
        strings.write_string(&sb, "\n\t\t")
        strings.write_string(&sb, cmd)
    }
    s := strings.to_string(sb)
    return strings.clone_to_cstring(s), true
}

console_load_level :: proc(args: []string) -> (cstring, bool) {
    if len(args) != 1 {
        return "Failed: level command requires exactly one file argument", false
    }
    game.world_load(args[0]) // @TODO: report failure
    return "Loaded level", true
}