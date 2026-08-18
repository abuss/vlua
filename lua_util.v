// Simple Lua utilities for V
// Provides basic Lua state management and string conversion

module main

// Get error message from Lua stack
pub fn lua_error_msg(l voidptr) string {
	msg := C.lua_tostring(l, -1)
	if unsafe { msg == nil } {
		return 'unknown error'
	}
	return unsafe { cstring_to_vstring(*msg) }
}

// Create a new Lua state
pub fn new_state() ?voidptr {
	l := C.luaL_newstate()
	if l == 0 {
		return none
	}
	C.luaL_openlibs(l)
	return l
}

// Close a Lua state
pub fn close_state(l voidptr) {
	C.lua_close(l)
}

// Execute Lua code safely
pub fn safe_dostring(l voidptr, code string) !string {
	ret := C.luaL_dostring(l, code.str)
	if ret != 0 {
		msg := lua_error_msg(l)
		C.lua_pop(l, 1)
		return error(msg)
	}
	return ''
}

// Execute a Lua file safely
pub fn safe_dofile(l voidptr, filename string) !string {
	ret := C.luaL_dofile(l, filename.str)
	if ret != 0 {
		msg := lua_error_msg(l)
		C.lua_pop(l, 1)
		return error(msg)
	}
	return ''
}

// Get a global variable as string
pub fn get_global_string(l voidptr, name string) string {
	C.lua_getglobal(l, name.str)
	if C.lua_isnil(l, -1) != 0 {
		C.lua_pop(l, 1)
		return ''
	}
	s := C.lua_tostring(l, -1)
	C.lua_pop(l, 1)
	if unsafe { s == nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(*s) }
}

// Get a global variable as number
pub fn get_global_number(l voidptr, name string) f64 {
	C.lua_getglobal(l, name.str)
	if C.lua_isnil(l, -1) != 0 {
		C.lua_pop(l, 1)
		return 0
	}
	n := C.lua_tonumber(l, -1)
	C.lua_pop(l, 1)
	return n
}

// Set a global variable
pub fn set_global(l voidptr, name string, value string) {
	C.lua_pushstring(l, value.str)
	C.lua_setglobal(l, name.str)
}

// Register a V function as a callable Lua global.
// The function must have the signature `fn (l voidptr) int`: it reads its
// arguments from the Lua stack by index and returns the number of results
// it pushed back onto the stack.
pub fn register_function(l voidptr, name string, f fn (voidptr) int) {
	C.lua_pushcfunction(l, f)
	C.lua_setglobal(l, name.str)
}

// Set a global number
pub fn set_global_number(l voidptr, name string, value f64) {
	C.lua_pushnumber(l, value)
	C.lua_setglobal(l, name.str)
}
