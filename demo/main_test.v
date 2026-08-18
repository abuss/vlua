// Tests for Lua integration
// Run with: v test .
// The FFI declarations below are duplicated from vlua/lua_bridge.v because C
// declarations are private to their module; the tests use them directly.
import os
import vlua

fn C.lua_gettop(L voidptr) int
fn C.lua_tonumber(L voidptr, idx int) f64
fn C.lua_pushnumber(L voidptr, n f64)
fn C.lua_tostring(L voidptr, idx int) &char
fn C.lua_pushstring(L voidptr, s &char)

// Resolve examples/demo.lua whether the tests run from the project root
// or from inside the demo/ directory.
fn demo_lua_path() string {
	mut p := 'examples/demo.lua'
	if !os.exists(p) {
		p = '../examples/demo.lua'
	}
	return p
}

// A Lua-callable V function (registered with vlua.register_function).
fn lua_cb_add(l voidptr) int {
	a := C.lua_tonumber(l, 1)
	b := C.lua_tonumber(l, 2)
	C.lua_pushnumber(l, a + b)
	return 1
}

fn lua_cb_greet(l voidptr) int {
	s := C.lua_tostring(l, 1)
	name := unsafe { cstring_to_vstring(*s) }
	C.lua_pushstring(l, ('Hello, ' + name + '!').str)
	return 1
}

// Tests
fn test_basic_execution() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'print("Hello from Lua!")') or {
		panic('Failed to execute Lua code: $err')
	}
}

fn test_global_variables() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'x = 42\nname = "Lua"\npi = 3.14159') or {
		panic('Failed to set globals: $err')
	}

	x := vlua.get_global_number(l, 'x')
	name := vlua.get_global_string(l, 'name')
	pi := vlua.get_global_number(l, 'pi')

	assert x == 42.0
	assert name == 'Lua'
	assert pi == 3.14159
}

fn test_write_globals() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.set_global(l, 'v_value', 'From V')
	vlua.set_global_number(l, 'v_num', 100)

	v_value := vlua.get_global_string(l, 'v_value')
	v_num := vlua.get_global_number(l, 'v_num')

	assert v_value == 'From V'
	assert v_num == 100.0
}

fn test_error_handling() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	if _ := vlua.safe_dostring(l, 'error("Test error")') {
		panic('Expected error but got success')
	} else {
		assert err.msg().contains('Test error')
	}
}

fn test_arithmetic() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'result = 2 + 3 * 4') or { panic('Failed to execute arithmetic: $err') }

	result := vlua.get_global_number(l, 'result')
	assert result == 14.0
}

fn test_stack_balanced_after_errors() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	assert C.lua_gettop(l) == 0

	for _ in 0 .. 10 {
		_ := vlua.safe_dostring(l, 'error("boom")') or { continue }
	}

	assert C.lua_gettop(l) == 0
}

fn test_missing_global() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	assert vlua.get_global_number(l, 'no_such_global') == 0.0
	assert vlua.get_global_string(l, 'no_such_global') == ''
	assert C.lua_gettop(l) == 0
}

fn test_syntax_error() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	if _ := vlua.safe_dostring(l, 'this is not valid lua !!!') {
		panic('Expected syntax error but got success')
	} else {
		assert err.msg().contains('syntax')
	}

	assert C.lua_gettop(l) == 0
}

fn test_external_file() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dofile(l, demo_lua_path()) or { panic('Failed to execute Lua file: $err') }

	assert vlua.get_global_string(l, 'script_name') == 'demo.lua'
	assert vlua.get_global_number(l, 'answer') == 42.0
	assert vlua.get_global_number(l, 'pi') == 3.14159

	vlua.safe_dostring(l, 'greet_result = greet("V")') or {
		panic('Failed to call Lua function: $err')
	}
	assert vlua.get_global_string(l, 'greet_result') == 'Hello, V!'
	assert C.lua_gettop(l) == 0
}

fn test_v_function_call() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.register_function(l, 'v_add', lua_cb_add)
	vlua.register_function(l, 'v_greet', lua_cb_greet)

	vlua.safe_dostring(l, 'sum = v_add(20, 22)') or { panic('Failed to call V function: $err') }
	assert vlua.get_global_number(l, 'sum') == 42.0

	vlua.safe_dostring(l, 'greeting = v_greet("V")') or { panic('Failed to call V function: $err') }
	assert vlua.get_global_string(l, 'greeting') == 'Hello, V!'
	assert C.lua_gettop(l) == 0
}

fn test_table_f64_roundtrip() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.set_table_f64(l, 't', {
		'a': 1.5
		'b': 2.5
	})
	m := vlua.get_table_f64(l, 't')
	assert m.len == 2
	assert m['a'] == 1.5
	assert m['b'] == 2.5
	assert C.lua_gettop(l) == 0
}

fn test_table_string_roundtrip() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.set_table_string(l, 't', {
		'k1': 'v1'
		'k2': 'v2'
	})
	m := vlua.get_table_string(l, 't')
	assert m.len == 2
	assert m['k1'] == 'v1'
	assert m['k2'] == 'v2'
	assert C.lua_gettop(l) == 0
}

fn test_read_lua_created_table() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'lt = { alpha = 1.5, beta = 2.5, seq = { 10, 20 } }') or {
		panic('Failed to create table in Lua: $err')
	}

	m := vlua.get_table_f64(l, 'lt')
	assert m['alpha'] == 1.5
	assert m['beta'] == 2.5

	v := vlua.get_global_value(l, 'lt') or { panic(err) }
	assert v.children['alpha'].num == 1.5
	seq := v.children['seq'].array
	assert seq.len == 2
	assert seq[0].num == 10.0
	assert seq[1].num == 20.0
	assert C.lua_gettop(l) == 0
}

fn test_array_roundtrip() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.set_array_f64(l, 'a', [1.0, 2.0, 3.0])
	assert vlua.get_array_f64(l, 'a') == [1.0, 2.0, 3.0]

	vlua.set_array_string(l, 'b', ['x', 'y'])
	assert vlua.get_array_string(l, 'b') == ['x', 'y']
	assert C.lua_gettop(l) == 0
}

fn test_general_value_roundtrip() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.set_global_value(l, 't', vlua.LuaValue{
		kind:     .table
		children: {
			'n': vlua.LuaValue{
				kind: .number
				num:  7.0
			}
			's': vlua.LuaValue{
				kind: .string
				str:  'hi'
			}
		}
		array:    [
			vlua.LuaValue{
				kind: .number
				num:  1.0
			},
			vlua.LuaValue{
				kind: .string
				str:  'two'
			},
		]
	})

	vlua.safe_dostring(l, 'rt = t.n + t[1]') or { panic('Failed to use table in Lua: $err') }
	assert vlua.get_global_number(l, 'rt') == 8.0

	v := vlua.get_global_value(l, 't') or { panic('Failed to read table: $err') }
	assert v.kind == .table
	assert v.children['n'].kind == .number
	assert v.children['n'].num == 7.0
	assert v.children['s'].str == 'hi'
	assert v.array.len == 2
	assert v.array[0].num == 1.0
	assert v.array[1].str == 'two'
	assert C.lua_gettop(l) == 0
}

fn test_missing_table_returns_empty() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	assert vlua.get_table_f64(l, 'no_such').len == 0
	assert vlua.get_table_string(l, 'no_such').len == 0
	assert vlua.get_array_f64(l, 'no_such').len == 0
	assert vlua.get_array_string(l, 'no_such').len == 0

	if _ := vlua.get_global_value(l, 'no_such') {
		panic('Expected error for missing global')
	} else {
		assert err.msg().contains('nil')
	}
	assert C.lua_gettop(l) == 0
}

fn test_call_function() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.register_function(l, 'v_fn', lua_cb_add)
	res := vlua.call_function(l, 'v_fn', [
		vlua.LuaValue{ kind: .number, num: 20.0 },
		vlua.LuaValue{ kind: .number, num: 22.0 },
	]) or { panic(err) }
	assert res.len == 1
	assert res[0].kind == .number
	assert res[0].num == 42.0

	vlua.safe_dostring(l, 'function pair(a, b) return a + b, a * b end') or {
		panic('Failed to define function: $err')
	}
	multi := vlua.call_function(l, 'pair', [
		vlua.LuaValue{ kind: .number, num: 3.0 },
		vlua.LuaValue{ kind: .number, num: 4.0 },
	]) or { panic(err) }
	assert multi.len == 2
	assert multi[0].num == 7.0
	assert multi[1].num == 12.0

	vlua.safe_dostring(l, 'function hi() return "hi" end') or {
		panic('Failed to define function: $err')
	}
	noargs := vlua.call_function(l, 'hi', []) or { panic(err) }
	assert noargs.len == 1
	assert noargs[0].str == 'hi'
	assert C.lua_gettop(l) == 0
}

fn test_call_function_errors() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'function boom() error("kaboom") end') or {
		panic('Failed to define function: $err')
	}
	if _ := vlua.call_function(l, 'boom', []) {
		panic('Expected error from boom')
	} else {
		assert err.msg().contains('kaboom')
	}

	vlua.set_global_number(l, 'not_a_func', 5.0)
	if _ := vlua.call_function(l, 'not_a_func', []) {
		panic('Expected error for non-function')
	}

	if _ := vlua.call_function(l, 'does_not_exist', []) {
		panic('Expected error for missing global')
	}
	assert C.lua_gettop(l) == 0
}

fn test_call_function_dotted() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	res := vlua.call_function(l, 'math.max', [
		vlua.LuaValue{ kind: .number, num: 3.0 },
		vlua.LuaValue{ kind: .number, num: 9.0 },
		vlua.LuaValue{ kind: .number, num: 5.0 },
	]) or { panic(err) }
	assert res.len == 1
	assert res[0].num == 9.0

	// dotted path resolving to a non-function (math.pi is a number)
	if _ := vlua.call_function(l, 'math.pi', []) {
		panic('Expected error for non-function dotted target')
	} else {
		assert err.msg().contains('not a function')
	}

	// deep missing path
	if _ := vlua.call_function(l, 'math.missing_fn', []) {
		panic('Expected error for missing dotted target')
	}
	assert C.lua_gettop(l) == 0
}

fn test_integer_roundtrip() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	// a value beyond 2^53 proves the integer path (f64 would lose precision)
	big := i64(9007199254740993)
	vlua.set_global_integer(l, 'big', big)
	assert vlua.get_global_integer(l, 'big') == big

	vlua.safe_dostring(l, 'big1 = big + 1') or { panic('Failed to run Lua: $err') }
	assert vlua.get_global_integer(l, 'big1') == big + 1

	vlua.safe_dostring(l, 'f = 3.5') or { panic('Failed to run Lua: $err') }
	assert vlua.get_global_integer(l, 'f') == 0
	assert C.lua_gettop(l) == 0
}

fn test_registry_ref() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	ref := vlua.ref_value(l, vlua.LuaValue{
		kind:     .table
		children: {
			'x': vlua.LuaValue{
				kind: .number
				num:  5.0
			}
		}
	}) or { panic(err) }

	v := vlua.get_ref(l, ref) or { panic(err) }
	assert v.kind == .table
	assert v.children['x'].num == 5.0

	vlua.unref_value(l, ref)

	// an unused registry slot errors on fetch
	if _ := vlua.get_ref(l, 999999) {
		panic('Expected error for invalid reference')
	} else {
		assert err.msg().contains('no such reference')
	}
	assert C.lua_gettop(l) == 0
}

fn test_call_referenced_function() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l, 'function cube(x) return x * x * x end') or {
		panic('Failed to define function: $err')
	}
	ref := vlua.ref_global(l, 'cube') or { panic(err) }

	res := vlua.call_ref(l, ref, [vlua.LuaValue{ kind: .number, num: 3.0 }]) or { panic(err) }
	assert res.len == 1
	assert res[0].num == 27.0

	// ref a dotted function and call it
	max_ref := vlua.ref_global(l, 'math.max') or { panic(err) }
	maxes := vlua.call_ref(l, max_ref, [
		vlua.LuaValue{ kind: .number, num: 1.0 },
		vlua.LuaValue{ kind: .number, num: 7.0 },
	]) or { panic(err) }
	assert maxes[0].num == 7.0

	// calling a non-function reference errors
	vlua.set_global_number(l, 'some_num', 42.0)
	num_ref := vlua.ref_global(l, 'some_num') or { panic(err) }
	if _ := vlua.call_ref(l, num_ref, []) {
		panic('expected error for function call on number ref')
	} else {
		assert err.msg().contains('not a function')
	}
	vlua.unref_value(l, ref)
	vlua.unref_value(l, max_ref)
	vlua.unref_value(l, num_ref)
	assert C.lua_gettop(l) == 0
}

fn test_pass_array_get_table() {
	l := vlua.new_state() or { panic('Failed to create Lua state') }
	defer {
		vlua.close_state(l)
	}

	vlua.safe_dostring(l,
		'function stats(data) local s = 0 for _, v in ipairs(data) do s = s + v end return { sum = s, count = #data } end') or {
		panic('Failed to define function: $err')
	}

	nums := [3.0, 1.0, 4.0]
	mut num_vals := []vlua.LuaValue{}
	for n in nums {
		num_vals << vlua.LuaValue{
			kind: .number
			num:  n
		}
	}

	res := vlua.call_function(l, 'stats', [
		vlua.LuaValue{
			kind:  .table
			array: num_vals
		},
	]) or { panic(err) }
	assert res.len == 1
	tbl := res[0]
	assert tbl.kind == .table
	assert tbl.children['sum'].num == 8.0
	assert tbl.children['count'].num == 3.0
	assert C.lua_gettop(l) == 0
}
