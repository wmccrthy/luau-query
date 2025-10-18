-- test is and has methods
local matchers = require("../matchers")
local is, has = matchers.is, matchers.has
local parser = require("@std/syntax/parser")
local path = require("../path")

-- only testing is/has methods that have more complex logic than just checking if a nodePath property exists or equals certain value

local function setup(src: string): path.Path<any>
	local pathCache = {}
	local srcAST = parser.parse(src)
	path.createPathCache(pathCache, srcAST, nil, nil)
	local rootPath = pathCache[srcAST]
	return rootPath
end

function test_hasToken()
	local src = "local myToken = 1"
	local rootPath = setup(src)
	assert(has.token("myToken")(rootPath), "Failed to detect token: myToken on Path")
end

function test_isCall()
	local src = [[
        print(1)
        local x = print
    ]]
	local rootPath = setup(src)
	local callPath = rootPath:findFirstDescendant(function(nodePath)
		return nodePath.node.tag == "call"
	end)
	assert(is.call("print")(callPath), "Failed to detect call")
	assert(not is.call("require")(callPath), "Incorrectly evaluated faulty call path as truthy")
	assert(#rootPath:findDescendants(is.call()) == 1, "Found too many calls")
end

function test_isGlobalFunction()
	local src = [[
        function myGlobalFunc()
            return
        end
    ]]
	local rootPath = setup(src)
	local functionPath = rootPath:getDescendantAt("statements", 1)
	assert(is.globalFunction("myGlobalFunc")(functionPath), "Failed to detect global function")
	assert(
		not is.globalFunction("notMyGlobalFunc")(functionPath),
		"Incorrectly evaluated faulty global function as truthy"
	)
end

function test_isLocalFunction()
	local src = [[
        local function myLocalFunc()
            return
        end
    ]]
	local rootPath = setup(src)
	local functionPath = rootPath:getDescendantAt("statements", 1)
	assert(is.localFunction("myLocalFunc")(functionPath), "Failed to detect local function")
	assert(
		not is.localFunction("notMyLocalFunc")(functionPath),
		"Incorrectly evaluated faulty local function as truthy"
	)
end

function test_isLocalDeclaration()
	local src = "local myLocal = 1"
	local rootPath = setup(src)
	local declarationPath = rootPath:getDescendantAt("statements", 1)
	assert(is.localDeclaration()(declarationPath), "Failed to detect local declaration")
end

function test_isLocalReference()
	local src = [[
        local myLocal = 1
        print(myLocal)
    ]]
	local rootPath = setup(src)
	local referencePath = rootPath:getDescendantAt("statements", 2, "expression", "arguments", 1, "node")
	assert(is.localReference("myLocal")(referencePath), "Failed to detect local reference")
	assert(not is.localReference("notMyLocal")(referencePath), "Incorrectly evaluated faulty local reference as truthy")
end

function test_isGlobalReference()
	local src = "local p = print"
	local rootPath = setup(src)
	local referencePath = rootPath:getDescendantAt("statements", 1, "values", 1, "node")
	assert(is.globalReference("print")(referencePath), "Failed to detect global reference")
	assert(not is.globalReference("notPrint")(referencePath), "Incorrectly evaluated faulty global reference as truthy")
end

function test_isIndexName()
	local src = [[
        local t = {
            a = {
                b = 1
            }
        }
        print(t.a)
        print(t.a.b)
    ]]
	local rootPath = setup(src)
	local firstIndexNamePath = rootPath:getDescendantAt("statements", 2, "expression", "arguments", 1, "node")
	local secondIndexNamePath = rootPath:getDescendantAt("statements", 3, "expression", "arguments", 1, "node")
	assert(is.indexName({ "t", "a" })(firstIndexNamePath), "Failed to detect indexname")
	assert(is.indexName({ "t", "a", "b" })(secondIndexNamePath), "Failed to detect indexname")
end

function test_isNthChild()
	local src = [[
        local x = 1
        local y = 2
        local z = 3
    ]]
	local rootPath = setup(src)
	local firstChildPath = rootPath:getDescendantAt("statements", 1)
	local secondChildPath = rootPath:getDescendantAt("statements", 2)
	local thirdChildPath = rootPath:getDescendantAt("statements", 3)
	assert(is.nthChild(1)(firstChildPath), "Incorrectly evaluated first child")
	assert(is.nthChild(2)(secondChildPath), "Incorrectly evaluated second child")
	assert(is.nthChild(3)(thirdChildPath), "Incorrectly evaluated third child")
end

function test_hasArgument()
	local src = [[
		local x = 1
		print(x)
		print(1, 2)
	]]
	local function alwaysTrue(_n)
		return true
	end
	local rootPath = setup(src)
	local invalidPath = rootPath:getDescendantAt("statements", 1)
	local printSinglePath = rootPath:getDescendantAt("statements", 2, "expression")
	local printMultiplePath = rootPath:getDescendantAt("statements", 3, "expression")
	assert(not has.argument(1, alwaysTrue)(invalidPath), "Returned true for invalid node")
	assert(has.argument(1, alwaysTrue)(printSinglePath), "Failed to detect argument 1 in: print(x)")
	assert(
		matchers.all(has.argument(1, alwaysTrue), has.argument(2, alwaysTrue))(printMultiplePath),
		"Failed to detect arguments in: print(1, 2)"
	)
end

local function test_hasPropertyDeep()
	local src = "local x = 1"
	local rootPath = setup(src)
	assert(has.propertyDeep({ "statements", 1 })(rootPath), "Failed to find first statement")
	assert(
		has.propertyDeep({ "statements", 1, "variables", 1 })(rootPath),
		"Failed to find variable in first statement"
	)
	assert(
		has.propertyDeep({ "statements", 1, "variables", 1, "node", "name", "text" }, "x")(rootPath),
		"Failed to find text of first variable"
	)
	assert(not has.propertyDeep({ "statements", 2 })(rootPath), "False positive")
	assert(
		not has.propertyDeep({ "statements", 1, "variables", 1, "node", "name", "text" }, "y")(rootPath),
		"False positive"
	)
end

function run()
	test_hasToken()
	test_isCall()
	test_isGlobalFunction()
	test_isLocalFunction()
	test_isLocalDeclaration()
	test_isLocalReference()
	test_isGlobalReference()
	test_isIndexName()
	test_isNthChild()
	test_hasArgument()
	test_hasPropertyDeep()
end

return run
