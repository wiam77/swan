--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TARGETS = {"luau", "lune", "roblox"}
local INCLUDES = {"src", "LICENSE", "README.md", "docs"}

local BASE_MANIFEST = fs.readFile("base_pesde.toml")

if fs.isDir("build") then
	fs.removeDir("build")
end

fs.writeDir("build")

for _, target in TARGETS do
	local out_dir = "build/"..target
	fs.writeDir(out_dir)

	for _, include in INCLUDES do
		fs.copy(include, out_dir.."/"..include)
	end

	fs.writeFile(out_dir.."/pesde.toml", BASE_MANIFEST.."\n\n"..serde.encode("toml", {target = {
		environment = target,
		lib = "src/init.luau",
		build_files = target == "roblox" and {"src"} or nil
	}}, true))
end
