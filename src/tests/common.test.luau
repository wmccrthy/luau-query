local visitor = require("@std/syntax/visitor")
local printer = require("@std/syntax/printer")
local parser = require("@std/syntax/parser")
local ast = require("../commonUtils/common")

local function strip(s) -- convenient for testing
	-- Remove leading whitespace
	s = s:gsub("^%s*", "")
	-- Remove trailing whitespace
	s = s:gsub("%s*$", "")
	return s
end

local src = [[
        local x = 1
        local y = 2
]] -- code itself is irrelevant; just reusable sample
local srcAst = parser.parse(src)

local function test_getText()
	local textWithTrivia = ast._getText(srcAst, visitor.visitBlock, printer.printstatement)
	assert(strip(textWithTrivia) == strip(src), `Incorrect text printed: {textWithTrivia}`)
	local textWithoutTrivia = ast._getText(srcAst, visitor.visitBlock, printer.printstatement, true)
	assert(textWithoutTrivia == "localx=1localy=2")
end

local function test_isExpression()
	local expressionVisitor = visitor.createVisitor()
	expressionVisitor.visitExpression = function(node)
		assert(ast.isExpression(node), "Returned false for valid expression")
	end
	visitor.visitBlock(srcAst, expressionVisitor)
end

local function test_isStatement()
	local statementVisitor = visitor.createVisitor()
	statementVisitor.visitBlock = function(node)
		for _, statement in node.statements do
			assert(ast.isStatement(statement), "Returned false for valid statement")
		end
	end
end

local function run()
	test_getText()
	test_isExpression()
	test_isStatement()
end

return run
