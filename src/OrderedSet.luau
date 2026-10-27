--!strict

-- Preserve the existing collection's storage and public API. Its forEach
-- captures an initial array length, so dispatch needs a stable live ledger.
local Undefined, Nan = table.freeze({}), table.freeze({})
type Entry = { key: any, live: boolean }
type Ledger = { entries: { [any]: Entry }, order: { Entry } }
type State = { base: any, iterators: { [any]: Ledger }, objects: { [any]: any } }
local OrderedSet = {}
local methods = {} :: any

local function key(self: State, value: any, create: boolean): any
	if value == nil then
		return Undefined
	end
	if type(value) == "number" then
		if value ~= value then
			return Nan
		end
		if value == 0 then
			return 0
		end
	end
	if type(value) == "table" then
		-- The underlying collection deletes with table.find, which can invoke
		-- __eq. Private tokens keep distinct source objects distinct there too.
		local token = self.objects[value]
		if not token and create then
			token = table.freeze({ value = value })
			self.objects[value] = token
		end
		return token
	end
	return value
end
local function value(keyValue: any): any
	if rawequal(keyValue, Undefined) then
		return nil
	end
	if rawequal(keyValue, Nan) then
		return 0 / 0
	end
	if type(keyValue) == "table" then
		return keyValue.value
	end
	return keyValue
end
local function append(ledger: Ledger, item: any)
	local entry = { key = item, live = true }
	ledger.entries[item] = entry
	table.insert(ledger.order, entry)
end
function methods.add(self: State, item: any): any
	local normalized = key(self, item, true)
	local exists = self.base:has(normalized)
	self.base:add(normalized)
	if not exists then
		for _, ledger in self.iterators do
			append(ledger, normalized)
		end
	end
	return self
end
function methods.delete(self: State, item: any): boolean
	local normalized = key(self, item, false)
	if normalized == nil then
		return false
	end
	local removed = self.base:delete(normalized)
	if removed and type(item) == "table" then
		self.objects[item] = nil
	end
	if removed then
		for _, ledger in self.iterators do
			local entry = ledger.entries[normalized]
			if entry then
				entry.live, entry.key = false, nil
				ledger.entries[normalized] = nil
			end
		end
	end
	return removed
end
function methods.has(self: State, item: any): boolean
	local normalized = key(self, item, false)
	return normalized ~= nil and self.base:has(normalized)
end
function methods.clear(self: State)
	self.base:clear()
	table.clear(self.objects)
	for _, ledger in self.iterators do
		for _, entry in ledger.entries do
			entry.live, entry.key = false, nil
		end
		table.clear(ledger.entries)
	end
end

local function cursor(self: State): (() -> (boolean, any), () -> ())
	local token = {}
	local ledger: Ledger = { entries = {}, order = {} }
	self.base:forEach(function(item: any)
		append(ledger, item)
	end)
	self.iterators[token] = ledger
	local owner: State? = self
	local index = 1
	local function release()
		if owner then
			owner.iterators[token] = nil
			owner = nil
		end
		table.clear(ledger.entries)
		table.clear(ledger.order)
	end
	return function(): (boolean, any)
		if owner then
			while index <= #ledger.order do
				local entry = ledger.order[index]
				index += 1
				if entry.live then
					return true, value(entry.key)
				end
			end
			release()
		end
		return false, nil
	end,
		release
end

function methods.values(self: State): any
	-- Weak keys let an abandoned iterator disappear without a close callback
	-- from Lua's generic-for loop. The ledger never retains its ownership token.
	local step = cursor(self)
	return {
		next = function()
			local present, item = step()
			return if present then { done = false, value = item } else { done = true }
		end,
	}
end

function methods.forEach(self: State, callback: (any, any, any) -> ())
	assert(type(callback) == "function", "Set.forEach requires a callback")
	local step, release = cursor(self)
	local ok, failure = pcall(function()
		while true do
			local present, item = step()
			if not present then
				break
			end
			callback(item, item, self)
		end
	end)
	release()
	if not ok then
		error(failure, 0)
	end
end
function OrderedSet.create(baseSet: any): { new: <T>() -> any }
	assert(
		type(baseSet) == "table" and type(baseSet.new) == "function",
		"Set adapter requires a collection constructor"
	)
	local construct: () -> any = baseSet.new :: any
	local metatable = {
		__index = function(self: State, name: string): any
			return if name == "size" then self.base.size else methods[name]
		end,
	}
	return {
		new = function<T>(): any
			return setmetatable(
				{ base = construct(), iterators = setmetatable({}, { __mode = "k" }), objects = {} },
				metatable
			)
		end,
	}
end
return OrderedSet
