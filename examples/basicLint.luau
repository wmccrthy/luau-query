local parser = require("@std/syntax/parser")
local q = require("../src")
local query = q.query
local matchers = q.matchers
local is = matchers.is

local src = [[
    local x, y = 1, 2
    React.useEffect(function()
        arbitraryCallback(x, y)
    end, {})
]]

-- Lint for missing dependencies
local ast = parser.parse(src)
local useEffectCall = query.byCallExpression(ast):filter(is.call("useEffect"))

useEffectCall:forEach(function(path)
	-- find local references that are not in the dependency array; print warning
	local callback = path:getDescendantAt("arguments", 1, "node")
	local deps = path:getDescendantAt("arguments", 2, "node")
	local referencedDeps = query(deps, "LocalReference"):nodes()
	query(callback, "LocalReference", function(path)
		if referencedDeps[path.node] == nil then
			local varName = path.node.token.text
			print(`WARN missing dependency: {varName}`)
		end
	end) -- get vars referenced in callback that are not in deps
end)
