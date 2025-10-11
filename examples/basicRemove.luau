local parser = require("@std/syntax/parser")
local q = require("../src")
local query = q.query
local common = q.astUtils
local matchers = q.matchers
local has = matchers.has

local src = [[
    print("keep")
    print("remove")
    print("keep")
    print("remove")
    print("keep")
    print("remove")
    print("keep")
    print("remove")
    print("keep")
]]

-- lets remove all the print("remove") statements
local ast = parser.parse(src)
local printRemoveCalls = query.byCallStatement(ast, function(callPath)
    if has.token("remove")(callPath) then
        return callPath.node
    end
    return nil
end)
printRemoveCalls:forEach(function(path)
    path:delete()
end)

print(common.getStatementText(ast))