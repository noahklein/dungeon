package render

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
}

texture_format :: proc(tf: TextureFormat) -> (u32, u32) {
	switch tf {
		case .RGB:
			return gl.RGB8, gl.RGB
		case .RGBA:
			return gl.RGBA8, gl.RGBA
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
