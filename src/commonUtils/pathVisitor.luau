--!strict
local luau = require("@lute/luau")
local ast = require("./common")
local path = require("../path")

export type Visitor = {
	visitBlock: (luau.AstStatBlock) -> boolean,
	visitBlockEnd: (luau.AstStatBlock) -> (),
	visitIf: (luau.AstStatIf) -> boolean,
	visitWhile: (luau.AstStatWhile) -> boolean,
	visitRepeat: (luau.AstStatRepeat) -> boolean,
	visitReturn: (luau.AstStatReturn) -> boolean,
	visitLocalDeclaration: (luau.AstStatLocal) -> boolean,
	visitLocalDeclarationEnd: (luau.AstStatLocal) -> (),
	visitFor: (luau.AstStatFor) -> boolean,
	visitForIn: (luau.AstStatForIn) -> boolean,
	visitAssign: (luau.AstStatAssign) -> boolean,
	visitCompoundAssign: (luau.AstStatCompoundAssign) -> boolean,
	visitFunction: (luau.AstStatFunction) -> boolean,
	visitLocalFunction: (luau.AstStatLocalFunction) -> boolean,
	visitTypeAlias: (luau.AstStatTypeAlias) -> boolean,
	visitStatTypeFunction: (luau.AstStatTypeFunction) -> boolean,

	visitExpression: (luau.AstExpr) -> boolean,
	visitExpressionEnd: (luau.AstExpr) -> (),
	visitLocalReference: (luau.AstExprLocal) -> boolean,
	visitGlobal: (luau.AstExprGlobal) -> boolean,
	visitCall: (luau.AstExprCall) -> boolean,
	visitUnary: (luau.AstExprUnary) -> boolean,
	visitBinary: (luau.AstExprBinary) -> boolean,
	visitAnonymousFunction: (luau.AstExprAnonymousFunction) -> boolean,
	visitTableItem: (luau.AstExprTableItem) -> boolean,
	visitTable: (luau.AstExprTable) -> boolean,
	visitIndexName: (luau.AstExprIndexName) -> boolean,
	visitIndexExpr: (luau.AstExprIndexExpr) -> boolean,
	visitGroup: (luau.AstExprGroup) -> boolean,
	visitInterpolatedString: (luau.AstExprInterpString) -> boolean,
	visitTypeAssertion: (luau.AstExprTypeAssertion) -> boolean,
	visitIfExpression: (luau.AstExprIfElse) -> boolean,

	visitTypeReference: (luau.AstTypeReference) -> boolean,
	visitTypeBoolean: (luau.AstTypeSingletonBool) -> boolean,
	visitTypeString: (luau.AstTypeSingletonString) -> boolean,
	visitTypeTypeof: (luau.AstTypeTypeof) -> boolean,
	visitTypeGroup: (luau.AstTypeGroup) -> boolean,
	visitTypeUnion: (luau.AstTypeUnion) -> boolean,
	visitTypeIntersection: (luau.AstTypeIntersection) -> boolean,
	visitTypeArray: (luau.AstTypeArray) -> boolean,
	visitTypeTable: (luau.AstTypeTable) -> boolean,
	visitTypeFunction: (luau.AstTypeFunction) -> boolean,

	visitTypePackExplicit: (luau.AstTypePackExplicit) -> boolean,
	visitTypePackGeneric: (luau.AstTypePackGeneric) -> boolean,
	visitTypePackVariadic: (luau.AstTypePackVariadic) -> boolean,

	visitToken: (luau.Token) -> boolean,
	visitNil: (luau.AstExprConstantNil) -> boolean,
	visitString: (luau.AstExprConstantString) -> boolean,
	visitBoolean: (luau.AstExprConstantBool) -> boolean,
	visitNumber: (luau.AstExprConstantNumber) -> boolean,
	visitLocal: (luau.AstLocal) -> boolean,
	visitVarargs: (luau.AstExprVarargs) -> boolean,
}

local function alwaysVisit(...: any)
	return true
end

local defaultVisitor: Visitor = {
	visitBlock = alwaysVisit :: any,
	visitBlockEnd = alwaysVisit :: any,
	visitIf = alwaysVisit :: any,
	visitWhile = alwaysVisit :: any,
	visitRepeat = alwaysVisit :: any,
	visitReturn = alwaysVisit :: any,
	visitLocalDeclaration = alwaysVisit :: any,
	visitLocalDeclarationEnd = alwaysVisit :: any,
	visitFor = alwaysVisit :: any,
	visitForIn = alwaysVisit :: any,
	visitAssign = alwaysVisit :: any,
	visitCompoundAssign = alwaysVisit :: any,
	visitFunction = alwaysVisit :: any,
	visitLocalFunction = alwaysVisit :: any,
	visitTypeAlias = alwaysVisit :: any,
	visitStatTypeFunction = alwaysVisit :: any,

	visitExpression = alwaysVisit :: any,
	visitExpressionEnd = alwaysVisit :: any,
	visitLocalReference = alwaysVisit :: any,
	visitGlobal = alwaysVisit :: any,
	visitCall = alwaysVisit :: any,
	visitUnary = alwaysVisit :: any,
	visitBinary = alwaysVisit :: any,
	visitAnonymousFunction = alwaysVisit :: any,
	visitTableItem = alwaysVisit :: any,
	visitTable = alwaysVisit :: any,
	visitIndexName = alwaysVisit :: any,
	visitIndexExpr = alwaysVisit :: any,
	visitGroup = alwaysVisit :: any,
	visitInterpolatedString = alwaysVisit,
	visitTypeAssertion = alwaysVisit,
	visitIfExpression = alwaysVisit,

	visitTypeReference = alwaysVisit :: any,
	visitTypeBoolean = alwaysVisit :: any,
	visitTypeString = alwaysVisit :: any,
	visitTypeTypeof = alwaysVisit :: any,
	visitTypeGroup = alwaysVisit :: any,
	visitTypeUnion = alwaysVisit :: any,
	visitTypeIntersection = alwaysVisit :: any,
	visitTypeArray = alwaysVisit :: any,
	visitTypeTable = alwaysVisit :: any,
	visitTypeFunction = alwaysVisit,

	visitTypePackExplicit = alwaysVisit,
	visitTypePackGeneric = alwaysVisit,
	visitTypePackVariadic = alwaysVisit,

	visitToken = alwaysVisit :: any,
	visitNil = alwaysVisit :: any,
	visitString = alwaysVisit :: any,
	visitBoolean = alwaysVisit :: any,
	visitNumber = alwaysVisit :: any,
	visitLocal = alwaysVisit :: any,
	visitVarargs = alwaysVisit :: any,
}

local function exhaustiveMatch(value: never): never
	error(`Unknown value in exhaustive match: {value}`)
end

local function visitToken<T>(token: luau.Token<T>, visitor: Visitor, parent, id, cache)
	path.registerPath(token, parent, id, cache)
	visitor.visitToken(token)
end

-- at top level of visit function we register with exact parameters;
-- we then pass parent and id to children according to how they are accessed

local function visitPunctuated<T, Separator>(
	list: luau.Punctuated<T, Separator>,
	visitor: Visitor,
	apply: (T, Visitor, any, any, any) -> (),
	parent,
	id,
	cache
)
	local listPath = path.registerPath(list, parent, id, cache)
	for ind, item in list do
		local itemPath = path.registerPath(item, listPath, ind, cache)

		apply(item.node, visitor, itemPath, "node", cache)
		if item.separator then
			visitToken(item.separator, visitor, itemPath, "separator", cache)
		end
	end
end

local function visitLocal(node: luau.AstLocal, visitor: Visitor, parent, id, cache)
	local localPath = path.registerPath(node, parent, id, cache)
	if visitor.visitLocal(node) then
		visitToken(node.name, visitor, localPath, "name", cache)
		if node.colon then
			visitToken(node.colon, visitor, localPath, "colon", cache)
		end
		if node.annotation then
			visitType(node.annotation, visitor, localPath, "annotation", cache)
		end
	end
end

local function visitBlock(block: luau.AstStatBlock, visitor: Visitor, parent, id, cache)
	local blockPath = path.registerPath(block, parent, id, cache)
	-- print("registered path in block")
	if visitor.visitBlock(block) then
		local statementsPath = path.registerPath(block.statements, blockPath, "statements", cache)
		for ind, statement in block.statements do
			visitStatement(statement, visitor, statementsPath, ind, cache)
		end

		visitor.visitBlockEnd(block)
	end
end

local function visitIf(node: luau.AstStatIf, visitor: Visitor, parent, id, cache)
	local ifPath = path.registerPath(node, parent, id, cache)
	if visitor.visitIf(node) then
		visitToken(node.ifKeyword, visitor, ifPath, "ifKeyword", cache)
		visitExpression(node.condition, visitor, ifPath, "condition", cache)
		visitToken(node.thenKeyword, visitor, ifPath, "thenKeyword", cache)
		visitBlock(node.consequent, visitor, ifPath, "consequent", cache)
		local elseIfPath = path.registerPath(node.elseifs, ifPath, "elseIfs", cache)
		for _, elseifNode in node.elseifs do
			visitToken(elseifNode.elseifKeyword, visitor, elseIfPath, "elseifKeywords", cache)
			visitExpression(elseifNode.condition, visitor, elseIfPath, "elseifNode", cache)
			visitToken(elseifNode.thenKeyword, visitor, elseIfPath, "thenKeyword", cache)
			visitBlock(elseifNode.consequent, visitor, elseIfPath, "consequent", cache)
		end
		if node.elseKeyword then
			visitToken(node.elseKeyword, visitor, ifPath, "elseKeyword", cache)
		end
		if node.antecedent then
			visitBlock(node.antecedent, visitor, ifPath, "antecedent", cache)
		end
		visitToken(node.endKeyword, visitor, ifPath, "endKeyword", cache)
	end
end

local function visitWhile(node: luau.AstStatWhile, visitor: Visitor, parent, id, cache)
	local whilePath = path.registerPath(node, parent, id, cache)
	if visitor.visitWhile(node) then
		visitToken(node.whileKeyword, visitor, whilePath, "whileKeyword", cache)
		visitExpression(node.condition, visitor, whilePath, "condition", cache)
		visitToken(node.doKeyword, visitor, whilePath, "doKeyword", cache)
		visitBlock(node.body, visitor, whilePath, "body", cache)
		visitToken(node.endKeyword, visitor, whilePath, "endKeyword", cache)
	end
end

local function visitRepeat(node: luau.AstStatRepeat, visitor: Visitor, parent, id, cache)
	local repeatPath = path.registerPath(node, parent, id, cache)
	if visitor.visitRepeat(node) then
		visitToken(node.repeatKeyword, visitor, repeatPath, "repeatKeyword", cache)
		visitBlock(node.body, visitor, repeatPath, "body", cache)
		visitToken(node.untilKeyword, visitor, repeatPath, "untilKeyword", cache)
		visitExpression(node.condition, visitor, repeatPath, "condition", cache)
	end
end

local function visitReturn(node: luau.AstStatReturn, visitor: Visitor, parent, id, cache)
	local returnPath = path.registerPath(node, parent, id, cache)
	if visitor.visitReturn(node) then
		visitToken(node.returnKeyword, visitor, returnPath, "returnKeyword", cache)
		visitPunctuated(node.expressions, visitor, visitExpression, returnPath, "expressions", cache)
	end
end

local function visitLocalStatement(node: luau.AstStatLocal, visitor: Visitor, parent, id, cache)
	local localStatPath = path.registerPath(node, parent, id, cache)
	if visitor.visitLocalDeclaration(node) then
		visitToken(node.localKeyword, visitor, localStatPath, "localKeyword", cache)
		visitPunctuated(node.variables, visitor, visitLocal, localStatPath, "variables", cache)
		if node.equals then
			visitToken(node.equals, visitor, localStatPath, "equals", cache)
		end
		visitPunctuated(node.values, visitor, visitExpression, localStatPath, "values", cache)

		visitor.visitLocalDeclarationEnd(node)
	end
end

local function visitFor(node: luau.AstStatFor, visitor: Visitor, parent, id, cache)
	local forPath = path.registerPath(node, parent, id, cache)
	if visitor.visitFor(node) then
		visitToken(node.forKeyword, visitor, forPath, "forKeyword", cache)
		visitLocal(node.variable, visitor, forPath, "variable", cache)
		visitToken(node.equals, visitor, forPath, "equals", cache)
		visitExpression(node.from, visitor, forPath, "from", cache)
		visitToken(node.toComma, visitor, forPath, "toComma", cache)
		visitExpression(node.to, visitor, forPath, "to", cache)
		if node.stepComma then
			visitToken(node.stepComma, visitor, forPath, "stepComma", cache)
		end
		if node.step then
			visitExpression(node.step, visitor, forPath, "step", cache)
		end
		visitToken(node.doKeyword, visitor, forPath, "doKeyword", cache)
		visitBlock(node.body, visitor, forPath, "body", cache)
		visitToken(node.endKeyword, visitor, forPath, "endKeyword", cache)
	end
end

local function visitForIn(node: luau.AstStatForIn, visitor: Visitor, parent, id, cache)
	local forInPath = path.registerPath(node, parent, id, cache)
	if visitor.visitForIn(node) then
		visitToken(node.forKeyword, visitor, forInPath, "forKeyword", cache)
		visitPunctuated(node.variables, visitor, visitLocal, forInPath, "variables", cache)
		visitToken(node.inKeyword, visitor, forInPath, "inKeyword", cache)
		visitPunctuated(node.values, visitor, visitExpression, forInPath, "values", cache)
		visitToken(node.doKeyword, visitor, forInPath, "doKeyword", cache)
		visitBlock(node.body, visitor, forInPath, "body", cache)
		visitToken(node.endKeyword, visitor, forInPath, "endKeyword", cache)
	end
end

local function visitAssign(node: luau.AstStatAssign, visitor: Visitor, parent, id, cache)
	local assignPath = path.registerPath(node, parent, id, cache)
	if visitor.visitAssign(node) then
		visitPunctuated(node.variables, visitor, visitExpression, assignPath, "variables", cache)
		visitToken(node.equals, visitor, assignPath, "equals", cache)
		visitPunctuated(node.values, visitor, visitExpression, assignPath, "values", cache)
	end
end

local function visitCompoundAssign(node: luau.AstStatCompoundAssign, visitor: Visitor, parent, id, cache)
	local compoundAssignPath = path.registerPath(node, parent, id, cache)
	if visitor.visitCompoundAssign(node) then
		visitExpression(node.variable, visitor, compoundAssignPath, "variable", cache)
		visitToken(node.operand, visitor, compoundAssignPath, "operand", cache)
		visitExpression(node.value, visitor, compoundAssignPath, "value", cache)
	end
end

local function visitGeneric(node: luau.AstGenericType, visitor: Visitor, parent, id, cache)
	local genericPath = path.registerPath(node, parent, id, cache)
	visitToken(node.name, visitor, genericPath, "name", cache)
	if node.equals then
		visitToken(node.equals, visitor, genericPath, "equals", cache)
	end
	if node.default then
		visitType(node.default, visitor, genericPath, "default", cache)
	end
end

local function visitGenericPack(node: luau.AstGenericTypePack, visitor: Visitor, parent, id, cache)
	local genericPackPath = path.registerPath(node, parent, id, cache)
	visitToken(node.name, visitor, genericPackPath, "name", cache)
	visitToken(node.ellipsis, visitor, genericPackPath, "ellipsis", cache)
	if node.equals then
		visitToken(node.equals, visitor, genericPackPath, "equals", cache)
	end
	if node.default then
		visitTypePack(node.default, visitor, genericPackPath, "default", cache)
	end
end

local function visitTypeAlias(node: luau.AstStatTypeAlias, visitor: Visitor, parent, id, cache)
	local typeAliasPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeAlias(node) then
		if node.export then
			visitToken(node.export, visitor, typeAliasPath, "export", cache)
		end
		visitToken(node.typeToken, visitor, typeAliasPath, "typeToken", cache)
		visitToken(node.name, visitor, typeAliasPath, "name", cache)
		if node.openGenerics then
			visitToken(node.openGenerics, visitor, typeAliasPath, "openGenerics", cache)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric, typeAliasPath, "generics", cache)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack, typeAliasPath, "genericPacks", cache)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor, typeAliasPath, "closeGenerics", cache)
		end
		visitToken(node.equals, visitor, typeAliasPath, "equals", cache)
		visitType(node.type, visitor, typeAliasPath, "type", cache)
	end
end

local function visitString(node: luau.AstExprConstantString, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitString(node) then
		visitor.visitToken(node)
	end
end

local function visitNil(node: luau.AstExprConstantNil, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitNil(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitBoolean(node: luau.AstExprConstantBool, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitBoolean(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitNumber(node: luau.AstExprConstantNumber, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitNumber(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitLocalReference(node: luau.AstExprLocal, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitLocalReference(node) then
		visitor.visitToken(node.token)
	end
end

local function visitGlobal(node: luau.AstExprGlobal, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitGlobal(node) then
		visitor.visitToken(node.name)
	end
end

local function visitVarargs(node: luau.AstExprVarargs, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitVarargs(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitCall(node: luau.AstExprCall, visitor: Visitor, parent, id, cache)
	local callPath = path.registerPath(node, parent, id, cache)
	if visitor.visitCall(node) then
		visitExpression(node.func, visitor, callPath, "func", cache)
		if node.openParens then
			visitToken(node.openParens, visitor, callPath, "openParens", cache)
		end
		visitPunctuated(node.arguments, visitor, visitExpression, callPath, "arguments", cache)
		if node.closeParens then
			visitToken(node.closeParens, visitor, callPath, "closeParens", cache)
		end
	end
end

local function visitUnary(node: luau.AstExprUnary, visitor: Visitor, parent, id, cache)
	local unaryPath = path.registerPath(node, parent, id, cache)
	if visitor.visitUnary(node) then
		visitToken(node.operator, visitor, unaryPath, "operator", cache)
		visitExpression(node.operand, visitor, unaryPath, "operand", cache)
	end
end

local function visitBinary(node: luau.AstExprBinary, visitor: Visitor, parent, id, cache)
	local binaryPath = path.registerPath(node, parent, id, cache)
	if visitor.visitBinary(node) then
		visitExpression(node.lhsoperand, visitor, binaryPath, "lhsoperand", cache)
		visitToken(node.operator, visitor, binaryPath, "operator", cache)
		visitExpression(node.rhsoperand, visitor, binaryPath, "rhsoperand", cache)
	end
end

local function visitFunctionBody(node: luau.AstFunctionBody, visitor: Visitor, parent, id, cache)
	local functionBodyPath = path.registerPath(node, parent, id, cache)
	if node.openGenerics then
		visitToken(node.openGenerics, visitor, functionBodyPath, "openGenerics", cache)
	end
	if node.generics then
		visitPunctuated(node.generics, visitor, visitGeneric, functionBodyPath, "generics", cache)
	end
	if node.genericPacks then
		visitPunctuated(node.genericPacks, visitor, visitGenericPack, functionBodyPath, "genericPacks", cache)
	end
	if node.closeGenerics then
		visitToken(node.closeGenerics, visitor, functionBodyPath, "closeGenerics", cache)
	end
	visitToken(node.openParens, visitor, functionBodyPath, "openParens", cache)
	visitPunctuated(node.parameters, visitor, visitLocal, functionBodyPath, "parameters", cache)
	if node.vararg then
		visitToken(node.vararg, visitor, functionBodyPath, "vararg", cache)
	end
	if node.varargColon then
		visitToken(node.varargColon, visitor, functionBodyPath, "varargColon", cache)
	end
	if node.varargAnnotation then
		visitTypePack(node.varargAnnotation, visitor, functionBodyPath, "varargAnnotation", cache)
	end
	visitToken(node.closeParens, visitor, functionBodyPath, "closeParens", cache)
	if node.returnSpecifier then
		visitToken(node.returnSpecifier, visitor, functionBodyPath, "returnSpecifier", cache)
	end
	if node.returnAnnotation then
		visitTypePack(node.returnAnnotation, visitor, functionBodyPath, "returnAnnotation", cache)
	end
	visitBlock(node.body, visitor, functionBodyPath, "body", cache)
	visitToken(node.endKeyword, visitor, functionBodyPath, "endKeyword", cache)
end

local function visitAttribute(node: luau.AstAttribute, visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	visitToken(node, visitor, parent, id, cache)
end

local function visitAnonymousFunction(node: luau.AstExprAnonymousFunction, visitor: Visitor, parent, id, cache)
	local anonymousFunctionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitAnonymousFunction(node) then
		local attributesPath = path.registerPath(node.attributes, anonymousFunctionPath, "attributes", cache)
		for ind, attribute in node.attributes do
			visitAttribute(attribute, visitor, attributesPath, ind, cache)
		end
		visitToken(node.functionKeyword, visitor, anonymousFunctionPath, "functionKeyword", cache)
		visitFunctionBody(node.body, visitor, anonymousFunctionPath, "body", cache)
	end
end

local function visitFunction(node: luau.AstStatFunction, visitor: Visitor, parent, id, cache)
	local functionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitFunction(node) then
		local attributesPath = path.registerPath(node.attributes, functionPath, "attributes", cache)
		for ind, attribute in node.attributes do
			visitAttribute(attribute, visitor, attributesPath, ind, cache)
		end
		visitToken(node.functionKeyword, visitor, functionPath, "functionKeyword", cache)
		visitExpression(node.name, visitor, functionPath, "name", cache)
		visitFunctionBody(node.body, visitor, functionPath, "body", cache)
	end
end

local function visitLocalFunction(node: luau.AstStatLocalFunction, visitor: Visitor, parent, id, cache)
	local localFunctionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitLocalFunction(node) then
		local attributesPath = path.registerPath(node.attributes, localFunctionPath, "attributes", cache)
		for ind, attribute in node.attributes do
			visitAttribute(attribute, visitor, attributesPath, ind, cache)
		end
		visitToken(node.localKeyword, visitor, localFunctionPath, "localKeyword", cache)
		visitToken(node.functionKeyword, visitor, localFunctionPath, "functionKeyword", cache)
		visitLocal(node.name, visitor, localFunctionPath, "name", cache)
		visitFunctionBody(node.body, visitor, localFunctionPath, "body", cache)
	end
end

local function visitStatTypeFunction(node: luau.AstStatTypeFunction, visitor: Visitor, parent, id, cache)
	local statTypeFunctionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitStatTypeFunction(node) then
		if node.export then
			visitToken(node.export, visitor, statTypeFunctionPath, "export", cache)
		end
		visitToken(node.type, visitor, statTypeFunctionPath, "type", cache)
		visitToken(node.functionKeyword, visitor, statTypeFunctionPath, "functionKeyword", cache)
		visitToken(node.name, visitor, statTypeFunctionPath, "name", cache)
		visitFunctionBody(node.body, visitor, statTypeFunctionPath, "body", cache)
	end
end

local function visitTableItem(node: luau.AstExprTableItem, visitor: Visitor, parent, id, cache)
	local tableItemPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTableItem(node) then
		if node.kind == "list" then
			visitExpression(node.value, visitor, tableItemPath, "value", cache)
		elseif node.kind == "record" then
			visitToken(node.key, visitor, tableItemPath, "key", cache)
			visitToken(node.equals, visitor, tableItemPath, "equals", cache)
			visitExpression(node.value, visitor, tableItemPath, "value", cache)
		elseif node.kind == "general" then
			visitToken(node.indexerOpen, visitor, tableItemPath, "indexerOpen", cache)
			visitExpression(node.key, visitor, tableItemPath, "key", cache)
			visitToken(node.indexerClose, visitor, tableItemPath, "indexerClose", cache)
			visitToken(node.equals, visitor, tableItemPath, "equals", cache)
			visitExpression(node.value, visitor, tableItemPath, "value", cache)
		else
			exhaustiveMatch(node.kind)
		end

		if node.separator then
			visitToken(node.separator, visitor, tableItemPath, "separator", cache)
		end
	end
end

local function visitTable(node: luau.AstExprTable, visitor: Visitor, parent, id, cache)
	local tablePath = path.registerPath(node, parent, id, cache)
	if visitor.visitTable(node) then
		visitToken(node.openBrace, visitor, tablePath, "openBrace", cache)
		local entriesPath = path.registerPath(node.entries, tablePath, "entries", cache)
		for ind, item in node.entries do
			visitTableItem(item, visitor, entriesPath, ind, cache)
		end
		visitToken(node.closeBrace, visitor, tablePath, "closeBrace", cache)
	end
end

local function visitIndexName(node: luau.AstExprIndexName, visitor: Visitor, parent, id, cache)
	local indexNamePath = path.registerPath(node, parent, id, cache)
	if visitor.visitIndexName(node) then
		visitExpression(node.expression, visitor, indexNamePath, "expression", cache)
		visitToken(node.accessor, visitor, indexNamePath, "accessor", cache)
		visitToken(node.index, visitor, indexNamePath, "index", cache)
	end
end

local function visitIndexExpr(node: luau.AstExprIndexExpr, visitor: Visitor, parent, id, cache)
	local indexExprPath = path.registerPath(node, parent, id, cache)
	if visitor.visitIndexExpr(node) then
		visitExpression(node.expression, visitor, indexExprPath, "expression", cache)
		visitToken(node.openBrackets, visitor, indexExprPath, "openBrackets", cache)
		visitExpression(node.index, visitor, indexExprPath, "index", cache)
		visitToken(node.closeBrackets, visitor, indexExprPath, "closeBrackets", cache)
	end
end

local function visitGroup(node: luau.AstExprGroup, visitor: Visitor, parent, id, cache)
	local groupPath = path.registerPath(node, parent, id, cache)
	if visitor.visitGroup(node) then
		visitToken(node.openParens, visitor, groupPath, "openParens", cache)
		visitExpression(node.expression, visitor, groupPath, "expression", cache)
		visitToken(node.closeParens, visitor, groupPath, "closeParens", cache)
	end
end

local function visitInterpolatedString(node: luau.AstExprInterpString, visitor: Visitor, parent, id, cache)
	local interpolatedStringPath = path.registerPath(node, parent, id, cache)
	if visitor.visitInterpolatedString(node) then
		local stringsPath = path.registerPath(node.strings, interpolatedStringPath, "strings", cache)
		local expressionsPath = path.registerPath(node.expressions, interpolatedStringPath, "expressions", cache)
		for i = 1, #node.strings do
			visitToken(node.strings[i], visitor, stringsPath, i, cache)
			if i <= #node.expressions then
				visitExpression(node.expressions[i], visitor, expressionsPath, i, cache)
			end
		end
	end
end

local function visitTypeAssertion(node: luau.AstExprTypeAssertion, visitor: Visitor, parent, id, cache)
	local typeAssertionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeAssertion(node) then
		visitExpression(node.operand, visitor, typeAssertionPath, "operand", cache)
		visitToken(node.operator, visitor, typeAssertionPath, "operator", cache)
		visitType(node.annotation, visitor, typeAssertionPath, "annotation", cache)
	end
end

local function visitIfExpression(node: luau.AstExprIfElse, visitor: Visitor, parent, id, cache)
	local ifExpressionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitIfExpression(node) then
		visitToken(node.ifKeyword, visitor, ifExpressionPath, "ifKeyword", cache)
		visitExpression(node.condition, visitor, ifExpressionPath, "condition", cache)
		visitToken(node.thenKeyword, visitor, ifExpressionPath, "thenKeyword", cache)
		visitExpression(node.consequent, visitor, ifExpressionPath, "consequent", cache)
		local elseifsPath = path.registerPath(node.elseifs, ifExpressionPath, "elseifs", cache)
		for ind, elseifs in node.elseifs do
			local elseifPath = path.registerPath(elseifs, elseifsPath, ind, cache)
			visitToken(elseifs.elseifKeyword, visitor, elseifPath, "elseifKeyword", cache)
			visitExpression(elseifs.condition, visitor, elseifPath, "condition", cache)
			visitToken(elseifs.thenKeyword, visitor, elseifPath, "thenKeyword", cache)
			visitExpression(elseifs.consequent, visitor, elseifPath, "consequent", cache)
		end
		visitToken(node.elseKeyword, visitor, ifExpressionPath, "elseKeyword", cache)
		visitExpression(node.antecedent, visitor, ifExpressionPath, "antecedent", cache)
	end
end

local function visitTypeOrPack(node: luau.AstType | luau.AstTypePack, visitor: Visitor, parent, id, cache)
	if node.tag == "explicit" or node.tag == "generic" or node.tag == "variadic" then
		visitTypePack(node, visitor, parent, id, cache)
	else
		visitType(node, visitor, parent, id, cache)
	end
end

local function visitTypeReference(node: luau.AstTypeReference, visitor: Visitor, parent, id, cache)
	local typeReferencePath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeReference(node) then
		if node.prefix then
			visitToken(node.prefix, visitor, typeReferencePath, "prefix", cache)
		end
		if node.prefixPoint then
			visitToken(node.prefixPoint, visitor, typeReferencePath, "prefixPoint", cache)
		end
		visitToken(node.name, visitor, typeReferencePath, "name", cache)
		if node.openParameters then
			visitToken(node.openParameters, visitor, typeReferencePath, "openParameters", cache)
		end
		if node.parameters then
			visitPunctuated(node.parameters, visitor, visitTypeOrPack, typeReferencePath, "parameters", cache)
		end
		if node.closeParameters then
			visitToken(node.closeParameters, visitor, typeReferencePath, "closeParameters", cache)
		end
	end
end

local function visitTypeBoolean(node: luau.AstTypeSingletonBool, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitTypeBoolean(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitTypeString(node: luau.AstTypeSingletonString, visitor: Visitor, parent, id, cache)
	path.registerPath(node, parent, id, cache)
	if visitor.visitTypeString(node) then
		visitToken(node, visitor, parent, id, cache)
	end
end

local function visitTypeTypeof(node: luau.AstTypeTypeof, visitor: Visitor, parent, id, cache)
	local typeTypeofPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeTypeof(node) then
		visitToken(node.typeof, visitor, typeTypeofPath, "typeof", cache)
		visitToken(node.openParens, visitor, typeTypeofPath, "openParens", cache)
		visitExpression(node.expression, visitor, typeTypeofPath, "expression", cache)
		visitToken(node.closeParens, visitor, typeTypeofPath, "closeParens", cache)
	end
end

local function visitTypeGroup(node: luau.AstTypeGroup, visitor: Visitor, parent, id, cache)
	local typeGroupPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeGroup(node) then
		visitToken(node.openParens, visitor, typeGroupPath, "openParens", cache)
		visitType(node.type, visitor, typeGroupPath, "type", cache)
		visitToken(node.closeParens, visitor, typeGroupPath, "closeParens", cache)
	end
end

local function visitTypeUnion(node: luau.AstTypeUnion, visitor: Visitor, parent, id, cache)
	local typeUnionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeUnion(node) then
		if node.leading then
			visitToken(node.leading, visitor, typeUnionPath, "leading", cache)
		end
		visitPunctuated(node.types, visitor, visitType, typeUnionPath, "types", cache)
	end
end

local function visitTypeIntersection(node: luau.AstTypeIntersection, visitor: Visitor, parent, id, cache)
	local typeIntersectionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeIntersection(node) then
		if node.leading then
			visitToken(node.leading, visitor, typeIntersectionPath, "leading", cache)
		end
		visitPunctuated(node.types, visitor, visitType, typeIntersectionPath, "types", cache)
	end
end

local function visitTypeArray(node: luau.AstTypeArray, visitor: Visitor, parent, id, cache)
	local typeArrayPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeArray(node) then
		visitToken(node.openBrace, visitor, typeArrayPath, "openBrace", cache)
		if node.access then
			visitToken(node.access, visitor, typeArrayPath, "access", cache)
		end
		visitType(node.type, visitor, typeArrayPath, "type", cache)
		visitToken(node.closeBrace, visitor, typeArrayPath, "closeBrace", cache)
	end
end

local function visitTypeTable(node: luau.AstTypeTable, visitor: Visitor, parent, id, cache)
	local typeTablePath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeTable(node) then
		visitToken(node.openBrace, visitor, typeTablePath, "openBrace", cache)
		local entriesPath = path.registerPath(node.entries, typeTablePath, "entries", cache)
		for ind, entry in node.entries do
			local entryPath = path.registerPath(entry, entriesPath, ind, cache)
			if entry.access then
				visitToken(entry.access, visitor, entryPath, "access", cache)
			end
			if entry.kind == "indexer" then
				visitToken(entry.indexerOpen, visitor, entryPath, "indexerOpen", cache)
				visitType(entry.key, visitor, entryPath, "key", cache)
				visitToken(entry.indexerClose, visitor, entryPath, "indexerClose", cache)
			elseif entry.kind == "stringproperty" then
				visitToken(entry.indexerOpen, visitor, entryPath, "indexerOpen", cache)
				visitTypeString(entry.key, visitor, entryPath, "key", cache)
				visitToken(entry.indexerClose, visitor, entryPath, "indexerClose", cache)
			else
				visitToken(entry.key, visitor, entryPath, "key", cache)
			end
			visitToken(entry.colon, visitor, entryPath, "colon", cache)
			visitType(entry.value, visitor, entryPath, "value", cache)
			if entry.separator then
				visitToken(entry.separator, visitor, entryPath, "separator", cache)
			end
		end
		visitToken(node.closeBrace, visitor, typeTablePath, "closeBrace", cache)
	end
end

local function visitTypeFunctionParameter(node: luau.AstTypeFunctionParameter, visitor, parent, id, cache)
	local typeFunctionParameterPath = path.registerPath(node, parent, id, cache)
	if node.name then
		visitToken(node.name, visitor, typeFunctionParameterPath, "name", cache)
	end
	if node.colon then
		visitToken(node.colon, visitor, typeFunctionParameterPath, "colon", cache)
	end
	visitType(node.type, visitor, typeFunctionParameterPath, "type", cache)
end

local function visitTypeFunction(node: luau.AstTypeFunction, visitor: Visitor, parent, id, cache)
	local typeFunctionPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypeFunction(node) then
		if node.openGenerics then
			visitToken(node.openGenerics, visitor, typeFunctionPath, "openGenerics", cache)
		end
		if node.generics then
			visitPunctuated(node.generics, visitor, visitGeneric, typeFunctionPath, "generics", cache)
		end
		if node.genericPacks then
			visitPunctuated(node.genericPacks, visitor, visitGenericPack, typeFunctionPath, "genericPacks", cache)
		end
		if node.closeGenerics then
			visitToken(node.closeGenerics, visitor, typeFunctionPath, "closeGenerics", cache)
		end
		visitToken(node.openParens, visitor, typeFunctionPath, "openParens", cache)
		visitPunctuated(node.parameters, visitor, visitTypeFunctionParameter, typeFunctionPath, "parameters", cache)
		if node.vararg then
			visitTypePack(node.vararg, visitor, typeFunctionPath, "vararg", cache)
		end
		visitToken(node.closeParens, visitor, typeFunctionPath, "closeParens", cache)
		visitToken(node.returnArrow, visitor, typeFunctionPath, "returnArrow", cache)
		visitTypePack(node.returnTypes, visitor, typeFunctionPath, "returnTypes", cache)
	end
end

local function visitTypePackExplicit(node: luau.AstTypePackExplicit, visitor: Visitor, parent, id, cache)
	local typePackExplicitPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypePackExplicit(node) then
		if node.openParens then
			visitToken(node.openParens, visitor, typePackExplicitPath, "openParens", cache)
		end
		visitPunctuated(node.types, visitor, visitType, typePackExplicitPath, "types", cache)
		if node.tailType then
			visitTypePack(node.tailType, visitor, typePackExplicitPath, "tailType", cache)
		end
		if node.closeParens then
			visitToken(node.closeParens, visitor, typePackExplicitPath, "closeParens", cache)
		end
	end
end

local function visitTypePackGeneric(node: luau.AstTypePackGeneric, visitor: Visitor, parent, id, cache)
	local typePackGenericPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypePackGeneric(node) then
		visitToken(node.name, visitor, typePackGenericPath, "name", cache)
		visitToken(node.ellipsis, visitor, typePackGenericPath, "ellipsis", cache)
	end
end

local function visitTypePackVariadic(node: luau.AstTypePackVariadic, visitor: Visitor, parent, id, cache)
	local typePackVariadicPath = path.registerPath(node, parent, id, cache)
	if visitor.visitTypePackVariadic(node) then
		if node.ellipsis then
			visitToken(node.ellipsis, visitor, typePackVariadicPath, "ellipsis", cache)
		end
		visitType(node.type, visitor, typePackVariadicPath, "type", cache)
	end
end

function visitExpression(expression: luau.AstExpr, visitor: Visitor, parent, id: string | number | nil, cache)
	path.registerPath(expression, parent, id, cache)
	if visitor.visitExpression(expression) then
		if expression.tag == "nil" then
			visitNil(expression, visitor, parent, id, cache)
		elseif expression.tag == "boolean" then
			visitBoolean(expression, visitor, parent, id, cache)
		elseif expression.tag == "number" then
			visitNumber(expression, visitor, parent, id, cache)
		elseif expression.tag == "string" then
			visitString(expression, visitor, parent, id, cache)
		elseif expression.tag == "local" then
			visitLocalReference(expression, visitor, parent, id, cache)
		elseif expression.tag == "global" then
			visitGlobal(expression, visitor, parent, id, cache)
		elseif expression.tag == "vararg" then
			visitVarargs(expression, visitor, parent, id, cache)
		elseif expression.tag == "call" then
			visitCall(expression, visitor, parent, id, cache)
		elseif expression.tag == "unary" then
			visitUnary(expression, visitor, parent, id, cache)
		elseif expression.tag == "binary" then
			visitBinary(expression, visitor, parent, id, cache)
		elseif expression.tag == "function" then
			visitAnonymousFunction(expression, visitor, parent, id, cache)
		elseif expression.tag == "table" then
			visitTable(expression, visitor, parent, id, cache)
		elseif expression.tag == "indexname" then
			visitIndexName(expression, visitor, parent, id, cache)
		elseif expression.tag == "index" then
			visitIndexExpr(expression, visitor, parent, id, cache)
		elseif expression.tag == "group" then
			visitGroup(expression, visitor, parent, id, cache)
		elseif expression.tag == "interpolatedstring" then
			visitInterpolatedString(expression, visitor, parent, id, cache)
		elseif expression.tag == "cast" then
			visitTypeAssertion(expression, visitor, parent, id, cache)
		elseif expression.tag == "conditional" then
			visitIfExpression(expression, visitor, parent, id, cache)
		else
			exhaustiveMatch(expression.tag)
		end

		visitor.visitExpressionEnd(expression)
	end
end

function visitStatement(statement: luau.AstStat, visitor: Visitor, parent, id, cache)
	path.registerPath(statement, parent, id, cache)
	if statement.tag == "block" then
		visitBlock(statement, visitor, parent, id, cache)
	elseif statement.tag == "conditional" then
		visitIf(statement, visitor, parent, id, cache)
	elseif statement.tag == "expression" then
		local exprStat = path.registerPath(statement, parent, id, cache)
		visitExpression(statement.expression, visitor, exprStat, "expression", cache)
	elseif statement.tag == "local" then
		visitLocalStatement(statement, visitor, parent, id, cache)
	elseif statement.tag == "return" then
		visitReturn(statement, visitor, parent, id, cache)
	elseif statement.tag == "while" then
		visitWhile(statement, visitor, parent, id, cache)
	elseif statement.tag == "break" then
		visitToken(statement, visitor, parent, id, cache)
	elseif statement.tag == "continue" then
		visitToken(statement, visitor, parent, id, cache)
	elseif statement.tag == "repeat" then
		visitRepeat(statement, visitor, parent, id, cache)
	elseif statement.tag == "for" then
		visitFor(statement, visitor, parent, id, cache)
	elseif statement.tag == "forin" then
		visitForIn(statement, visitor, parent, id, cache)
	elseif statement.tag == "assign" then
		visitAssign(statement, visitor, parent, id, cache)
	elseif statement.tag == "compoundassign" then
		visitCompoundAssign(statement, visitor, parent, id, cache)
	elseif statement.tag == "function" then
		visitFunction(statement, visitor, parent, id, cache)
	elseif statement.tag == "localfunction" then
		visitLocalFunction(statement, visitor, parent, id, cache)
	elseif statement.tag == "typealias" then
		visitTypeAlias(statement, visitor, parent, id, cache)
	elseif statement.tag == "typefunction" then
		visitStatTypeFunction(statement, visitor, parent, id, cache)
	else
		exhaustiveMatch(statement.tag)
	end
end

function visitType(type: luau.AstType, visitor: Visitor, parent, id, cache)
	if type.tag == "reference" then
		visitTypeReference(type, visitor, parent, id, cache)
	elseif type.tag == "boolean" then
		visitTypeBoolean(type, visitor, parent, id, cache)
	elseif type.tag == "string" then
		visitTypeString(type, visitor, parent, id, cache)
	elseif type.tag == "typeof" then
		visitTypeTypeof(type, visitor, parent, id, cache)
	elseif type.tag == "group" then
		visitTypeGroup(type, visitor, parent, id, cache)
	elseif type.tag == "union" then
		visitTypeUnion(type, visitor, parent, id, cache)
	elseif type.tag == "intersection" then
		visitTypeIntersection(type, visitor, parent, id, cache)
	elseif type.tag == "optional" then
		visitToken(type, visitor, parent, id, cache)
	elseif type.tag == "array" then
		visitTypeArray(type, visitor, parent, id, cache)
	elseif type.tag == "table" then
		visitTypeTable(type, visitor, parent, id, cache)
	elseif type.tag == "function" then
		visitTypeFunction(type, visitor, parent, id, cache)
	else
		exhaustiveMatch(type.tag)
	end
end

function visitTypePack(type: luau.AstTypePack, visitor: Visitor, parent, id, cache)
	if type.tag == "explicit" then
		visitTypePackExplicit(type, visitor, parent, id, cache)
	elseif type.tag == "generic" then
		visitTypePackGeneric(type, visitor, parent, id, cache)
	elseif type.tag == "variadic" then
		visitTypePackVariadic(type, visitor, parent, id, cache)
	else
		exhaustiveMatch(type.tag)
	end
end

local function createVisitor()
	return table.clone(defaultVisitor)
end

local function visitWithPaths(root, visitor, parent, id, cache)
	if ast.isExpression(root) then
		visitExpression(root, visitor, nil, nil, cache)
	elseif ast.isStatement(root) then
		visitStatement(root, visitor, nil, nil, cache)
	end
end

return {
	visitWithPaths = visitWithPaths,
	createVisitor = createVisitor,
	visitBlock = visitBlock,
	visitStatement = visitStatement,
	visitExpression = visitExpression,
	visitType = visitType,
	visitTypePack = visitTypePack,
	visitToken = visitToken,
}
