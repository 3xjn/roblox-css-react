--!strict
-- Source collections use SameValueZero identity and insertion order. Deleted
-- entries are unlinked immediately; live iterator cursors advance on deletion
-- and accept later insertions until they have actually reported completion.
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local Properties = require(script.Parent.Properties)
local SourceType = require(script.Parent.SourceType)
local Records = require(script.Parent.Records)
local Symbols = require(script.Parent.SourceSymbols)
local Collections = {}
local undefinedKey, nanKey = {}, {}
type Entry = { key: any, value: any, previous: Entry?, following: Entry? }
type Cursor = { following: Entry? }
type State = {
	head: Entry?, tail: Entry?, index: { [any]: Entry }, size: number, kind: string,
	cursors: { [Cursor]: boolean },
}
-- The identity registry never owns collection data. State lives in the
-- owner's private metatable so map.set(map, map) is an ordinary collectable
-- cycle, rather than a weak-key registry value retaining its own key.
local identities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local stateToken = {}
local propertiesToken, methodsToken = {}, {}
local function keyOf(key: any): any
	if key == nil then return undefinedKey end
	if type(key) == "number" and key ~= key then return nanKey end
	return key
end
local function stateOf(owner: any): State
	assert(identities[owner], "Source collection method called with an incompatible receiver")
	return (getmetatable(owner) :: any)[stateToken]
end
local function canonical(key: any): any
	return if type(key) == "number" and key == 0 then 0 else key
end
local function set(owner: any, key: any, value: any): any
	local state = stateOf(owner)
	local token = keyOf(key)
	local previous = state.index[token]
	if previous then previous.value = value; return owner end
	local entry: Entry = { key = canonical(key), value = value, previous = state.tail }
	if state.tail then state.tail.following = entry else state.head = entry end
	state.tail = entry
	state.index[token] = entry
	state.size += 1
	for cursor in state.cursors do
		if not cursor.following then cursor.following = entry end
	end
	return owner
end
local function delete(owner: any, key: any): boolean
	local state = stateOf(owner)
	local token = keyOf(key)
	local entry = state.index[token]
	if not entry then return false end
	state.index[token] = nil
	if entry.previous then entry.previous.following = entry.following else state.head = entry.following end
	if entry.following then entry.following.previous = entry.previous else state.tail = entry.previous end
	for cursor in state.cursors do
		if cursor.following == entry then cursor.following = entry.following end
	end
	entry.key, entry.value, entry.previous, entry.following = nil, nil, nil, nil
	state.size -= 1
	return true
end
local function iteratorFor(owner: any, mode: string): any
	local state: State? = stateOf(owner)
	local cursor: Cursor = { following = (state :: State).head }
	(state :: State).cursors[cursor] = true
	return { close = function()
		if state then state.cursors[cursor] = nil end
		state, cursor.following = nil, nil
	end, next = function(_self: any?): any
		local active = state
		if active then
			local entry = cursor.following
			if entry then
				cursor.following = entry.following
				local value = if mode == "keys" then entry.key elseif mode == "values" then entry.value
					else Arrays.adopt({ entry.key, entry.value }, 2)
				return { done = false, value = value }
			end
			active.cursors[cursor] = nil
			state = nil
		end
		return { done = true }
	end }
end
function Collections.iterator(value: any): any
	if Arrays.owns(value) then return Arrays.values(value) end
	local state = if identities[value] then stateOf(value) else nil
	if state then return iteratorFor(value, if state.kind == "set" then "values" else "entries") end
	assert(type(value) == "table" and type(value.next) == "function", "Value requires a supported source iterable")
	return value
end
local function consume(input: any, visit: (any) -> ())
	if Nulls.isNullish(input) then return end
	local iterator = Collections.iterator(input)
	while true do
		local item = iterator.next(iterator)
		if item.done then return end
		visit(item.value)
	end
end
local sharedProperties = { size = true, has = true, delete = true, clear = true, keys = true,
	values = true, entries = true, iterator = true, forEach = true }
local function mapProperty(key: any): boolean
	return sharedProperties[key] == true or key == "get" or key == "set"
end
local function setProperty(key: any): boolean
	return sharedProperties[key] == true or key == "add"
end
local function make(kind: string, initial: any): any
	local owner: { [any]: any } = {}
	local state: State = { index = {}, size = 0, kind = kind, cursors = setmetatable({}, { __mode = "k" }) :: any }
	identities[owner] = true
	setmetatable(owner, { [stateToken] = state, [propertiesToken] = Records.adopt({}, {}), __index = function(self: any, key: string): any
		return if key == "size" then stateOf(self).size else nil
	end, __newindex = function(self: any, key: any, value: any)
		assert(key ~= "size", "Collection size is read-only")
		rawset(self, key, value)
	end })
	owner.has = function(self: any, key: any): boolean return stateOf(self).index[keyOf(key)] ~= nil end
	owner.delete = delete
	owner.clear = function(self: any)
		local state = stateOf(self)
		local entry = state.head
		while entry do
			local following = entry.following
			entry.key, entry.value, entry.previous, entry.following = nil, nil, nil, nil
			entry = following
		end
		for cursor in state.cursors do cursor.following = nil end
		state.head, state.tail, state.size = nil, nil, 0
		table.clear(state.index)
	end
	owner.keys = function(self: any): any return iteratorFor(self, "keys") end
	owner.values = function(self: any): any return iteratorFor(self, "values") end
	owner.entries = function(self: any): any return iteratorFor(self, "entries") end
	owner.iterator = if kind == "set" then owner.values else owner.entries
	owner.forEach = function(self: any, callback: (any, any, any) -> ())
		assert(type(callback) == "function", "Collection forEach requires a callback")
		local iterator = iteratorFor(self, "entries")
		local ok, problem = pcall(function()
			while true do
				local item = iterator:next()
				if item.done then return end
				callback(item.value[2], item.value[1], self)
			end
		end)
		iterator.close()
		if not ok then error(problem, 0) end
	end
	Properties.register(owner, if kind == "set" then setProperty else mapProperty)
	if kind == "set" then
		owner.add = function(self: any, value: any): any return set(self, value, canonical(value)) end
		owner.keys = owner.values
		local nativeMeta = getmetatable(owner) :: any
		nativeMeta[methodsToken] = table.clone(owner)
		consume(initial, function(value: any) owner:add(value) end)
	else
		owner.set = set
		owner.get = function(self: any, key: any): any
			local entry = stateOf(self).index[keyOf(key)]
			return if entry then entry.value else nil
		end
		local nativeMeta = getmetatable(owner) :: any
		nativeMeta[methodsToken] = table.clone(owner)
		consume(initial, function(pair: any)
			assert(Arrays.owns(pair), "Map constructor entries must be adopted source array pairs")
			owner:set(pair[1], pair[2])
		end)
	end
	return owner
end
local function weakKey(key: any): boolean
	if SourceType.typeOf(key) == "symbol" then return Symbols.Symbol.keyFor(key) == nil end
	return not Nulls.isNullish(key) and (type(key) == "table" or type(key) == "function" or type(key) == "userdata")
end
local weakIdentities: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local weakStateToken = {}
local weakKindToken = {}
local function weakState(owner: any, expected: string): { [any]: { value: any } }
	assert(weakIdentities[owner] and (getmetatable(owner) :: any)[weakKindToken] == expected,
		"Weak collection method called with an incompatible receiver")
	return (getmetatable(owner) :: any)[weakStateToken]
end
local function makeWeak(kind: string, initial: any): any
	local owner: { [any]: any } = {}
	weakIdentities[owner] = true
	setmetatable(owner, { [weakKindToken] = kind, [weakStateToken] = setmetatable({}, { __mode = "k" }) :: any,
		[propertiesToken] = Records.adopt({}, {}) })
	if kind == "weakmap" then
		owner.set = function(self: any, key: any, value: any): any
			local state = weakState(self, kind)
			assert(weakKey(key), "WeakMap keys must be non-null source objects or non-registered symbols")
			state[key] = { value = value }
			return self
		end
		owner.get = function(self: any, key: any): any
			local state = weakState(self, kind)
			local entry = if weakKey(key) then state[key] else nil
			return if entry then entry.value else nil
		end
	else
		owner.add = function(self: any, key: any): any
			local state = weakState(self, kind)
			assert(weakKey(key), "WeakSet values must be non-null source objects or non-registered symbols")
			state[key] = { value = true }
			return self
		end
	end
	owner.has = function(self: any, key: any): boolean
		local state = weakState(self, kind)
		return weakKey(key) and state[key] ~= nil
	end
	owner.delete = function(self: any, key: any): boolean
		local state = weakState(self, kind)
		if not weakKey(key) or not state[key] then return false end
		state[key] = nil
		return true
	end
	local nativeMeta = getmetatable(owner) :: any
	nativeMeta[methodsToken] = table.clone(owner)
	consume(initial, function(value: any)
		if kind == "weakset" then owner:add(value)
		else
			assert(Arrays.owns(value), "WeakMap constructor entries must be adopted source array pairs")
			owner:set(value[1], value[2])
		end
	end)
	return owner
end
local constructorStateToken = {}
local function constructor(factory: (any) -> any): any
	local state: any = { factory = factory, projection = nil }
	local value = setmetatable({}, { [constructorStateToken] = state, __index = function(_owner: any, key: any): any
		if state.projection then
			if key == "new" then return state.projection.new end
			if key == "instanceof" then return state.projection.instanceof end
			return state.projection.fields[key]
		end
		return if key == "new" then state.factory else nil
	end })
	return SourceType.register(table.freeze(value), "function")
end
Collections.Map = constructor(function(initial: any): any return make("map", initial) end)
Collections.Set = constructor(function(initial: any): any return make("set", initial) end)
Collections.WeakMap = constructor(function(initial: any): any return makeWeak("weakmap", initial) end)
Collections.WeakSet = constructor(function(initial: any): any return makeWeak("weakset", initial) end)
function Collections.empty(value: any): any
	local state = (getmetatable(value) :: any)[constructorStateToken]
	assert(state, "Native collection constructor identity required")
	return state.factory(nil)
end
function Collections.bindConstructor(value: any, projection: any)
	local state = (getmetatable(value) :: any)[constructorStateToken]
	assert(state and not state.projection, "Native collection constructor already bound or invalid")
	state.projection = projection
end
function Collections.constructorFields(value: any): any
	return assert((getmetatable(value) :: any)[constructorStateToken].projection, "Unbound collection constructor").fields
end
function Collections.kind(value: any): string?
	if identities[value] then return stateOf(value).kind end
	return if weakIdentities[value] then (getmetatable(value) :: any)[weakKindToken] else nil
end
function Collections.canBeHeldWeakly(value: any): boolean return weakKey(value) end
function Collections.properties(value: any): any
	assert(Collections.kind(value), "Source collection property access requires a collection")
	return (getmetatable(value) :: any)[propertiesToken]
end
function Collections.method(value: any, name: string): any
	assert(Collections.kind(value), "Source collection method access requires a collection")
	return (getmetatable(value) :: any)[methodsToken][name]
end
return Collections
