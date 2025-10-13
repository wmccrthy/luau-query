local parser = require("@std/syntax/parser")
local q = require("../src")
local common = q.astUtils
local query = q.query

local src = [[
local x = 1
local y = 2
local z = 3
]]
local ast = parser.parse(src)
local myVars = query(ast, "LocalDeclaration")
myVars:forEach(function(path)
	path:insertBefore(function(p)
		local varName = p:getDescendantAt("variables", 1, "node"):name()
		return parser.parse(`print("Initializing {varName}!")\n`)
	end)
end)

print(common.getStatementText(ast))
