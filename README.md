# vlua

Embed the [Lua 5.4](https://www.lua.org/) scripting language inside [V](https://vlang.io) via C FFI.

`vlua` is a minimal, importable module that lets V programs create a Lua state, execute
Lua snippets, read/write Lua globals and tables, register V functions callable from Lua,
and call Lua functions with V arguments. It uses raw C calls with no external
dependencies beyond a Lua 5.4 installation.

## Layout

| Path                 | Purpose                                                              |
| -------------------- | -------------------------------------------------------------------- |
| `vlua/`              | The importable module (`import vlua`) — `vlua/lua_bridge.v` (FFI declarations) and `vlua/lua_util.v` (API). |
| `demo/`              | Runnable demo + test suite (`module main`, imports `vlua`).          |
| `demo/main.v`        | Executable demo (8 usage patterns).                                  |
| `demo/main_test.v`   | Test suite.                                                          |
| `examples/demo.lua`  | Sample external Lua script loaded by the demo and tests.             |
| `v.mod`              | Project manifest (import anchor).                                    |

## Requirements

- [V](https://vlang.io) 0.5.x
- Lua 5.4 headers and library (`liblua5.4` on Linux/macOS).

## Usage

```v
import vlua

l := vlua.new_state() or { panic('failed to create Lua state') }
defer { vlua.close_state(l) }

vlua.safe_dostring(l, 'print("Hello from Lua!")') or {
    eprintln('error: $err')
}

vlua.set_global(l, 'name', 'world')
println(vlua.get_global_string(l, 'name'))

// Execute an external Lua file
vlua.safe_dofile(l, 'examples/demo.lua') or {
    eprintln('error: $err')
}
println(vlua.get_global_number(l, 'answer')) // 42.0
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

vlua.register_function(l, 'v_add', lua_add)
vlua.safe_dostring(l, 'print(v_add(20, 22))') // prints 42.0
```

### Working with Lua tables

Typed helpers for homogeneous tables and arrays (string keys / integer keys `1..#t`):

```v
vlua.set_table_f64(l, 'cfg', {'max': 100.0, 'step': 0.5})
m := vlua.get_table_f64(l, 'cfg') // map[string]f64

vlua.set_array_string(l, 'names', ['a', 'b', 'c'])
names := vlua.get_array_string(l, 'names') // []string
```

For heterogeneous / nested tables, use the general value type `LuaValue`
(`kind` one of `.integer`/`.number`/`.string`/`.boolean`/`.table`, plus `i`,
`num`, `str`, `b`, `children map[string]LuaValue`, `array []LuaValue`):

```v
v := vlua.get_global_value(l, 'config') or { panic(err) }
println(v.children['name'].str) // "vlua"
println(v.children['tags'].array[0].i) // 10 (Lua integers keep full precision)
```

Integer and float Lua values are preserved separately: Lua integers map to
`.integer` (`i i64`), floats to `.number` (`num f64`) — so values beyond 2^53
round-trip losslessly inside tables too.

Notes: string keys map to `children`; integer keys `1..#t` map to `array`;
trailing `nil` array slots are not materialized; `get_global_value` errors on a
missing/nil global, while the typed helpers return empty containers.

### Calling Lua functions from V

```v
greets := vlua.call_function(l, 'greet', [vlua.LuaValue{kind: .string, str: 'world'}]) or {
    eprintln('error: $err')
}
println(greets[0].str) // "Hello, world!"

// multiple return values are preserved in order
res := vlua.call_function(l, 'pair', [
    vlua.LuaValue{kind: .number, num: 3.0},
    vlua.LuaValue{kind: .number, num: 4.0},
]) or { panic(err) } // res[0] == 7.0, res[1] == 12.0
```

`call_function` takes a global name or dotted path (e.g. `math.max`) and a
`[]LuaValue` of arguments, and returns the values in order. It errors if the
target is not a function or the call raises an error.

### Integers

Lua values that are integers (not floats) round-trip losslessly, even beyond
2^53 where `f64` would lose precision:

```v
vlua.set_global_integer(l, 'big', i64(9007199254740993))
vlua.safe_dostring(l, 'big1 = big + 1') or { panic(err) }
vlua.get_global_integer(l, 'big1') == i64(9007199254740994)
```

`get_global_integer` returns 0 when the value is not an integer-valued number.

### Holding Lua values with registry references

`ref_value`/`ref_global` store a value (including functions and tables) in the
Lua registry and return an integer handle — no global name needed:

```v
ref := vlua.ref_global(l, 'math.max') or { panic(err) }
res := vlua.call_ref(l, ref, [vlua.LuaValue{kind: .number, num: 1.0}, ...]) or { panic(err) }
vlua.unref_value(l, ref) // release the handle
```

```v
tbl_ref := vlua.ref_value(l, vlua.LuaValue{kind: .table, ...}) or { panic(err) }
v := vlua.get_ref(l, tbl_ref) or { panic(err) }
```

- `ref_value(l, v)` — store any `LuaValue`, return the handle.
- `ref_global(l, name)` — store a global / dotted-path value, return the handle.
- `get_ref(l, ref)` — fetch a stored value back.
- `call_ref(l, ref, args)` — call a stored function.
- `unref_value(l, ref)` — release the handle.

### Compile without running & raising errors from V

Compile Lua source (an anonymous function) without executing it, then run it
later through `call_ref`:

```v
ref := vlua.load_string(l, 'return 1 + 2') or { panic(err) }
res := vlua.call_ref(l, ref, []) or { panic(err) }
println(res[0].i) // 3 (integer)
vlua.unref_value(l, ref)
```

A V function registered with `register_function` can raise a Lua error (caught
by `pcall` or by `call_function`) with `vlua.raise_lua_error`:

```v
fn boom(l voidptr) int {
    _ = vlua.raise_lua_error(l, 'boom from V')
    return 0
}
```

## Build & Test

The V compiler version is pinned in `.vvmrc` (`0.5.2`).

```sh
v run demo/     # run the demo (from anywhere in the project)
v test demo/    # run the test suite
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs the test suite on every push
and on manual dispatch (`workflow_dispatch`) across Ubuntu and macOS: each leg
installs Lua 5.4, downloads the pinned V release toolchain (cached per version),
and runs `v test demo/`. The Ubuntu leg is the reference configuration.

## Security note

`safe_dostring` executes arbitrary Lua code. `new_state()` loads the full Lua standard
library (`luaL_openlibs`), so executed code can run shell commands (`os.execute`), read
and write arbitrary files (`io`), and load native modules (`package.loadlib`).

Only pass **trusted, developer-authored** Lua code to `safe_dostring`. Do not feed it
untrusted input (user input, files, network data) unless you restrict the opened
libraries or run the code in a sandboxed process. There are currently no CPU-time or
memory limits, so untrusted code could also hang or exhaust memory.