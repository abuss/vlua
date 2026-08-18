-- example/demo.lua
-- External Lua script executed by vlua (see Demo 4 in main.v).

print("Hello from an external Lua file!")

-- Set globals that V can read back after running this file.
script_name = "demo.lua"
answer = 42
pi = 3.14159

-- Define a function so the file also serves as a reusable module.
function greet(who)
	return "Hello, " .. who .. "!"
end