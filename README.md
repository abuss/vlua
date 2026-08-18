# vlua

Embed the [Lua 5.4](https://www.lua.org/) scripting language inside [V](https://vlang.io) via C FFI.

## Overview

`vlua` is a minimal FFI wrapper that lets V programs create a Lua state, execute Lua
snippets, and read/write Lua globals from V. It uses raw C calls with no external
dependencies beyond a Lua 5.4 installation.

## Files

| File              | Purpose                                                        |
| ----------------- | -------------------------------------------------------------- |
| `lua_bridge.v`    | FFI declarations for the Lua C API (linking, C functions).     |
| `lua_util.v`      | High-level helpers: state lifecycle, safe execution, globals.  |
| `main.v`          | Executable demo showing the usage patterns.                    |
| `main_test.v`     | Test suite; run with `v test .`.                             |
| `examples/demo.lua` | Sample external Lua script loaded by the demo and tests. |

## Requirements

- [V](https://vlang.io) 0.5.x
- Lua 5.4 headers and library (`liblua5.4` on Linux/macOS, `lua54` on Windows).

## Usage

```v
l := new_state() or { panic('failed to create Lua state') }
defer { close_state(l) }

safe_dostring(l, 'print("Hello from Lua!")') or {
    eprintln('error: $err')
}

set_global(l, 'name', 'world')
println(get_global_string(l, 'name'))

// Execute an external Lua file
safe_dofile(l, 'examples/demo.lua') or {
    eprintln('error: $err')
}
println(get_global_number(l, 'answer')) // 42.0
```

### Calling V functions from Lua

```v
// a Lua-callable V function: reads args from the Lua stack, returns # of results
fn lua_add(l voidptr) int {
    a := C.lua_tonumber(l, 1)
    b := C.lua_tonumber(l, 2)
    C.lua_pushnumber(l, a + b)
    return 1
}

register_function(l, 'v_add', lua_add)
safe_dostring(l, 'print(v_add(20, 22))') // prints 42.0
```

### Working with Lua tables

Typed helpers for homogeneous tables and arrays (string keys / integer keys `1..#t`):

```v
set_table_f64(l, 'cfg', {'max': 100.0, 'step': 0.5})
m := get_table_f64(l, 'cfg') // map[string]f64

set_array_string(l, 'names', ['a', 'b', 'c'])
names := get_array_string(l, 'names') // []string
```

For heterogeneous / nested tables, use the general value type `LuaValue`
(`num`, `str`, `b`, `children map[string]LuaValue`, `array []LuaValue`):

```v
v := get_global_value(l, 'config') or { panic(err) }
println(v.children['name'].str) // "vlua"
println(v.children['tags'].array[0].num) // 10.0

set_global_value(l, 't', LuaValue{
    kind:     .table
    children: {'n': LuaValue{kind: .number, num: 7.0}}
    array:    [LuaValue{kind: .string, str: 'hi'}]
})
```

Notes: string keys map to `children`; integer keys `1..#t` map to `array`;
trailing `nil` array slots are not materialized; `get_global_value` errors on a
missing/nil global, while the typed helpers return empty containers.

## Build & Test

```sh
v run .          # run the demo
v build .        # build without running
v test .         # run the test suite
```

## Security note

`safe_dostring` executes arbitrary Lua code. `new_state()` loads the full Lua standard
library (`luaL_openlibs`), so executed code can run shell commands (`os.execute`), read
and write arbitrary files (`io`), and load native modules (`package.loadlib`).

Only pass **trusted, developer-authored** Lua code to `safe_dostring`. Do not feed it
untrusted input (user input, files, network data) unless you restrict the opened
libraries or run the code in a sandboxed process. There are currently no CPU-time or
memory limits, so untrusted code could also hang or exhaust memory.