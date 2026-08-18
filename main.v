// V functions exposed to Lua (see Demo 5).
// Each reads its arguments from the Lua stack by index and returns the number
// of results it pushed back onto the stack.
fn lua_add(l voidptr) int {
	a := C.lua_tonumber(l, 1)
	b := C.lua_tonumber(l, 2)
	C.lua_pushnumber(l, a + b)
	return 1
}

fn lua_greet(l voidptr) int {
	s := C.lua_tostring(l, 1)
	name := unsafe { cstring_to_vstring(*s) }
	C.lua_pushstring(l, ('Hello, ' + name + '!').str)
	return 1
}

fn main() {
	println('=== vlua: Embedding Lua in V ===\n')

	// Create a new Lua state
	l := new_state() or {
		eprintln('Failed to create Lua state')
		return
	}
	defer {
		close_state(l)
	}

	// Demo 1: Basic execution
	println('--- Demo 1: Basic Execution ---')
	safe_dostring(l, 'print("Hello from Lua!")') or {
		eprintln('Error: $err')
		return
	}

	// Demo 2: Reading/writing globals
	println('\n--- Demo 2: Global Variables ---')
	safe_dostring(l, 'x = 42\nname = "Lua"\npi = 3.14159') or {
		eprintln('Error: $err')
		return
	}

	x := get_global_number(l, 'x')
	name := get_global_string(l, 'name')
	pi := get_global_number(l, 'pi')

	println('x = ${x}')
	println('name = "${name}"')
	println('pi = ${pi}')

	// Write variables to Lua
	set_global(l, 'v_value', 'From V')
	set_global_number(l, 'v_num', 100)

	// Verify by reading them back
	v_value := get_global_string(l, 'v_value')
	v_num := get_global_number(l, 'v_num')

	println('\nWritten from V:')
	println('v_value = "${v_value}"')
	println('v_num = ${v_num}')

	// Demo 3: Error handling
	println('\n--- Demo 3: Error Handling ---')
	if _ := safe_dostring(l, 'error("This is a test error")') {
		println('No error')
	} else {
		println('Error caught: ${err}')
	}

	// Demo 4: Execute an external .lua file
	println('\n--- Demo 4: External Lua File ---')
	safe_dofile(l, 'examples/demo.lua') or {
		eprintln('Error: $err')
		return
	}

	file_name := get_global_string(l, 'script_name')
	file_answer := get_global_number(l, 'answer')
	file_pi := get_global_number(l, 'pi')

	println('script_name = "${file_name}"')
	println('answer = ${file_answer}')
	println('pi = ${file_pi}')

	// Call a Lua function defined in the file.
	safe_dostring(l, 'greet_result = greet("V")') or {
		eprintln('Error: $err')
		return
	}
	greet_result := get_global_string(l, 'greet_result')
	println('greet("V") = "${greet_result}"')

	// Demo 5: Calling V functions from Lua
	println('\n--- Demo 5: Calling V Functions from Lua ---')
	register_function(l, 'v_add', lua_add)
	register_function(l, 'v_greet', lua_greet)

	safe_dostring(l, 'sum = v_add(20, 22); print("v_add(20, 22) = " .. sum)') or {
		eprintln('Error: $err')
		return
	}
	sum := get_global_number(l, 'sum')

	safe_dostring(l, 'greeting = v_greet("V"); print(greeting)') or {
		eprintln('Error: $err')
		return
	}
	greeting := get_global_string(l, 'greeting')

	println('sum = ${sum}')
	println('greeting = "${greeting}"')

	println('\n=== All demos completed successfully! ===')
}
