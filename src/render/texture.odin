package render

import "core:fmt"
import glm "core:math/linalg/glsl"

import "vendor:stb/image"
import gl "vendor:OpenGL"

Texture :: struct { 
	id, unit: u32,
	format: u32,
}

TextureOptions :: struct {
	width, height: i32,
	format: TextureFormat,
	min_filter, mag_filter: i32,
	wrap_s, wrap_t: i32,
}

TextureFormat :: enum {
	RGB,
	RGBA,
	RED_INT,
}

texture_format :: proc(tf: TextureFormat) -> (u32, u32) {
	switch tf {
		case .RGB:
			return gl.RGB8, gl.RGB
		case .RGBA:
			return gl.RGBA8, gl.RGBA
		case .RED_INT:
			return gl.R32I, gl.RED_INTEGER
		case:
			panic("unsupported texture format")
	}
}

texture_init :: proc(unit: u32, opt: TextureOptions) -> Texture {
    tex: Texture
	internal, format := texture_format(opt.format)
	tex.format = format
	tex.unit = unit

	gl.CreateTextures(gl.TEXTURE_2D, 1, &tex.id)
	gl.TextureStorage2D(tex.id, 1, internal, opt.width, opt.height)
	gl.TextureParameteri(tex.id, gl.TEXTURE_MIN_FILTER, opt.min_filter)
	gl.TextureParameteri(tex.id, gl.TEXTURE_MAG_FILTER, opt.mag_filter)

	if opt.wrap_s != 0 {
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, opt.wrap_s);
	}
	if opt.wrap_t != 0 {
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, opt.wrap_t);
	}

    gl.BindTextureUnit(tex.unit, tex.id)

    return tex
}

texture_load :: proc(unit: u32, path: cstring) -> Texture {
	image.set_flip_vertically_on_load(1)
	width, height, channels: i32
	img := image.load(path, &width, &height, &channels, 0)
    defer image.image_free(img)

	tex := texture_init(unit, TextureOptions{
		width = width, height = height,
		format = gl_format(channels),
		min_filter = gl.LINEAR, mag_filter = gl.NEAREST,
		wrap_s = gl.REPEAT, wrap_t = gl.REPEAT,
	})

	gl.TextureSubImage2D(tex.id, 0, 0, 0, width, height, tex.format, gl.UNSIGNED_BYTE, img)

	return tex
}

gl_format :: #force_inline proc(channels: i32) -> TextureFormat{
	switch channels {
		case 3: return .RGB
		case 4: return .RGBA
		case: panic("unsupported channels")
	}
}

// Texture for mouse-picking. Each pixel is an entity ID.
MousePicking :: struct {
	fbo, rbo: u32,
	tex, entity_id_tex: u32,
}

mouse_picking_init :: proc(screen: glm.vec2) -> (mp: MousePicking, ok: bool) {
	size := glm.ivec2{i32(screen.x), i32(screen.y)}

	gl.GenFramebuffers(1, &mp.fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, mp.fbo)
	defer gl.BindFramebuffer(gl.FRAMEBUFFER, 0)

	// defer gl.BindTexture(gl.TEXTURE_2D, 0)

	// Color texture
	tex := texture_init(0, TextureOptions{
		width = size.x, height = size.y,
		format = .RGB,
		min_filter = gl.LINEAR, mag_filter = gl.LINEAR,
	})
	mp.tex = tex.id

	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, mp.tex, 0)

	// Depth and stencil render buffer
	gl.GenRenderbuffers(1, &mp.rbo)
	gl.BindRenderbuffer(gl.RENDERBUFFER, mp.rbo)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, size.x, size.y)
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, mp.rbo)

	// Entity IDs for mouse picking
	entity_id_tex := texture_init(0, TextureOptions{
		width = size.x, height = size.y, 
		format = .RED_INT,
		min_filter = gl.LINEAR, mag_filter = gl.LINEAR,
	})
	mp.entity_id_tex = entity_id_tex.id
	// gl.GenTextures(1, &mp.entity_id_tex)
	// gl.BindTexture(gl.TEXTURE_2D, mp.entity_id_tex)
	// gl.TexImage2D(gl.TEXTURE_2D, 0, gl.R32I, size.x, size.y,
	// 	0, gl.RED_INTEGER, gl.INT, nil)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT1, gl.TEXTURE_2D, mp.entity_id_tex, 0)

	gl.ReadBuffer(gl.NONE)
	// gl.DrawBuffer(gl.COLOR_ATTACHMENT0)
	attachments := [?]u32{gl.COLOR_ATTACHMENT0, gl.COLOR_ATTACHMENT1}
	gl.DrawBuffers(2, &attachments[0])

	if status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER); status != gl.FRAMEBUFFER_COMPLETE {
		fmt.eprintln("Mouse picking framebuffer error: status =", status)
		return mp, false
	}

	return mp, true
}

mouse_picking_begin :: proc(mp: MousePicking) {
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, mp.fbo)
}

mouse_picking_end :: proc() {
	gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, 0)
}

mouse_picking_read :: proc(mp: MousePicking, coord: glm.vec2) -> int {
	x, y := i32(coord.x), i32(coord.y)
	
	gl.BindFramebuffer(gl.READ_FRAMEBUFFER, mp.fbo)
	defer gl.BindFramebuffer(gl.READ_FRAMEBUFFER, 0)

	gl.ReadBuffer(gl.COLOR_ATTACHMENT1)
	defer gl.ReadBuffer(gl.NONE)

	id : int
	gl.ReadPixels(x, y, 1, 1, gl.RED_INTEGER, gl.INT, &id)

	return id
}