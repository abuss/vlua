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

-- A heterogeneous, nested table read by Demo 6 via get_global_value.
config = {
	name = "vlua",
	version = 6.2,
	features = { "auto", "lua" },
	tags = { 10, 20, 30 },
}

-- Receives a V array (Demo 8) and returns a Lua table of statistics.
function analyze(data)
	local sum, mn, mx = 0, math.huge, -math.huge
	for _, v in ipairs(data) do
		sum = sum + v
		if v < mn then mn = v end
		if v > mx then mx = v end
	end
	return { sum = sum, count = #data, min = mn, max = mx }
end