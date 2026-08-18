// Simple Lua FFI wrapper for V
// Uses raw C calls with minimal abstraction

module vlua

#include <lua5.4/lua.h>
#include <lua5.4/lauxlib.h>
#include <lua5.4/lualib.h>

#flag linux -llua5.4
#flag darwin -I/usr/local/include
#flag darwin -I/opt/homebrew/include
#flag darwin -L/usr/local/lib
#flag darwin -L/opt/homebrew/lib
#flag darwin -llua5.4
#flag windows -llua54

// Minimal Lua C API declarations
fn C.luaL_newstate() voidptr
fn C.luaL_openlibs(L voidptr)
fn C.lua_close(L voidptr)
fn C.luaL_dostring(L voidptr, s &char) int
fn C.luaL_dofile(L voidptr, filename &char) int
fn C.luaL_loadstring(L voidptr, s &char) int
fn C.luaL_ref(L voidptr, t int) int
fn C.luaL_unref(L voidptr, t int, ref int)
fn C.lua_pcall(L voidptr, nargs int, nresults int, errfunc int) int
fn C.lua_error(L voidptr) int
fn C.lua_getglobal(L voidptr, name &char)
fn C.lua_getfield(L voidptr, idx int, k &char)
fn C.lua_setglobal(L voidptr, name &char)
fn C.lua_setfield(L voidptr, idx int, k &char)
fn C.lua_remove(L voidptr, idx int)
fn C.lua_newtable(L voidptr)
fn C.lua_next(L voidptr, idx int) int
fn C.lua_type(L voidptr, idx int) int
fn C.lua_tonumber(L voidptr, idx int) f64
fn C.lua_tointeger(L voidptr, idx int) i64
fn C.lua_isinteger(L voidptr, idx int) int
fn C.lua_tostring(L voidptr, idx int) &char
fn C.lua_istable(L voidptr, idx int) int
fn C.lua_isnil(L voidptr, idx int) int
fn C.lua_pop(L voidptr, n int)
fn C.lua_pushnil(L voidptr)
fn C.lua_pushnumber(L voidptr, n f64)
fn C.lua_pushinteger(L voidptr, n i64)
fn C.lua_pushstring(L voidptr, s &char)
fn C.lua_pushboolean(L voidptr, b bool)
fn C.lua_pushcfunction(L voidptr, f fn (voidptr) int)
fn C.lua_toboolean(L voidptr, idx int) int
fn C.lua_gettop(L voidptr) int
fn C.lua_rawlen(L voidptr, idx int) int
fn C.lua_rawgeti(L voidptr, idx int, n i64) int
fn C.lua_geti(L voidptr, idx int, n i64) int
fn C.lua_seti(L voidptr, idx int, n i64)
