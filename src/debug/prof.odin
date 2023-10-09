package debug

import "core:prof/spall"

ctx : spall.Context
buf : spall.Buffer

ENABLE_SPALL :: #config(ENABLE_SPALL, false) // TODO: disable
when ENABLE_SPALL {
    TRACE :: spall.SCOPED_EVENT
} else {
    TRACE :: #force_inline proc(ctx: ^spall.Context, buf: ^spall.Buffer, name: string) -> bool { return true }
}

prof_init :: proc() { 
    ctx = spall.context_create("trace_test.spall")

    buffer_backing := make([]u8, spall.BUFFER_DEFAULT_SIZE)
    buf = spall.buffer_create(buffer_backing)
}

prof_deinit :: proc() { 
    spall.buffer_destroy(&ctx, &buf)
    spall.context_destroy(&ctx)
}

