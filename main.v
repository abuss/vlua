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

	println('\n=== All demos completed successfully! ===')
}
