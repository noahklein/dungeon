package debug

import "core:fmt"
import "core:runtime"
import gl "vendor:OpenGL"

on_debug_msg :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	msg: cstring,
	user_param: rawptr,
) {
	context = runtime.default_context()
	fmt.printf(
		"(%s) [%s] %s: %s\n",
		log_severity_to_string(severity),
		log_source_to_string(source),
		log_type_to_string(type),
		cstring(msg),
	)
}


log_type_to_string :: proc(type: u32) -> string {
	switch (type) {
	case gl.DEBUG_TYPE_ERROR:
		return "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		return "Deprecated behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		return "Undefined behavior"
	case gl.DEBUG_TYPE_PORTABILITY:
		return "Portability issue"
	case gl.DEBUG_TYPE_PERFORMANCE:
		return "Performance issue"
	case gl.DEBUG_TYPE_MARKER:
		return "Stream annotation"
	case gl.DEBUG_TYPE_OTHER_ARB:
		return "Other"
	case:
		assert(false)
		return ""
	}
}

log_source_to_string :: proc(source: u32) -> string {
	switch (source) {
	case gl.DEBUG_SOURCE_API:
		return "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
		return "Window system"
	case gl.DEBUG_SOURCE_SHADER_COMPILER:
		return "Shader compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY:
		return "Third party"
	case gl.DEBUG_SOURCE_APPLICATION:
		return "Application"
	case gl.DEBUG_SOURCE_OTHER:
		return "Other"
	case:
		assert(false)
		return ""
	}
}

log_severity_to_string :: proc(severity: u32) -> string {
	switch (severity) {
	case gl.DEBUG_SEVERITY_HIGH:
		return "High"
	case gl.DEBUG_SEVERITY_MEDIUM:
		return "Medium"
	case gl.DEBUG_SEVERITY_LOW:
		return "Low"
	case gl.DEBUG_SEVERITY_NOTIFICATION:
		return "Info"
	case:
		assert(false)
		return ""
	}
}