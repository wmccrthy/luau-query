local parser = require("@std/syntax/parser")
local q = require("../src")
local query = q.query
local matchers = q.matchers
local has = matchers.has
local astUtils = q.astUtils

local src = [[
    local x = 1
    local y = 2
]]

-- Basic example: swap variable names of x and y
local ast = parser.parse(src)
query(ast, "LocalDeclaration", function(path)
	local varPath = path:findFirstDescendant(matchers.any(has.property("text", "x"), has.property("text", "y"))).node
	varPath.text = if varPath.text == "x" then "y" else "x"
end)

print(astUtils.getStatementText(ast))
