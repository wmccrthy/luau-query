local parser = require("@std/syntax/parser")
local q = require("../src")
local common = q.astUtils
local query = q.query

local src = [[
    local condition

    assert(condition)
]]
local ast = parser.parse(src)
-- lets replace the assert with an "if condition then error..." statement 

local assertCalls = query.byCallStatement(ast)
assertCalls:forEach(function(path)
	path:replace(function(p)
		return parser.parse([[
    if condition then
        error("bad condition is true!")
    end
    ]])
	end)
end)

print(common.getStatementText(ast))
