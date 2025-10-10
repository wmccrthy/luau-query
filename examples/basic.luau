local parser = require("@std/syntax/parser")
local q = require("../src")
local query, astUtils = q.query, q.astUtils

local src = [[
    local x = 1
    local y = 2
]]

-- Basic example: swap variable names of x and y
-- Here, we use the exact structure of the tree
local ast = parser.parse(src)
query(ast, "LocalDeclaration", function(path)
	local varPath = path:getDescendantAt("variables", 1, "node", "name").node
	varPath.text = if varPath.text == "x" then "y" else "x"
end)

print(astUtils.getStatementText(ast))
