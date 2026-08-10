--!strict

-- TODO: upload coverage to codecov.io

local process = require("@lune/process")

process.create("lest", { "--coverage" })
