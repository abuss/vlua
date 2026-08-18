// Simple Lua utilities for V
// Provides basic Lua state management and string conversion

module main

// Lua type ids (luaconf.h)
const lua_tnil = 0
const lua_tboolean = 1
const lua_tnumber = 3
const lua_tstring = 4
const lua_ttable = 5
const lua_tfunction = 6
const lua_multret = -1

// General value type for heterogeneous/nested Lua tables.
enum LuaValueKind {
	number
	string
	boolean
	table
}

struct LuaValue {
mut:
	kind     LuaValueKind
	num      f64
	str      string
	b        bool
	children map[string]LuaValue
	array    []LuaValue
}

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

// Read the value at Lua stack index `idx` into a LuaValue without popping
// it. Recurses into tables; non-string/number/bool/table values fall back to
// LuaValue kind `.number` with value 0.
fn read_value_at(l voidptr, idx int) LuaValue {
	typ := C.lua_type(l, idx)
	match typ {
		lua_tnumber {
			return LuaValue{
				kind: .number
				num:  C.lua_tonumber(l, idx)
			}
		}
		lua_tstring {
			s := C.lua_tostring(l, idx)
			return LuaValue{
				kind: .string
				str:  unsafe { cstring_to_vstring(*s) }
			}
		}
		lua_tboolean {
			return LuaValue{
				kind: .boolean
				b:    C.lua_toboolean(l, idx) != 0
			}
		}
		lua_ttable {
			tb := if idx < 0 {
				C.lua_gettop(l) + idx + 1
			} else {
				idx
			}
			mut v := LuaValue{
				kind:     .table
				children: map[string]LuaValue{}
			}
			n := C.lua_rawlen(l, tb)
			for i := i64(1); i <= n; i++ {
				C.lua_geti(l, tb, i)
				if C.lua_isnil(l, -1) != 0 {
					C.lua_pop(l, 1)
					continue
				}
				v.array << read_value_at(l, -1)
				C.lua_pop(l, 1)
			}
			C.lua_pushnil(l)
			for C.lua_next(l, tb) != 0 {
				if C.lua_type(l, -2) == lua_tstring {
					ks := C.lua_tostring(l, -2)
					v.children[unsafe { cstring_to_vstring(*ks) }] = read_value_at(l, -1)
				}
				C.lua_pop(l, 1)
			}
			return v
		}
		else {
			return LuaValue{}
		}
	}
}

// Read the value at the top of the Lua stack without popping it.
fn read_value_at_top(l voidptr) LuaValue {
	return read_value_at(l, -1)
}

// Push a LuaValue onto the Lua stack (recurses into tables).
fn push_value(l voidptr, v LuaValue) {
	match v.kind {
		.number {
			C.lua_pushnumber(l, v.num)
		}
		.string {
			C.lua_pushstring(l, v.str.str)
		}
		.boolean {
			C.lua_pushboolean(l, v.b)
		}
		.table {
			C.lua_newtable(l)
			tb := C.lua_gettop(l)
			for i, e in v.array {
				push_value(l, e)
				C.lua_seti(l, tb, i64(i) + 1)
			}
			for key, val in v.children {
				push_value(l, val)
				C.lua_setfield(l, tb, key.str)
			}
		}
	}
}

// Read a global Lua table into a map[string]f64 (string keys only).
pub fn get_table_f64(l voidptr, name string) map[string]f64 {
	mut result := map[string]f64{}
	C.lua_getglobal(l, name.str)
	if C.lua_istable(l, -1) == 0 {
		C.lua_pop(l, 1)
		return result
	}
	C.lua_pushnil(l)
	for C.lua_next(l, -2) != 0 {
		if C.lua_type(l, -2) == lua_tstring && C.lua_type(l, -1) == lua_tnumber {
			ks := C.lua_tostring(l, -2)
			result[unsafe { cstring_to_vstring(*ks) }] = C.lua_tonumber(l, -1)
		}
		C.lua_pop(l, 1)
	}
	C.lua_pop(l, 1)
	return result
}

// Read a global Lua table-name into a map[string]string (string keys only).
pub fn get_table_string(l voidptr, name string) map[string]string {
	mut result := map[string]string{}
	C.lua_getglobal(l, name.str)
	if C.lua_istable(l, -1) == 0 {
		C.lua_pop(l, 1)
		return result
	}
	C.lua_pushnil(l)
	for C.lua_next(l, -2) != 0 {
		if C.lua_type(l, -2) == lua_tstring && C.lua_type(l, -1) == lua_tstring {
			ks := C.lua_tostring(l, -2)
			vs := C.lua_tostring(l, -1)
			result[unsafe { cstring_to_vstring(*ks) }] = unsafe { cstring_to_vstring(*vs) }
		}
		C.lua_pop(l, 1)
	}
	C.lua_pop(l, 1)
	return result
}

// Set a global table from a map[string]f64.
pub fn set_table_f64(l voidptr, name string, m map[string]f64) {
	C.lua_newtable(l)
	tb := C.lua_gettop(l)
	for key, val in m {
		C.lua_pushnumber(l, val)
		C.lua_setfield(l, tb, key.str)
	}
	C.lua_setglobal(l, name.str)
}

// Set a global table from a map[string]string.
pub fn set_table_string(l voidptr, name string, m map[string]string) {
	C.lua_newtable(l)
	tb := C.lua_gettop(l)
	for key, val in m {
		C.lua_pushstring(l, val.str)
		C.lua_setfield(l, tb, key.str)
	}
	C.lua_setglobal(l, name.str)
}

// Read a global array-like Lua table into []f64 (integer keys 1..#t).
pub fn get_array_f64(l voidptr, name string) []f64 {
	mut result := []f64{}
	C.lua_getglobal(l, name.str)
	if C.lua_istable(l, -1) == 0 {
		C.lua_pop(l, 1)
		return result
	}
	tb := C.lua_gettop(l)
	n := C.lua_rawlen(l, tb)
	for i := i64(1); i <= n; i++ {
		C.lua_geti(l, tb, i)
		if C.lua_type(l, -1) == lua_tnumber {
			result << C.lua_tonumber(l, -1)
		}
		C.lua_pop(l, 1)
	}
	C.lua_pop(l, 1)
	return result
}

// Read a global array-like Lua table into []string.
pub fn get_array_string(l voidptr, name string) []string {
	mut result := []string{}
	C.lua_getglobal(l, name.str)
	if C.lua_istable(l, -1) == 0 {
		C.lua_pop(l, 1)
		return result
	}
	tb := C.lua_gettop(l)
	n := C.lua_rawlen(l, tb)
	for i := i64(1); i <= n; i++ {
		C.lua_geti(l, tb, i)
		if C.lua_type(l, -1) == lua_tstring {
			s := C.lua_tostring(l, -1)
			result << unsafe { cstring_to_vstring(*s) }
		}
		C.lua_pop(l, 1)
	}
	C.lua_pop(l, 1)
	return result
}

// Set a global array-like Lua table from []f64.
pub fn set_array_f64(l voidptr, name string, arr []f64) {
	C.lua_newtable(l)
	tb := C.lua_gettop(l)
	for i, val in arr {
		C.lua_pushnumber(l, val)
		C.lua_seti(l, tb, i64(i) + 1)
	}
	C.lua_setglobal(l, name.str)
}

// Set a global array-like Lua table from []string.
pub fn set_array_string(l voidptr, name string, arr []string) {
	C.lua_newtable(l)
	tb := C.lua_gettop(l)
	for i, val in arr {
		C.lua_pushstring(l, val.str)
		C.lua_seti(l, tb, i64(i) + 1)
	}
	C.lua_setglobal(l, name.str)
}

// Read any global value (scalar, table, or nested table) as a LuaValue.
// Errors if the global is nil or missing.
pub fn get_global_value(l voidptr, name string) !LuaValue {
	C.lua_getglobal(l, name.str)
	if C.lua_isnil(l, -1) != 0 {
		C.lua_pop(l, 1)
		return error('global "$name" is nil or missing')
	}
	v := read_value_at_top(l)
	C.lua_pop(l, 1)
	return v
}

// Set a global value from a LuaValue.
pub fn set_global_value(l voidptr, name string, v LuaValue) {
	push_value(l, v)
	C.lua_setglobal(l, name.str)
}

// Call a global Lua function with the given arguments and collect its
// return values. Errors if the global is not a function or the call fails.
pub fn call_function(l voidptr, name string, args []LuaValue) ![]LuaValue {
	C.lua_getglobal(l, name.str)
	if C.lua_type(l, -1) != lua_tfunction {
		C.lua_pop(l, 1)
		return error('global "$name" is not a function')
	}
	for a in args {
		push_value(l, a)
	}
	if C.lua_pcall(l, args.len, lua_multret, 0) != 0 {
		msg := lua_error_msg(l)
		C.lua_pop(l, 1)
		return error(msg)
	}
	mut results := []LuaValue{}
	n := C.lua_gettop(l)
	for i := -n; i <= -1; i++ {
		results << read_value_at(l, i)
	}
	C.lua_pop(l, n)
	return results
}
