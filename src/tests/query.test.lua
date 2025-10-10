local parser = require("@std/syntax/parser")
local query = require("../query")
local ast = require("../commonUtils/common")
local path = require("../path")
local matchers = require("../matchers")
local all, has = matchers.all, matchers.has
type Path<T> = path.Path<T>

local function test_queryExpression()
	local src = [[
        local x = 1
        local y = 2
        local z = x + y
    ]]
	local srcAST = parser.parse(src)
	local selected = query.byExpression(srcAST, function(nodePath): luau.AstExpr
		return if has.tag("binary")(nodePath) then nodePath.node else nil
	end)
	assert(selected, "Selected nil when expression was present")
	assert(ast.getExprText(selected.selected[1], true) == "x+y", "Failed to select expression")
end

local function test_queryStatement()
	local src = [[
        local x = 1
        local function y()
            return 1
        end
    ]]
	local srcAST = parser.parse(src)
	local selected = query.byStatement(srcAST, function(nodePath): luau.AstStat
		return if has.tag("localfunction")(nodePath) then nodePath.node else nil
	end)
	assert(selected.selected, "Selected nil when statement was present")
	assert(selected.selected[1].name.name.text == "y", "Failed to select correct statement")
end

local function test_queryOnBlock()
	-- tests the extensibility of the base query
	local src = [[
        table.insert()
        assert(true)
        print(2)
        print(1)
    ]]
	-- we want to find call nodes, so we'll leverage query
	-- let's query to get all 'print' calls
	local srcAST = parser.parse(src)
	local printCalls = query(srcAST, "Call", function(nodePath: Path<luau.AstExprCall>)
		local node = nodePath.node
		if node.func.tag == "global" and node.func.name.text == "print" then
			return node
		end
		return nil
	end)
	assert(printCalls, "Failed to query for print calls")
	assert(printCalls:size() == 2, "Failed to find all print nodes")
end

local function test_queryOnStatement()
	-- tests that base query can be called on a statement node (not just block)
	-- this is rly nice bc it allows us to query within specific nodes, rather than only at the block level
	local src = [[
        local x = 1
    ]]
	local srcAST = parser.parse(src)
	local statement = srcAST.statements[1]
	-- lets query for the local variable in our statement
	assert(ast.isStatement(statement), "Not testing on expression node")
	local variableName = query(statement, "Local", function(nodePath)
		local node = nodePath.node
		return node.name
	end).selected
	assert(variableName, "Failed to query on statement node")
	assert(#variableName == 1, "Incorrectly queried statement node")
	assert(variableName[1].text == "x", "Incorrectly queried statement node")
end

local function test_queryOnExpression()
	local src = [[
        print(1)
    ]]
	local srcAST = parser.parse(src)
	local statement = srcAST.statements[1]
	local expression = statement.expression
	assert(ast.isExpression(expression), "Not testing on expression node")
	-- lets query for the global in our statement
	local variableName = query(expression, "Global", function(nodePath)
		local node = nodePath.node
		return node.name
	end).selected
	assert(variableName, "Failed to query on expression node")
	assert(#variableName == 1, "Incorrectly queried expression node")
	assert(variableName[1].text == "print", "Incorrectly queried expression node")
end

local function test_queryNoCondition()
	local src = [[
        table.insert()
        assert(true)
        print(2)
        print(1)
    ]]
	local srcAST = parser.parse(src)
	local calls = query.byCallExpression(srcAST)
	assert(#calls.selected == 4, "Failed to query with default condition")
end

local function test_transformableForEach()
	local funcCalls = 0
	local testCall = function()
		funcCalls += 1
	end

	local src = [[
		print(1)
		print(1)
		print(1)
	]]
	local srcAST = parser.parse(src)
	-- get statements
	-- forEach call testCall
	-- funcCalls should == 3
	local statements = query.byStatement(srcAST)
	assert(statements:size() == 3)
	statements:forEach(testCall)
	assert(funcCalls == 3)
end

local function test_transformableReplace()
	local src = [[
		print(true)
		print(true)
	]]
	local srcAST = parser.parse(src)
	query
		.byCallExpression(srcAST)
		:forEach(function(nodePath) -- don't necessarily need to use the node passed by replace
			nodePath:replace(function(n)
				return parser.parseexpr("\nassert(true)")
			end)
		end)
	assert(ast.getStatementText(ast.getFormattedStatement(srcAST)) == "assert(true)\nassert(true)\n")
end

local function test_transformableDelete()
	local src = [[
		print(1)
		print(2)
		print(1)
		print(2)
		print(1)
	]]
	local srcAST = parser.parse(src)
	query
		.byCallStatement(srcAST) -- returns Transformable
		:filter(function(nodePath)
			return nodePath.node.expression.arguments[1].node.text == "1"
		end)
		:forEach(function(nodePath)
			nodePath:delete()
		end)
	-- there should now be two print calls, both with 2 as arg
	local remainingPrints = query.byCallExpression(srcAST)
	assert(#remainingPrints.selected == 2, `Improperly deleted prints: {#remainingPrints}`)
	remainingPrints:forEach(function(nodeData)
		local argument = nodeData.node.arguments[1].node.text
		assert(argument == "2")
	end)

	-- for good measure (we prop only need this but the above is good demo of how query can be used for testing)
	assert(ast.getStatementText(ast.getFormattedStatement(srcAST)) == "print(2)\nprint(2)\n")
end

local function test_transformableInsertBefore()
	local src = [[
		print(1)
		print(1)
	]]
	local srcAST = parser.parse(src)
	-- insert print("hi") before each call
	query.byCallStatement(srcAST):forEach(function(nodePath)
		nodePath:insertBefore(function(n)
			return parser.parse("print(2)").statements[1]
		end)
	end)

	-- verify we now have two print(2) calls
	local res = query.byCallStatement(srcAST)
	assert(#res.selected == 4, "Inserted incorrect amount of nodes")
	-- map print calls into just their argument
	local newPrints = res:find("Call", function(nodePath)
		local node = nodePath.node -- get first argument of each call
		return node.arguments[1].node
	end):filter(function(nodeData) -- filter arguments according to those which == 2
		return nodeData.node.value == 2
	end)
	assert(#newPrints.selected == 2, "Inserted incorrect amount of new nodes")
	assert(ast.getStatementText(srcAST.statements[1], true) == "print(2)")
	assert(ast.getStatementText(srcAST.statements[2], true) == "print(1)")
	assert(ast.getStatementText(srcAST.statements[3], true) == "print(2)")
	assert(ast.getStatementText(srcAST.statements[4], true) == "print(1)")
end

local function test_transformableInsertAfter()
	-- reverse the above test
	local src = [[
		print(1)
		print(1)
	]]
	local srcAST = parser.parse(src)
	-- insert print("hi") before each call
	query.byCallStatement(srcAST):forEach(function(nodePath)
		nodePath:insertAfter(function(n)
			return parser.parse("print(2)").statements[1]
		end)
	end)

	-- verify we now have two print(2) calls
	local res = query.byCallStatement(srcAST)
	assert(#res.selected == 4, "Inserted incorrect amount of nodes")
	-- map print calls into just their argument
	local newPrints = res:find("Call", function(nodePath)
		local node = nodePath.node
		return node.arguments[1].node
	end):filter(function(nodeData) -- filter arguments according to those which = 2
		return nodeData.node.value == 2
	end)
	assert(#newPrints.selected == 2, "Inserted incorrect amount of new nodes")
	assert(ast.getStatementText(srcAST.statements[1], true) == "print(1)")
	assert(ast.getStatementText(srcAST.statements[2], true) == "print(2)")
	assert(ast.getStatementText(srcAST.statements[3], true) == "print(1)")
	assert(ast.getStatementText(srcAST.statements[4], true) == "print(2)")
end
-- THE ABOVE TWO TESTS ARE REDUNDANT; WE PROB JUST NEED ONE...

local function test_transformableFilter()
	local src = [[
		local x = 1
		print(x)
	]]
	local srcAST = parser.parse(src)
	local filterForLocal = query.byStatement(srcAST):filter(function(nodeData)
		return nodeData.node.tag == "local"
	end)
	-- test filter works
	assert(filterForLocal:size() == 1, "Filtered incorrectly")
	assert(filterForLocal.selected[1] == srcAST.statements[1], "Filtered for incorrect statement")
end

local function test_transformableParent()
	local src = [[
		local x = 1
		print(x)
	]]
	local srcAST = parser.parse(src)
	local parent = query -- getting the parent for each statement in the tree
		.byStatement(srcAST)
		:parent()
	-- test parent() works; bc we queried statements and the only two statements in the tree are in the same block, there should be one parent
	assert(parent:size() == 1, "Returned too many parents")
	assert(parent.selected[1] == srcAST.statements, "Found incorrect parent")
	local root = parent:parent()
	assert(parent:size() == 1, "Returned too many parents (chain)")
	assert(root.selected[1] == srcAST, "Found incorrect parent (chain)")
end

--
local function test_transformableMap()
	local src = [[
		local x = 1
		local y = 2	
	]]
	local srcAST = parser.parse(src)
	local values = query.byStatement(srcAST):map(function(nodeData)
		return nodeData.node.values[1].node
	end)
	assert(#values == 2, "Incorrectly mapped query result")
	assert(values[1].value == 1)
	assert(values[2].value == 2)
end

-- lol we use this for testing in some of the above functions so it is kinda already tested
local function test_transformableFind()
	local src = [[
		local x = 1
		local y = 2
		local z = 3
	]]
	local srcAST = parser.parse(src)
	local statements = query.byStatement(srcAST)
	-- lets get all the variables in our statements
	local vars = statements:find("LocalDeclaration", function(nodePath)
		return nodePath:findFirstDescendant(all(has.ancestor(has.id("variables")), has.id(1))).node.node
	end)
	assert(vars, "find failed!")
	assert(vars:size() == 3, "found incorrect number of nodes")
	assert(vars.selected[1].name.text == "x", "found incorrect variable for x")
	assert(vars.selected[2].name.text == "y", "found incorrect variable for y")
	assert(vars.selected[3].name.text == "z", "found incorrect variable for z")
end

function run()
	test_queryExpression()
	test_queryStatement()
	test_queryOnBlock()
	test_queryOnStatement()
	test_queryOnExpression()
	test_queryNoCondition()

	test_transformableForEach()
	test_transformableReplace()
	test_transformableFilter()
	test_transformableDelete()
	test_transformableInsertAfter()
	test_transformableInsertBefore()
	test_transformableMap()
	test_transformableParent()
	test_transformableFind()
end

return run
