// Tests for Lua integration
// Run with: v test .

module main

// Uses pub fns + FFI declarations from lua_util.v / lua_bridge.v

// Tests
fn test_basic_execution() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l, 'print("Hello from Lua!")') or { panic('Failed to execute Lua code: $err') }
}

fn test_global_variables() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l, 'x = 42\nname = "Lua"\npi = 3.14159') or {
		panic('Failed to set globals: $err')
	}

	x := get_global_number(l, 'x')
	name := get_global_string(l, 'name')
	pi := get_global_number(l, 'pi')

	assert x == 42.0
	assert name == 'Lua'
	assert pi == 3.14159
}

fn test_write_globals() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	set_global(l, 'v_value', 'From V')
	set_global_number(l, 'v_num', 100)

	v_value := get_global_string(l, 'v_value')
	v_num := get_global_number(l, 'v_num')

	assert v_value == 'From V'
	assert v_num == 100.0
}

fn test_error_handling() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	if _ := safe_dostring(l, 'error("Test error")') {
		panic('Expected error but got success')
	} else {
		assert err.msg().contains('Test error')
	}
}

fn test_arithmetic() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l, 'result = 2 + 3 * 4') or { panic('Failed to execute arithmetic: $err') }

	result := get_global_number(l, 'result')
	assert result == 14.0
}

fn test_stack_balanced_after_errors() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	assert C.lua_gettop(l) == 0

	for _ in 0 .. 10 {
		_ := safe_dostring(l, 'error("boom")') or { continue }
	}

	assert C.lua_gettop(l) == 0
}

fn test_missing_global() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	assert get_global_number(l, 'no_such_global') == 0.0
	assert get_global_string(l, 'no_such_global') == ''
	assert C.lua_gettop(l) == 0
}

fn test_syntax_error() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	if _ := safe_dostring(l, 'this is not valid lua !!!') {
		panic('Expected syntax error but got success')
	} else {
		assert err.msg().contains('syntax')
	}

	assert C.lua_gettop(l) == 0
}

fn test_external_file() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dofile(l, 'examples/demo.lua') or { panic('Failed to execute Lua file: $err') }

	assert get_global_string(l, 'script_name') == 'demo.lua'
	assert get_global_number(l, 'answer') == 42.0
	assert get_global_number(l, 'pi') == 3.14159

	safe_dostring(l, 'greet_result = greet("V")') or { panic('Failed to call Lua function: $err') }
	assert get_global_string(l, 'greet_result') == 'Hello, V!'
	assert C.lua_gettop(l) == 0
}

fn test_v_function_call() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	register_function(l, 'v_add', lua_add)
	register_function(l, 'v_greet', lua_greet)

	safe_dostring(l, 'sum = v_add(20, 22)') or { panic('Failed to call V function: $err') }
	assert get_global_number(l, 'sum') == 42.0

	safe_dostring(l, 'greeting = v_greet("V")') or { panic('Failed to call V function: $err') }
	assert get_global_string(l, 'greeting') == 'Hello, V!'
	assert C.lua_gettop(l) == 0
}

fn test_table_f64_roundtrip() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	set_table_f64(l, 't', {
		'a': 1.5
		'b': 2.5
	})
	m := get_table_f64(l, 't')
	assert m.len == 2
	assert m['a'] == 1.5
	assert m['b'] == 2.5
	assert C.lua_gettop(l) == 0
}

fn test_table_string_roundtrip() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	set_table_string(l, 't', {
		'k1': 'v1'
		'k2': 'v2'
	})
	m := get_table_string(l, 't')
	assert m.len == 2
	assert m['k1'] == 'v1'
	assert m['k2'] == 'v2'
	assert C.lua_gettop(l) == 0
}

fn test_read_lua_created_table() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l, 'lt = { alpha = 1.5, beta = 2.5, seq = { 10, 20 } }') or {
		panic('Failed to create table in Lua: $err')
	}

	m := get_table_f64(l, 'lt')
	assert m['alpha'] == 1.5
	assert m['beta'] == 2.5

	v := get_global_value(l, 'lt') or { panic(err) }
	assert v.children['alpha'].num == 1.5
	seq := v.children['seq'].array
	assert seq.len == 2
	assert seq[0].num == 10.0
	assert seq[1].num == 20.0
	assert C.lua_gettop(l) == 0
}

fn test_array_roundtrip() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	set_array_f64(l, 'a', [1.0, 2.0, 3.0])
	assert get_array_f64(l, 'a') == [1.0, 2.0, 3.0]

	set_array_string(l, 'b', ['x', 'y'])
	assert get_array_string(l, 'b') == ['x', 'y']
	assert C.lua_gettop(l) == 0
}

fn test_general_value_roundtrip() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	set_global_value(l, 't', LuaValue{
		kind:     .table
		children: {
			'n': LuaValue{
				kind: .number
				num:  7.0
			}
			's': LuaValue{
				kind: .string
				str:  'hi'
			}
		}
		array:    [
			LuaValue{
				kind: .number
				num:  1.0
			},
			LuaValue{
				kind: .string
				str:  'two'
			},
		]
	})

	safe_dostring(l, 'rt = t.n + t[1]') or { panic('Failed to use table in Lua: $err') }
	assert get_global_number(l, 'rt') == 8.0

	v := get_global_value(l, 't') or { panic('Failed to read table: $err') }
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
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	assert get_table_f64(l, 'no_such').len == 0
	assert get_table_string(l, 'no_such').len == 0
	assert get_array_f64(l, 'no_such').len == 0
	assert get_array_string(l, 'no_such').len == 0

	if _ := get_global_value(l, 'no_such') {
		panic('Expected error for missing global')
	} else {
		assert err.msg().contains('nil')
	}
	assert C.lua_gettop(l) == 0
}

fn test_call_function() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	register_function(l, 'v_add', lua_add)
	res := call_function(l, 'v_add', [
		LuaValue{ kind: .number, num: 20.0 },
		LuaValue{ kind: .number, num: 22.0 },
	]) or { panic(err) }
	assert res.len == 1
	assert res[0].kind == .number
	assert res[0].num == 42.0

	safe_dostring(l, 'function pair(a, b) return a + b, a * b end') or {
		panic('Failed to define function: $err')
	}
	multi := call_function(l, 'pair', [
		LuaValue{ kind: .number, num: 3.0 },
		LuaValue{ kind: .number, num: 4.0 },
	]) or { panic(err) }
	assert multi.len == 2
	assert multi[0].num == 7.0
	assert multi[1].num == 12.0

	safe_dostring(l, 'function hi() return "hi" end') or {
		panic('Failed to define function: $err')
	}
	noargs := call_function(l, 'hi', []) or { panic(err) }
	assert noargs.len == 1
	assert noargs[0].str == 'hi'
	assert C.lua_gettop(l) == 0
}

fn test_call_function_errors() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l, 'function boom() error("kaboom") end') or {
		panic('Failed to define function: $err')
	}
	if _ := call_function(l, 'boom', []) {
		panic('Expected error from boom')
	} else {
		assert err.msg().contains('kaboom')
	}

	set_global_number(l, 'not_a_func', 5.0)
	if _ := call_function(l, 'not_a_func', []) {
		panic('Expected error for non-function')
	}

	if _ := call_function(l, 'does_not_exist', []) {
		panic('Expected error for missing global')
	}
	assert C.lua_gettop(l) == 0
}

fn test_pass_array_get_table() {
	l := new_state() or { panic('Failed to create Lua state') }
	defer {
		close_state(l)
	}

	safe_dostring(l,
		'function stats(data) local s = 0 for _, v in ipairs(data) do s = s + v end return { sum = s, count = #data } end') or {
		panic('Failed to define function: $err')
	}

	nums := [3.0, 1.0, 4.0]
	mut num_vals := []LuaValue{}
	for n in nums {
		num_vals << LuaValue{
			kind: .number
			num:  n
		}
	}

	res := call_function(l, 'stats', [LuaValue{ kind: .table, array: num_vals }]) or { panic(err) }
	assert res.len == 1
	tbl := res[0]
	assert tbl.kind == .table
	assert tbl.children['sum'].num == 8.0
	assert tbl.children['count'].num == 3.0
	assert C.lua_gettop(l) == 0
}
