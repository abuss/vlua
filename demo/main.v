import os
import vlua

// FFI declarations used by the V functions exposed to Lua (see Demo 5).
// C declarations are private to their module, so the demo declares its own.
fn C.lua_tonumber(L voidptr, idx int) f64
fn C.lua_tostring(L voidptr, idx int) &char
fn C.lua_pushnumber(L voidptr, n f64)
fn C.lua_pushstring(L voidptr, s &char)

// Resolve examples/demo.lua whether the demo is run from the project root
// or from inside the demo/ directory.
fn demo_lua_path() string {
	mut p := 'examples/demo.lua'
	if !os.exists(p) {
		p = '../examples/demo.lua'
	}
	return p
}

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
	l := vlua.new_state() or {
		eprintln('Failed to create Lua state')
		return
	}
	defer {
		vlua.close_state(l)
	}

	// Demo 1: Basic execution
	println('--- Demo 1: Basic Execution ---')
	vlua.safe_dostring(l, 'print("Hello from Lua!")') or {
		eprintln('Error: $err')
		return
	}

	// Demo 2: Reading/writing globals
	println('\n--- Demo 2: Global Variables ---')
	vlua.safe_dostring(l, 'x = 42\nname = "Lua"\npi = 3.14159') or {
		eprintln('Error: $err')
		return
	}

	x := vlua.get_global_number(l, 'x')
	name := vlua.get_global_string(l, 'name')
	pi := vlua.get_global_number(l, 'pi')

	println('x = ${x}')
	println('name = "${name}"')
	println('pi = ${pi}')

	// Write variables to Lua
	vlua.set_global(l, 'v_value', 'From V')
	vlua.set_global_number(l, 'v_num', 100)

	// Verify by reading them back
	v_value := vlua.get_global_string(l, 'v_value')
	v_num := vlua.get_global_number(l, 'v_num')

	println('\nWritten from V:')
	println('v_value = "${v_value}"')
	println('v_num = ${v_num}')

	// Demo 3: Error handling
	println('\n--- Demo 3: Error Handling ---')
	if _ := vlua.safe_dostring(l, 'error("This is a test error")') {
		println('No error')
	} else {
		println('Error caught: ${err}')
	}

	// Demo 4: Execute an external .lua file
	println('\n--- Demo 4: External Lua File ---')
	vlua.safe_dofile(l, demo_lua_path()) or {
		eprintln('Error: $err')
		return
	}

	file_name := vlua.get_global_string(l, 'script_name')
	file_answer := vlua.get_global_number(l, 'answer')
	file_pi := vlua.get_global_number(l, 'pi')

	println('script_name = "${file_name}"')
	println('answer = ${file_answer}')
	println('pi = ${file_pi}')

	// Call a Lua function defined in the file.
	vlua.safe_dostring(l, 'greet_result = greet("V")') or {
		eprintln('Error: $err')
		return
	}
	greet_result := vlua.get_global_string(l, 'greet_result')
	println('greet("V") = "${greet_result}"')

	// Demo 5: Calling V functions from Lua
	println('\n--- Demo 5: Calling V Functions from Lua ---')
	vlua.register_function(l, 'v_add', lua_add)
	vlua.register_function(l, 'v_greet', lua_greet)

	vlua.safe_dostring(l, 'sum = v_add(20, 22); print("v_add(20, 22) = " .. sum)') or {
		eprintln('Error: $err')
		return
	}
	sum := vlua.get_global_number(l, 'sum')

	vlua.safe_dostring(l, 'greeting = v_greet("V"); print(greeting)') or {
		eprintln('Error: $err')
		return
	}
	greeting := vlua.get_global_string(l, 'greeting')

	println('sum = ${sum}')
	println('greeting = "${greeting}"')

	// Demo 6: Lua tables
	println('\n--- Demo 6: Lua Tables ---')

	// Write a numeric table from V and read it back.
	v_cfg := {
		'max':  100.0
		'step': 0.5
	}
	vlua.set_table_f64(l, 'v_cfg', v_cfg)
	read_cfg := vlua.get_table_f64(l, 'v_cfg')
	println('v_cfg.max = ${read_cfg['max']}, v_cfg.step = ${read_cfg['step']}')

	// Write a string array from V and read it back.
	vlua.set_array_string(l, 'v_names', ['a', 'b', 'c'])
	names := vlua.get_array_string(l, 'v_names')
	println('v_names = ${names}')

	// Read a heterogeneous, nested table from examples/demo.lua.
	vlua.safe_dofile(l, demo_lua_path()) or {
		eprintln('Error: $err')
		return
	}
	cfg := vlua.get_global_value(l, 'config') or {
		eprintln('Error: $err')
		return
	}
	println('config.name = "${cfg.children['name'].str}"')
	println('config.version = ${cfg.children['version'].num}')
	mut feature_names := []string{}
	for f in cfg.children['features'].array {
		feature_names << f.str
	}
	mut tag_values := []f64{}
	for t in cfg.children['tags'].array {
		tag_values << t.num
	}
	println('config.features = ${feature_names}')
	println('config.tags = ${tag_values}')

	// Demo 7: Calling Lua functions from V
	println('\n--- Demo 7: Calling Lua Functions from V ---')

	// greet() was loaded from examples/demo.lua in Demo 6.
	greets := vlua.call_function(l, 'greet', [
		vlua.LuaValue{
			kind: .string
			str:  'world'
		},
	]) or {
		eprintln('Error: $err')
		return
	}
	println('greet("world") = "${greets[0].str}"')

	// A Lua function using the math library.
	vlua.safe_dostring(l, 'function max3(a, b, c) return math.max(a, b, c) end') or {
		eprintln('Error: $err')
		return
	}
	maxes := vlua.call_function(l, 'max3', [
		vlua.LuaValue{ kind: .number, num: 3.0 },
		vlua.LuaValue{ kind: .number, num: 9.0 },
		vlua.LuaValue{ kind: .number, num: 5.0 },
	]) or {
		eprintln('Error: $err')
		return
	}
	println('max3(3, 9, 5) = ${maxes[0].num}')

	adds := vlua.call_function(l, 'v_add', [
		vlua.LuaValue{ kind: .number, num: 20.0 },
		vlua.LuaValue{ kind: .number, num: 22.0 },
	]) or {
		eprintln('Error: $err')
		return
	}
	println('v_add(20, 22) = ${adds[0].num}')

	// Demo 8: Pass a V array to a Lua function, get a Lua table back
	println('\n--- Demo 8: V Array to Lua, Lua Table Back ---')

	nums := [3.0, 1.0, 4.0, 1.0, 5.0, 9.0]
	mut num_vals := []vlua.LuaValue{}
	for n in nums {
		num_vals << vlua.LuaValue{
			kind: .number
			num:  n
		}
	}

	stats := vlua.call_function(l, 'analyze', [
		vlua.LuaValue{
			kind:  .table
			array: num_vals
		},
	]) or {
		eprintln('Error: $err')
		return
	}
	stats_tbl := stats[0]
	println('analyze([${nums}]) =')
	println('  sum   = ${stats_tbl.children['sum'].num}')
	println('  count = ${stats_tbl.children['count'].num}')
	println('  min   = ${stats_tbl.children['min'].num}')
	println('  max   = ${stats_tbl.children['max'].num}')

	println('\n=== All demos completed successfully! ===')
}
