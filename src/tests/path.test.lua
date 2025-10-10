local parser = require("@std/syntax/parser")
local path = require("../path")
local matchers = require("../matchers")
local has, is, all, negate = matchers.has, matchers.is, matchers.all, matchers.negate
local ast = require("../commonUtils/common")

type Path<T> = path.Path<T>

local src = [[
    local x = 1
    local y = 2
    print(3)
]]
local srcAST = parser.parse(src)

local function checkNodeExistsInCache(node, pathCache, invert: boolean?) -- pass invert to assert that node doesn't exist in cache
	for k, v in node do
		if typeof(v) == "table" then
			-- since these are not root level nodes, they should all have parent and id entries
			assert(
				if invert then not pathCache[v] else pathCache[v],
				if invert then "Failed to delete cache entry for node" else "Failed to create cache entry for node"
			)
			if not invert then
				assert(pathCache[v].node == v)
				assert(pathCache[v].parentPath, "Failed to cache parent for node")
				assert((pathCache[v].parentPath :: Path<any>).node == node, "Incorrectly cached parent for node")
				assert(pathCache[v].id == k, "Incorrectly cached id for node")
			end
			checkNodeExistsInCache(v, pathCache, invert)
		end
	end
end

local function test_createPathCache()
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	assert(pathCache[srcAST], "Failed to create cache entry for root node")
	checkNodeExistsInCache(srcAST, pathCache)
end

local function test_pathFindFirstAncestor()
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	-- test simple detection of ancestors
	local rootPath = pathCache[srcAST]
	assert(rootPath:findFirstAncestor(function(n)
		return true
	end) == nil, "Should find no ancestors for root node")
	local statementsPath = pathCache[srcAST.statements]
	assert(
		statementsPath:findFirstAncestor(has.tag("block")) == rootPath,
		"Should find block ancestor for statements node"
	)
	for _, statement in srcAST.statements do
		-- for each statement, should be able to find statements and block ancestor
		local statementPath = pathCache[statement]
		assert(
			statementPath:findFirstAncestor(has.tag("block")) == rootPath,
			"Should find block ancestor for each statement node"
		)
		assert(
			statementPath:findFirstAncestor(function(path)
				return path.id == "statements"
			end),
			"Should find statements ancestor for each statement node"
		)
	end
end

local function test_pathFindFirstDescendant()
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	local rootPath = pathCache[srcAST]
	local firstLocal = rootPath:findFirstDescendant(has.tag("local"))
	assert(firstLocal, "Failed to find local descendant")
	-- firstDescendant should be local x
	assert(has.token("x")(firstLocal), "Found incorrect local")
end

local function test_pathFindDescendants()
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	local rootPath = pathCache[srcAST]
	local function isLocal(path)
		return path.node.tag == "local"
	end
	assert(#rootPath:findDescendants(isLocal) == 2, "Failed to find local descendant")
	assert(#rootPath:findDescendants(function(path)
		return path.node.tag == "call"
	end) == 1, "Failed to find call descendants")
	assert(#rootPath:findDescendants(function(path)
		return path.node.tag == "number"
	end) == 3, "Failed to find number descendants")
end

local function test_pathReplace()
	local srcAST = parser.parse(src)
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	local statements = pathCache[srcAST.statements]
	local newSrc = [[
		print("replaced everything :0")
	]]
	local newAstSrc = parser.parse(newSrc)
	local newNode = newAstSrc.statements
	local oldNode = statements.node
	statements:replace(function(_n)
		return newNode
	end)
	assert(ast.getStatementText(srcAST, true) == ast.getStatementText(newAstSrc, true), "Failed to replace node")

	-- newNode should exist in the cache
	checkNodeExistsInCache(newNode, pathCache)
	-- statements should be gone from the cache
	checkNodeExistsInCache(oldNode, pathCache, true)
end

local function test_pathInsert()
	local srcAST = parser.parse(src)
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	local statementsPath = pathCache[srcAST.statements]
	-- test inserting statement at top of block
	statementsPath:insert(function(_n)
		return parser.parse("print('i am the king of the block')\n").statements[1]
	end, 1)
	local newStatement = srcAST.statements[1] -- inserted statement should now be at top of block
	assert(
		newStatement.tag == "expression" and newStatement.expression.tag == "call",
		"Failed to insert node correctly"
	)
	assert(pathCache[newStatement].id == 1, "Inserted node with incorrect id")
	assert(ast.getStatementText(newStatement, true) == "print('i am the king of the block')")
	-- new node should exist in the cache
	checkNodeExistsInCache(newStatement, pathCache)
	-- existing children should have updated ids
	for i = 2, #srcAST.statements do
		local statementPath = pathCache[srcAST.statements[i]]
		assert(statementPath.id == i, "Failed to update position of affected siblings after node insertion")
	end
end

local function test_pathDelete()
	local srcAST = parser.parse(src)
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	assert(#srcAST.statements == 3, "Starting out with incorrect # of statements")
	local firstStatement = srcAST.statements[1]
	local firstStatementPath = pathCache[firstStatement]
	firstStatementPath:delete()
	assert(#srcAST.statements == 2, "Failed to delete statement")
	local rootPath = pathCache[srcAST]
	assert(rootPath:findFirstDescendant(function(nodePath)
		local isLocalX = nodePath.id == "variables" and nodePath.node[1].node.name.text == "x"
		return isLocalX
	end) == nil, "Found statement we wanted to delete")
	-- old node should be gone from the cache
	checkNodeExistsInCache(firstStatement, pathCache, true)
	-- existing children should have updated ids
	for i = 1, #srcAST.statements do
		local statementPath = pathCache[srcAST.statements[i]]
		assert(statementPath.id == i, "Failed to update position of affected sibling nodes after node deletion")
	end
end

local function test_pathCacheNoLocalCollisions()
	-- want to test that local references don't break Path logic for declaration and prev references
	-- to enforce this, in our implementation, we omit "local" pointers from find.... (descendants/ancestors) methods
	local src = [[
		local x = 1
		assert(x)
		print(x)
	]]
	local srcAst = parser.parse(src)
	local pathCache = {}
	path.createPathCache(pathCache, srcAst, nil, nil)
	local rootPath = pathCache[srcAst]

	local declarationStatement = rootPath:findFirstDescendant(all(is.localDeclaration(), has.token("x")))
	local declarationReference = pathCache[declarationStatement.node.variables[1].node]
	local assertReference = rootPath:findFirstDescendant(is.call("assert")):findFirstDescendant(is.localReference())
	local printReference = rootPath:findFirstDescendant(is.call("print")):findFirstDescendant(is.localReference())

	-- assert identity of declarationReference
	assert(is.localDeclaration()(declarationStatement))
	assert(all(negate(has.property("tag")), has.property("name"))(declarationReference))

	-- assert declaration node and reference nodes are distinct
	assert(declarationReference ~= assertReference)
	assert(declarationReference ~= printReference)
	assert(printReference ~= assertReference)

	-- assert declaration and reference nodes have distinct ancestry
	assert(has.ancestor(has.id("variables"))(declarationReference))
	assert(has.ancestor(is.call("assert"))(assertReference))
	assert(has.ancestor(is.call("print"))(printReference))
end

local function test_pathGetDescendantAt()
	local srcAST = parser.parse(src)
	local pathCache = {}
	path.createPathCache(pathCache, srcAST, nil, nil)
	local rootPath = pathCache[srcAST]
	local statementsPath = pathCache[srcAST.statements]
	assert(rootPath:getDescendantAt("statements") == statementsPath, "Failed to get statements path")
	assert(rootPath:getDescendantAt("statements", 1), "Failed to find first statement")
	assert(rootPath:getDescendantAt("statements", 1, "variables"), "Failed to find property of first statement")
	assert(not rootPath:getDescendantAt("statements", 100), "False positive")
end

local function run()
	test_createPathCache()
	test_pathCacheNoLocalCollisions()
	test_pathFindFirstAncestor()
	test_pathFindFirstDescendant()
	test_pathFindDescendants()
	test_pathReplace()
	test_pathInsert()
	test_pathDelete()
	test_pathGetDescendantAt()
end

return run
