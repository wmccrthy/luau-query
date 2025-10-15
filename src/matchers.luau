local ast = require("./commonUtils/common")
local path = require("./path")
type Path<T> = path.Path<T>

-- Some common helpers for working with Path objects;
-- Ideally simplifies the verbosity of writing manual callbacks and cover common cases

function negate<T>(condition: (Path<T>) -> boolean): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return not condition(nodePath)
	end
end

function any<T>(...: (Path<T>) -> boolean): (Path<T>) -> boolean
	local predicates = { ... }
	return function(nodePath: Path<T>)
		for _, predicate in predicates do
			if predicate(nodePath) then
				return true
			end
		end
		return false
	end
end

-- combining 'has' conditions in more concise way
function all<T>(...: (Path<T>) -> boolean): (Path<T>) -> boolean
	local predicates = { ... }
	return function(nodePath: Path<T>)
		for ind, predicate in predicates do
			if not predicate(nodePath) then
				return false
			end
		end
		return true
	end
end

-- has: broader, for checking a node's contents and relationships. not for specific node state/identity
local has = {}

-- generic helpers, usable on any path
function has.ancestor<T>(condition: (Path<any>) -> boolean): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return nodePath:findFirstAncestor(condition) ~= nil
	end
end

function has.tag<T>(tag: string): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return nodePath.node.tag and nodePath.node.tag == tag
	end
end

function has.id<T>(id: string | number): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		-- once we have parent support built into AST, we can do
		-- return nodePath.node.parent[id] == nodePath.node

		return nodePath.id == id
	end
end

function has.property<T>(property: string, value: any?): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		if nodePath.node[property] then
			return value == nil or nodePath.node[property] == value
		end
		return false
	end
end

function has.propertyDeep<T>(path: { string | number }, value: any?): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		local cur = nodePath.node
		for _, ind in path do
			cur = cur[ind] 
			if not cur then
				return false
			end
		end
		return cur ~= nil
	end
end

function has.descendant<T>(condition: (Path<any>) -> boolean): (Path<T>) -> boolean
	return function(nodePath)
		return nodePath:findFirstDescendant(condition) ~= nil
	end
end

-- similar applications to text matching, but a little more precise;
function has.token<T>(matcher: string): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return nodePath:findFirstDescendant(all(has.property("text", matcher), has.property("position"))) ~= nil
	end
end

-- more specific "has" helpers, only applicable on paths with certain node types

function has.argument(
	ind: number,
	condition: (Path<any>) -> boolean
): (Path<luau.AstExprCall>) -> boolean -- used on call nodes
	return function(nodePath)
		if not has.tag("call")(nodePath) then
			return false
		end
		local arg = nodePath:get(nodePath.node.arguments[ind].node)
		if not arg then
			return false
		end
		return condition(arg)
	end
end

function has.name(name: string): (Path<luau.AstLocal | luau.AstExprGlobal>) -> boolean
	return function(nodePath)
		local pathName = nodePath:name()
		return if pathName then pathName == name else false
	end
end

-- is: more specific, for checking a node's identity and state
local is = {}

local function getCommonFunctionName( -- gets name from most common function naming conventions
	func: luau.AstExprIndexName | luau.AstExprIndexExpr | luau.AstExprGlobal | luau.AstLocal
): string | nil
	local funcName = if func.name
		then func.name.text
		elseif func.tag == "indexname" then func.index.text
		elseif func.tag == "local" then func.token.text
		else nil
	return funcName
end

type FunctionNode = luau.AstExprCall | luau.AstStatFunction | luau.AstStatLocalFunction
local function isFunctionGeneric(node: FunctionNode, expectedTag, name: string?)
	local isTag = node.tag == expectedTag
	if not isTag then
		return false
	end
	if not name then
		return true
	end
	local funcName = getCommonFunctionName(if node.tag == "call" then node.func else node.name)
	return funcName == name
end

function is.call<T>(functionName: string?): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return isFunctionGeneric(nodePath.node, "call", functionName)
	end
end

function is.globalFunction<T>(functionName: string?): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return isFunctionGeneric(nodePath.node, "function", functionName)
	end
end

function is.localFunction<T>(functionName: string?): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return isFunctionGeneric(nodePath.node, "localfunction", functionName)
	end
end

function is.localDeclaration<T>(): (Path<T>) -> boolean
	return all(has.tag("local"), has.property("variables"))
end

function is.localReference<T>(varName: string?): (Path<T>) -> boolean -- finds AstExprLocal nodes
	return if varName
		then all(has.tag("local"), has.property("token"), function(nodePath: Path<T>)
			return (nodePath :: any).node.token.text == varName
		end)
		else all(has.tag("local"), has.property("token"))
end

function is.globalReference<T>(varName: string?): (Path<T>) -> boolean
	return if varName
		then all(has.tag("global"), function(nodePath: Path<T>)
			return (nodePath :: any).node.name.text == varName
		end)
		else has.tag("global")
end

function is.indexName<T>(parts: { string }): (Path<T>) -> boolean
	return function(nodePath: Path<T>)
		return has.tag("indexname")(nodePath) and ast._matchesPathTable(nodePath.node, parts)
	end
end

function is.nthChild<T>(n: number): (Path<T>) -> boolean
	return function(nodePath)
		if not nodePath.parentPath then
			error(`Calling is.nthChild on path with no parent.`)
		end
		return if tonumber(nodePath.id) then nodePath.id == n else false
	end
end

return {
	has = has,
	is = is,
	any = any,
	all = all,
	negate = negate,
}
