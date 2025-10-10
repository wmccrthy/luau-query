--!strict
local luau = require("@lute/luau")
local visitor = require("@std/syntax/visitor")
local printer = require("@std/syntax/printer")
local process = require("@lute/process")
local fs = require("@lute/fs")
local parser = require("@std/syntax/parser")
local tagMappings = require("./tagMappings")

type TriviaMap = { [luau.Token]: {
	leadingTrivia: { luau.Trivia },
	trailingTrivia: { luau.Trivia },
} }

function removeTrivia<T>(node: T, visit: (node: T, visitor: visitor.Visitor) -> ()): TriviaMap
	local triviaKiller = visitor.createVisitor()
	local toRestore: TriviaMap = {}
	triviaKiller.visitToken = function(node: luau.Token)
		toRestore[node] = {
			leadingTrivia = node.leadingTrivia,
			trailingTrivia = node.trailingTrivia,
		}
		node.leadingTrivia, node.trailingTrivia = {}, {}
		return true
	end
	visit(node, triviaKiller)
	return toRestore
end

function restoreTrivia<T>(node: T, visit: (node: T, visitor: visitor.Visitor) -> (), toRestore: TriviaMap)
	local triviaKiller = visitor.createVisitor()
	triviaKiller.visitToken = function(node: luau.Token)
		node.leadingTrivia = toRestore[node].leadingTrivia
		node.trailingTrivia = toRestore[node].trailingTrivia
		return true
	end
	visit(node, triviaKiller)
end

function getText<T>(
	node: T,
	visit: (node: T, visitor: visitor.Visitor) -> (),
	printer: (node: T) -> string,
	excludeTrivia: boolean?
)
	local trivia
	if excludeTrivia then
		trivia = removeTrivia(node, visit)
	end
	local str = printer(node)
	if trivia then
		restoreTrivia(node, visit, trivia)
	end
	return str
end

function getExprText(node: luau.AstExpr, excludeTrivia: boolean?)
	return getText(node, visitor.visitExpression, printer.printexpr, excludeTrivia)
end

function getStatementText(node: luau.AstStat, excludeTrivia: boolean?)
	return getText(node, visitor.visitStatement, printer.printstatement, excludeTrivia)
end

function getTypeText(node: luau.AstType, excludeTrivia: boolean?)
	return getText(node, visitor.visitType, printer.printType, excludeTrivia)
end

function getTextExhaustive(node: any, excludeTrivia: boolean?): string | nil
	local success, res = pcall(function()
		return getExprText(node, excludeTrivia)
	end)
	if not success then
		success, res = pcall(function()
			return getStatementText(node, excludeTrivia)
		end)
	end
	if not success then
		success, res = pcall(function()
			return getTypeText(node, excludeTrivia)
		end)
	end
	return if success then res else nil
end

function isExpression(node: any): boolean
	return tagMappings.isExpression(node)
end

function isStatement(node: any): boolean
	return tagMappings.isStatement(node)
end

-- we should just replace the above with this IMO
function _matchesPathTable(node: any, pathParts: { string }): boolean
	local currentNode = node
	local numParts = #pathParts

	-- Walk backwards from the end of the path (e.g., from "Button" up to "UIBlox")
	for i = numParts, 1, -1 do
		local part = pathParts[i]

		if i == 1 then
			-- We're at root of path, it should be a global or local identifier.
			if currentNode.tag == "global" and currentNode.name.text == part then
				return true -- Match found
			elseif currentNode.tag == "local" and currentNode.token.text == part then
				return true -- Match found
			end
		else
			-- Not root, it must be a property access.
			if currentNode.tag == "indexname" and currentNode.index.text == part then
				currentNode = currentNode.expression
			else
				return false -- Path doesn't match
			end
		end
	end

	return false
end

-- hacky but convenient and mainly used for testing
function getFormattedStatement(node: luau.AstStat): luau.AstStat
	-- randomize number to avoid collisions
	local hash1, hash2 = math.random(0, 99999), math.random(0, 99999)
	local tmpFilePath = `./{os.clock()}_{hash1}_ast_tmp_{node.tag}_{hash2}.luau`
	process.run({ "touch", tmpFilePath })
	fs.writestringtofile(tmpFilePath, printer.printstatement(node))
	process.run({ "stylua", tmpFilePath })
	local formatted = parser.parse(fs.readfiletostring(tmpFilePath))
	process.run({ "rm", tmpFilePath })
	return formatted
end

return {
	getFormattedStatement = getFormattedStatement,
	getTypeText = getTypeText,
	getExprText = getExprText,
	getStatementText = getStatementText,
	getTextExhaustive = getTextExhaustive,
	isExpression = isExpression,
	isStatement = isStatement,
	_matchesPathTable = _matchesPathTable,

	_getText = getText, -- for testing
}
