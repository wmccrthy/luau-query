local visitor = require("./commonUtils/pathVisitor")
local path = require("./path")

type Path<T> = path.Path<T>
type PathCache = path.PathCache

local Transformable = {}
Transformable.__index = Transformable

type TransformableData<T> = {
	selected: { T },
	metadataCache: PathCache,
}

type QueryCondition<T, V> = ((nodePath: Path<T>) -> V | nil) | nil

type Transformable<T> = typeof(setmetatable({} :: TransformableData<T>, Transformable))

function Transformable.new<T>(selected: { T }, metadataCache: PathCache): Transformable<T>
	local self = {}
	self.selected = selected
	self.metadataCache = metadataCache

	return setmetatable(self, Transformable)
end

function Transformable:operate<T>(node: T, operation: (nodePath: Path<T>) -> ()) -- generic function used to consolidate handling of nil metadata cache entries
	if self.metadataCache[node] then
		operation(self.metadataCache[node])
	end
end

--------- mutating, terminating (can change AST nodes, don't return chainable value) ---------
-- for performing deletion and insertion, it is necessary to iterate in reverse
-- so our updates don't affect the keys of remaining nodes mid-processing
function Transformable:forEach<T>(callback: (Path<T>) -> ())
	for i = #self.selected, 1, -1 do
		local node = self.selected[i]
		self:operate(node, callback)
	end
end

--------- non-mutating, non-terminating (don't change AST nodes, return chainable value) ---------
function Transformable:filter<T>(condition: (Path<T>) -> boolean): Transformable<T>
	local filtered = {}
	for _, node in self.selected do
		if condition(self.metadataCache[node]) then
			table.insert(filtered, node)
		end
	end
	return Transformable.new(filtered, self.metadataCache) -- use parent metadataCache to maintain widest scope
end

function Transformable:find<U, V>(
	override: string,
	condition: QueryCondition<U, V>
): Transformable<V> -- essentially performs a query on each node in the collection
	local foundSet = {}
	local returned = {}
	for _, node in self.selected do -- these nodes are of type T
		local res = query(node, override, condition, self.metadataCache) -- what we pass to condition is dependent on the override, thus why it is typed with U, not T
		for _, innerNode in res.selected do
			if not foundSet[innerNode] then
				table.insert(returned, innerNode)
				foundSet[innerNode] = true
			end
		end
	end
	return Transformable.new(returned, self.metadataCache) -- use parent metadataCache to maintain widest scope
end
-- easy to write additional find... methods that are more specific and require no override; much easier for users
-- so they don't have to memorize every "visit..." function
function Transformable:findExpression<V>(condition: QueryCondition<luau.AstExpr, V>): Transformable<V>
	return self:find("Expression", condition)
end
function Transformable:findCall<V>(condition: QueryCondition<luau.AstExprCall, V>): Transformable<V>
	return self:find("Call", condition)
end
function Transformable:findLocalFunction<V>(condition: QueryCondition<luau.AstStatLocalFunction, V>): Transformable<V>
	return self:find("LocalFunction", condition)
end
function Transformable:findFunction<V>(condition: QueryCondition<luau.AstStatFunction, V>): Transformable<V>
	return self:find("Function", condition)
end

function Transformable:parent(): Transformable<any>
	local parentSet, parents = {}, {}
	for _, node in self.selected do
		self:operate(node, function(nodePath)
			local parentPath = nodePath.parentPath
			if parentPath and not parentSet[parentPath.node] then
				parentSet[parentPath.node] = true
				table.insert(parents, parentPath.node)
			end
		end)
	end
	if #parents == 0 then
		error("Called parent() on highest level of scope; no parents available.")
	end
	return Transformable.new(parents, self.metadataCache)
end

function Transformable:map<T, V>(mappingCallback: (Path<T>) -> V): { V }
	local mappings = {}
	for _, node in self.selected do
		local nodeContext = self.metadataCache[node]
		table.insert(mappings, mappingCallback(nodeContext))
	end
	return mappings
end

--------- utility ---------
function Transformable:size()
	return #self.selected
end

-- Base Query; easily extendable and used to expose many basic/common query functions
function query<T, V>(
	src: luau.AstStat | luau.AstExpr,
	override: string,
	condition: QueryCondition<T, V>,
	cache: PathCache?
): Transformable<V>
	local queryVisitor = visitor.createVisitor()
	local selected = {}
	local metadataCache = cache
	if not metadataCache then
		metadataCache = {}
	end

	condition = condition or function(nodePath) -- fallback to default
		return nodePath.node
	end

	override = `visit{override}` -- simple but convenient touch

	queryVisitor[override] = function(node: T)
		local res = (condition :: (Path<T>) -> V | nil)(metadataCache[node])
		if res then
			if path.isPath(res) then
				-- It's a primitive or other data, so err
				error(`query selected a Path object. To select a node, return path.node instead.`)
			elseif typeof(res) ~= "table" then
				error(`query selected a non-node value. If you want to extract primitives, use :map().`)
			else
				table.insert(selected, res)
			end
		end
		return true
	end

	visitor.visitWithPaths(src, queryVisitor, nil, nil, metadataCache)

	return Transformable.new(selected, metadataCache)
end

function queryByExpression<T>(
	src: luau.AstStat | luau.AstExpr,
	condition: QueryCondition<luau.AstExpr, T>,
	cache: PathCache?
): Transformable<T>
	return query(src, "Expression", condition, cache)
end

local function queryByStatement<T>(
	src: luau.AstStat,
	condition: QueryCondition<luau.AstStat, T>,
	cache: PathCache?
): Transformable<T>
	-- need to implement manually since there is no overwritable visitStatement
	local queryVisitor = visitor.createVisitor()
	local metadataCache = cache
	if not metadataCache then
		metadataCache = {}
		-- createPathCache(metadataCache, src, nil, nil)
	end

	condition = condition or function(nodePath) -- fallback to default
		return nodePath.node
	end

	local selected = {}

	queryVisitor.visitBlockEnd = function(block: luau.AstStatBlock)
		for _, statement in block.statements do
			-- print(statement, metadataCache[statement])
			local res = (condition :: (Path<luau.AstStat>) -> T | nil)(metadataCache[statement])
			if res then
				if path.isPath(res) then
					-- It's a primitive or other data, so err
					error(`query selected a Path object. To select a node, return path.node instead.`)
				elseif typeof(res) ~= "table" then
					error(`query selected a non-node value. If you want to extract primitives, use :map().`)
				else
					table.insert(selected, res)
				end
			end
		end
	end

	visitor.visitStatement(src, queryVisitor, nil, nil, metadataCache)

	return Transformable.new(selected, metadataCache)
end

-- Some common queries that are not as generic as the above, but very common
function queryByCallExpression<T>(
	src: luau.AstStat | luau.AstExpr,
	condition: QueryCondition<luau.AstExprCall, T>,
	cache: PathCache?
): Transformable<T>
	return query(src, "Call", condition, cache)
end

local function queryByCallStatement<T>(
	src: luau.AstStat | luau.AstExpr,
	condition: QueryCondition<luau.AstStat, T>,
	cache: PathCache?
): Transformable<T>
	condition = condition or function(nodePath)
		return nodePath.node
	end

	return queryByStatement(src, function(nodePath)
		local node = nodePath.node
		if node.tag ~= "expression" then
			return nil
		end
		if node.expression.tag ~= "call" then
			return nil
		end
		return (condition :: (Path<luau.AstStat>) -> T | nil)(nodePath)
	end, cache)
end

function queryByTableItem<T>(
	src: luau.AstStat | luau.AstExpr,
	condition: QueryCondition<luau.AstExprTableItem, T>,
	cache: PathCache?
): Transformable<T>
	return query(src, "TableItem", condition, cache)
end

function queryByFunction<T>(
	src: luau.AstStat | luau.AstExpr,
	condition: QueryCondition<luau.AstStatFunction, T>,
	cache: PathCache?
): Transformable<T>
	return query(src, "Function", condition, cache)
end

local queryCollection = {
	query = query, -- easily overwritten for specific cases (i.e for very specific node type, no point in implementing all here)
	byExpression = queryByExpression,
	byStatement = queryByStatement,
	byCallExpression = queryByCallExpression,
	byCallStatement = queryByCallStatement,
	byTableItem = queryByTableItem,
	byFunction = queryByFunction,
	-- add on
}

setmetatable(queryCollection, {
	__call = function(self, ...)
		return self.query(...)
	end,
})

return queryCollection
