package debug

import mu "vendor:microui"


ui_init :: proc() -> mu.Context {
	ctx : mu.Context
	mu.init(&ctx)

    ctx.text_width = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height
    return ctx
}


ui_render :: proc(ctx: ^mu.Context) {
    mu.begin(ctx)
    defer mu.end(ctx)

    if mu.begin_window(ctx, "My window", {10, 10, 140, 80}) {
		mu.end_window(ctx)
	}


    // TODO: get this working.
    cmd: ^mu.Command
    for mu.next_command(ctx, &cmd) {
        switch cmd {
        }

    }
}