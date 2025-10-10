-- use these to distinguish expression and statement nodes
-- ugly hard-coding, but way better than trying to print (walk) the whole node
local statementTags = {
	["assign"] = true,
	["block"] = true,
	["break"] = true,
	["compoundassign"] = true,
	["conditional"] = true, -- This is the tag for an `if` statement
	["continue"] = true,
	["expression"] = true,
	["forin"] = true,
	["for"] = true,
	["function"] = true, -- This is the tag for a global function
	["localfunction"] = true,
	["local"] = true, -- This is the tag for a local declaration
	["repeat"] = true,
	["return"] = true,
	["typealias"] = true,
	["typefunction"] = true,
	["while"] = true,
}

-- A set containing all possible AstExpr tags, derived from `visitExpression`.
local expressionTags = {
	["binary"] = true,
	["boolean"] = true,
	["call"] = true,
	["cast"] = true,
	["conditional"] = true, -- This is the tag for an `if..then..else` expression
	["function"] = true, -- This is the tag for an anonymous function expression
	["global"] = true,
	["group"] = true,
	["index"] = true,
	["indexname"] = true,
	["interpolatedstring"] = true,
	["local"] = true, -- This is the tag for a local variable reference
	["nil"] = true,
	["number"] = true,
	["string"] = true,
	["table"] = true,
	["unary"] = true,
	["vararg"] = true,
}

local function isAmbiguousNodeStatement(
	node: any & {
		tag: "local" | "function" | "conditional",
	}
): boolean -- used to distinguish b/w expression and statement when node's tag could be either
	if node.tag == "local" then
		-- A local *statement* (declaration) has a `variables` array, a local *expression* (reference) does not.
		return node.variables ~= nil
	elseif node.tag == "function" then
		-- A function *statement* has a `name` property, an anonymous function *expression* does not.
		return node.name ~= nil
	elseif node.tag == "conditional" then
		-- Only if *statement* has end keyword
		return node.endKeyword ~= nil
	end
	return false
end

local function isStatement(node)
	if expressionTags[node.tag] and statementTags[node.tag] then
		return isAmbiguousNodeStatement(node)
	else
		return statementTags[node.tag]
	end
end

local function isExpression(node)
	if expressionTags[node.tag] and statementTags[node.tag] then
		return not isAmbiguousNodeStatement(node)
	else
		return expressionTags[node.tag]
	end
end

return {
	isExpression = isExpression,
	isStatement = isStatement,
}
