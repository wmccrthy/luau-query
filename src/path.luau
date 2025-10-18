local Path = {}
Path.__index = Path

export type PathData<T> = {
	node: T, -- stupid to have intersection, but type solver gets mad
	parentPath: any?, -- in practice, this will be PathData<any>, but type solver gets mad
	id: string? | number?,
	_cache: any, -- store reference to full metadataCache for easy navigation (type is PathCache, but type solver gets mad)
}

export type Path<T> = typeof(setmetatable({} :: PathData<T>, Path))

export type PathCache = {
	[any]: Path<any>,
}

-- helper methods that update pathCache on the fly when we make additions/deletions to tree
local function removeCacheNode(node, cache)
	if typeof(node) ~= "table" then
		return
	end

	cache[node] = nil
	for k, v in node do
		if k ~= "local" then -- dont want to remove local referebce nodes since they exist elsewhere in the tree
			removeCacheNode(v, cache)
		end
	end
end

local function safeInsert(t: { any }, k, v, cache, parent): number
	-- AstExprLocal (local references) contain a "local" child, which points back to the declaration node
	-- This can create confusing behavior to end-user if they find a descendant/ancestor that is this "local" node (since it points to different location in tree)
	-- So we omit these from our find descendant methods
	if k == "local" or typeof(v) ~= "table" then
		return 0
	end
	table.insert(t, v)
	registerPath(v, parent, k, cache)
	return 1
end

function Path.new<T>(node: T, parentPath: Path<any> | nil, id: string | number | nil, cache: PathCache)
	local self = {}
	self.node = node
	self.parentPath = parentPath
	self.id = id
	self._cache = cache

	return setmetatable(self, Path)
end

function Path:get<T>(node: T): Path<T>?
	return self._cache[node]
end

function nullPath(): Path<nil>
	return Path.new(nil, nil, nil, {})
end

function Path:getDescendantAt<T>(...: string | number): Path<T>
	local cur, parent = self.node, self
	local path = { ... }
	for _, ind in path do
		cur = cur[ind]
		if not cur then
			error("Invalid path given to getDescendantAt")
		end
		-- create paths as we traverse; (in case they are not already created, since visitor creates them in pre-order)
		parent = registerPath(cur, parent, ind, self._cache)
	end
	local descendant = self._cache[cur]
	if not descendant then
		error("Invalid path given to getDescendantAt")
	end
	return descendant
end

function Path:findFirstAncestor(condition: (Path<any>) -> boolean): Path<any>
	local ancestorPath = self.parentPath
	-- once/if parent support is built into AST
	-- local parent = self.node.parent
	-- local parentPath = registerPath(parent, nil, nil, self._cache)
	-- self.parentPath = parentPath
	-- will do this lazily, as we traverse up (only create parent Path when we actually need it / read it)

	while ancestorPath do
		if condition(ancestorPath) then
			return ancestorPath
		end
		ancestorPath = ancestorPath.parentPath
	end
	return nullPath()
end

function Path:findFirstDescendant(condition: (Path<any>) -> boolean): Path<any>
	local q, len = {}, 0
	for k, v in self.node do
		len += safeInsert(q, k, v, self._cache, self)
	end
	while len > 0 do
		len = 0
		local newQ = {}
		for k, v in q do
			if typeof(v) ~= "table" then
				continue
			end
			-- print("Checking path:", k, v)
			local path = self._cache[v]
			if condition(path) then
				return path
			else
				for k2, v2 in path.node do
					len += safeInsert(newQ, k2, v2, self._cache, path)
				end
			end
		end
		q = newQ
	end
	return nullPath()
end

function Path:findDescendants(condition: (Path<any>) -> boolean): { Path<any> }
	local found = {}
	local function traverse(node, key, parent)
		if typeof(node) ~= "table" then
			return
		end
		registerPath(node, parent, key, self._cache)
		local path = self._cache[node]
		if condition(path) then
			-- safeInsert(found, key, path)
			if key ~= "local" then
				table.insert(found, path)
			end
		end
		for _, v in node do
			traverse(v)
		end
	end
	for k, v in self.node do
		traverse(v, k, self)
	end
	return found
end

function Path:delete()
	if self.parentPath then
		local parent = self.parentPath.node
		if #parent then
			-- remove self (and descendants) from cache, update ids of parent's other children
			removeCacheNode(self.node, self._cache)
			table.remove(parent, self.id)
			for i = self.id, #parent do
				local child = parent[i]
				local childPath = self._cache[child]
				childPath.id = i
			end
		else
			error("Trying to delete in a non-array node; no changes will take effect.")
		end
	end
end

function Path:replace<T, V>(replacement: (Path<T>) -> V)
	if self.parentPath then
		local parent = self.parentPath.node
		local newNode = replacement(self)
		-- remove old node from cache (and all it's descendants)
		removeCacheNode(self.node, self._cache)
		parent[self.id] = newNode
		-- add new node to cache
		createPathCache(self._cache, newNode, self.parentPath, self.id)
		self.node = parent[self.id] -- need to update self path, since we have replaced node
	end
end

function Path:insert<T, V>(toInsert: (Path<T>) -> V, index: number, contextPath: Path<T>?)
	if #self.node then
		local insertedNode = toInsert(contextPath or self)
		-- add new node to cache
		createPathCache(self._cache, insertedNode, self, index)
		table.insert(self.node, index, insertedNode)
		for i = index + 1, #self.node do -- all nodes at indices > index we inserted at need to update ID
			local child = self.node[i]
			local childPath = self._cache[child]
			childPath.id = i
		end
	else
		error("Trying to insert in a non-array node; no changes will take effect.")
	end
end

function Path:insertBefore<T, V>(toInsert: (Path<T>) -> V) -- to insert before/after, we need parent context
	if self.id and tonumber(self.id) then
		if self.parentPath then
			self.parentPath:insert(toInsert, self.id, self)
		end
	end
end

function Path:insertAfter<T, V>(toInsert: (Path<T>) -> V) -- to insert before/after, we need parent context
	if self.id and tonumber(self.id) then
		if self.parentPath then
			self.parentPath:insert(toInsert, self.id + 1, self)
		end
	end
end

-- utility
function Path:print(depth: number?)
	depth = depth or 0
	local indent = string.rep(" ", depth :: number)
	print(`{indent}{self.id}:`)
	for k, v in self.node do
		if typeof(v) ~= "table" then
			print(`{indent}{k}: {v}`)
		else
			local path = self._cache[v]
			path:print((depth :: number) + 1)
		end
	end
end

function Path:name(): string? -- only applicable to global/local declaration/reference nodes
	local isAstExprLocal = self.node.tag and self.node.tag == "local" and self.node.token -- local reference
	local isAstLocal = self.node.name and self.node.name.text
	local isGlobal = self.node.tag == "global"
	if isAstExprLocal then
		return self.node.token.text
	elseif isAstLocal or isGlobal then
		return self.node.name.text
	end
	return nil
end

-- unfortunate to require a second pass, but we call this at the start
-- of query calls. walks tree and fills cache so we have Path object for each node
-- and can access full tree context/navigation in query callbacks
-- TO-DO: can we refactor visitor to pass this data down by default
function createPathCache(cache: PathCache, node: any, parentPath: Path<any> | nil, id: string | number | nil)
	if type(node) ~= "table" then
		return
	end

	if cache[node] then -- local references will contain upvalue reference back to original declaration node; cannot have duplicates in the path cache
		return
	end

	local nodePath = Path.new(node, parentPath, id, cache)
	cache[node] = nodePath

	for k, v in node do
		createPathCache(cache, v, nodePath, k)
	end
end

function registerPath(node, parentPath, id, cache)
	if not cache[node] then
		local nodePath = Path.new(node, parentPath, id, cache)
		cache[node] = nodePath
	end
	return cache[node]
end

-- used to protect against queries returning a path
local function isPath(node: any)
	return node.node and node._cache
end

return {
	createPathCache = createPathCache,
	isPath = isPath,
	registerPath = registerPath,
}
