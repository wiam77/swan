--!strict

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local TARGETS = {"luau", "lune", "roblox"}
local INCLUDES = {"src", "COPYING", "PESDE_README.md", "docs"}

local base_manifest = fs.readFile("base_pesde.toml")

if fs.isDir("build") then
	fs.removeDir("build")
end

fs.writeDir("build")

for _, target in TARGETS do
	local out_dir = "build/"..target
	fs.writeDir(out_dir)

	for _, include in INCLUDES do
		fs.copy(include, out_dir.."/"..if include == "PESDE_README.md" then "README.md" else include)
	end

	fs.writeFile(out_dir.."/pesde.toml", base_manifest.."\n"..serde.encode("toml", {target = {
		environment = target,
		lib = "src/init.luau",
		build_files = target == "roblox" and {"src"}
	}}, true))
end
