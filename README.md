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
| `main.v`          | Executable demo showing the three usage patterns.              |
| `main_test.v`     | Test suite; run with `v test .`.                               |

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
```

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