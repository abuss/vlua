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
