--!strict

-- Ordinary own data properties; the record remains the application's table.
-- Only presence/order live in weak metadata. Reads do not allocate wrappers.
type Entry = { key: any, index: number, captured: boolean?, value: any, rawKey: any, getter: (() -> any)? }
type Ledger = { order: { Entry }, present: { [any]: Entry } }
local Records = {}
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local SourceType = require(script.Parent.SourceType)
local prototypeToken = {}
-- User values belong to the owner itself, never a value in weak-key metadata.
-- Keeping descriptors in its private metatable makes owner/value cycles collectible.
local descriptorsToken, receiverToken, tagToken, nonextensibleToken = {}, {}, {}, {}
local nativePropertiesToken = {}
local readHook: any, writeHook: any, callHook: any, faultHook: any = nil, nil, nil, nil
function Records.configure(read: any, write: any, call: any, fault: any)
	readHook, writeHook, callHook, faultHook = read, write, call, fault
end
local function fault(message: string): never
	if faultHook then (faultHook :: any)("TypeError", message) end
	error(message, 2)
end
local function privateMeta(record: any): any
	local meta = table.clone(getmetatable(record) :: any)
	setmetatable(record, meta)
	return meta
end
function Records.setReceiver(record: any, receiver: any) privateMeta(record)[receiverToken] = receiver end
function Records.receiver(record: any): any return (getmetatable(record) :: any)[receiverToken] or record end
function Records.setTag(record: any, tag: string) privateMeta(record)[tagToken] = tag end
function Records.tag(record: any): string? return (getmetatable(record) :: any)[tagToken] end
function Records.extensible(record: any): boolean return not table.isfrozen(record) and not (getmetatable(record) :: any)[nonextensibleToken] end
function Records.preventExtensions(record: any) privateMeta(record)[nonextensibleToken] = true end
-- Native SDK constructor/instanceof views are not JavaScript own properties.
-- A source property using the same spelling remains in descriptor storage.
function Records.nativeProperty(record: any, key: string, value: any)
	local meta = privateMeta(record)
	local views = meta[nativePropertiesToken]
	if not views then views = {}; meta[nativePropertiesToken] = views end
	views[key] = value
	local desc = Records.descriptor(record, key)
	if desc then Records.defineDescriptor(record, key, desc) end
end
local metadata: { [any]: Ledger } = setmetatable({}, { __mode = "k" })
function Records.owns(value: any): boolean
	return metadata[value] ~= nil
end
local constructions: { [any]: boolean } = setmetatable({}, { __mode = "k" })
local Empty = table.freeze({})

local function normalize(key: any): any
	if type(key) == "string" then
		return key
	end
	if SourceType.typeOf(key) == "symbol" then return key end
	assert(type(key) == "number", "Record keys require strings or numbers; symbols and object coercion need a provider")
	if key ~= key then return "NaN" end
	if key == math.huge then return "Infinity" end
	if key == -math.huge then return "-Infinity" end
	assert(key % 1 == 0 and math.abs(key) <= 9007199254740991, "Non-safe-integer record keys need JavaScript NumberToString")
	return if key == 0 then "0" else string.format("%.0f", key)
end
Records.propertyKey = normalize
function Records.keyString(key: any): string
	local result = normalize(key)
	assert(type(result) == "string", "A symbol property key is not a string")
	return result
end
local function ledger(record: any): Ledger
	local result = metadata[record]
	assert(result, "Native records need adoption with their explicit source key order")
	return result
end
local function construction(token: any): Ledger
	assert(constructions[token], "Record construction is absent or already finished")
	return token
end
local function append(state: Ledger, key: any): Entry
	local entry = state.present[key]
	if not entry then
		local created: Entry = { key = key, index = #state.order + 1, value = nil, rawKey = nil }
		entry = created
		state.present[key] = entry
		table.insert(state.order, entry)
	end
	return entry
end
local function index(key: string): number?
	if type(key) ~= "string" then return nil end
	local number = tonumber(key)
	if number == 0 then
		return if key == "0" then 0 else nil
	end
	return if number
			and number >= 0
			and number < 4294967295
			and number % 1 == 0
			and string.format("%.0f", number) == key
		then number
		else nil
end
local function ordered(state: Ledger): { string }
	local numeric, other = {}, {}
	for _, entry in state.order do
		if type(entry.key) ~= "string" then continue
		elseif index(entry.key) ~= nil then
			table.insert(numeric, entry.key)
		else
			table.insert(other, entry.key)
		end
	end
	table.sort(numeric, function(a, b)
		return assert(tonumber(a)) < assert(tonumber(b))
	end)
	for _, key in other do
		table.insert(numeric, key)
	end
	return numeric
end
local function ownValue(record: any, key: string): any
	local position = if type(key) == "string" then index(key) else nil
	return if Arrays.owns(record) and position ~= nil then rawget(record, position + 1) else Records.readOwn(record, key, Records.receiver(record))
end
local recordMetatable = {
	__index = function(record: any, key: any): any
		local views = (getmetatable(record) :: any)[nativePropertiesToken]
		if views and views[key] ~= nil then return views[key] end
		if readHook then return (readHook :: any)(Records.receiver(record), key) end
		local name = normalize(key)
		if ledger(record).present[name] then return rawget(record, name) end
		local meta = getmetatable(record) :: any
		local prototype = meta[prototypeToken]
		return if prototype == nil or Nulls.isNull(prototype) then nil else prototype[name]
	end,
	__newindex = function(record: any, key: any, value: any)
		if writeHook then (writeHook :: any)(Records.receiver(record), key, value); return end
		local state = ledger(record)
		local normalized = normalize(key)
		assert(
			normalized ~= "__proto__" or state.present[normalized],
			"Prototype mutation is not a record data property"
		)
		-- A frozen/failed native write must not alter the property ledger.
		rawset(record, normalized, value)
		append(state, normalized)
	end,
}
function Records.descriptor(record: any, key: any): any
	local name = normalize(key)
	if not ledger(record).present[name] then return nil end
	local special = (getmetatable(record) :: any)[descriptorsToken]
	local frozen = table.isfrozen(record)
	if special and special[name] then
		if not frozen then return special[name] end
		local desc = table.clone(special[name])
		desc.configurable = false
		if desc.kind == "data" then desc.writable = false end
		return desc
	end
	return { kind = "data", value = rawget(record, name), writable = not frozen, enumerable = true, configurable = not frozen }
end
function Records.readOwn(record: any, key: any, receiver: any): any
	local desc = Records.descriptor(record, key)
	if not desc then return nil end
	if desc.kind == "data" then return desc.value end
	if desc.nativeGetter then return desc.get(receiver) end
	if rawequal(record, receiver) then receiver = Records.receiver(record) end
	return if desc.get == nil then nil else (assert(callHook, "Accessors require a source call boundary") :: any)(desc.get, receiver, Arrays.adopt({}, 0))
end
local function same(left: any, right: any): boolean
	if type(left) == "number" and type(right) == "number" then
		return if left ~= left then right ~= right elseif left == 0 and right == 0 then 1 / left == 1 / right else left == right
	end
	return rawequal(left, right)
end
function Records.defineDescriptor(record: any, key: any, desc: any): any
	local state, name = ledger(record), normalize(key)
	local old = Records.descriptor(record, name)
	if not old and not Records.extensible(record) then fault("Cannot add a property to a non-extensible object") end
	if old and not old.configurable then
		if desc.configurable or old.enumerable ~= desc.enumerable or old.kind ~= desc.kind then fault("Cannot redefine a non-configurable property") end
		if old.kind == "data" then
			if not old.writable and (desc.writable or not same(old.value, desc.value)) then fault("Cannot redefine a non-writable property") end
		elseif not same(old.get, desc.get) or not same(old.set, desc.set) then fault("Cannot redefine a non-configurable accessor") end
	end
	if table.isfrozen(record) then
		if not old or old.configurable or old.kind ~= desc.kind or desc.configurable then fault("Cannot define a property on a frozen record") end
		return record
	end
	local meta = privateMeta(record)
	local entries = meta[descriptorsToken]
	if not entries then entries = {}; meta[descriptorsToken] = entries end
	local views = meta[nativePropertiesToken]
	if desc.kind == "data" and desc.writable and desc.enumerable and desc.configurable and not (views and views[name] ~= nil) then
		entries[name] = nil
		rawset(record, name, desc.value)
	else
		rawset(record, name, nil)
		entries[name] = table.clone(desc)
	end
	append(state, name)
	return record
end
function Records.define(record: any, key: any, value: any): any
	Records.defineDescriptor(record, key, { kind = "data", value = value, writable = true, enumerable = true, configurable = true })
	return value
end
function Records.getPrototype(record: any): (boolean, any)
	ledger(record)
	local meta = getmetatable(record) :: any
	local prototype = rawget(meta, prototypeToken)
	return prototype ~= nil, prototype
end
function Records.setPrototype(record: any, prototype: any)
	ledger(record)
	local oldExplicit, old = Records.getPrototype(record)
	if oldExplicit and rawequal(old, prototype) then return end
	if not Records.extensible(record) then fault("Cannot change the prototype of a non-extensible object") end
	assert(type(prototype) == "table" or type(prototype) == "function", "A prototype must be an object or source null")
	local current, seen = prototype, {}
	while Records.owns(current) do
		assert(current ~= record and not seen[current], "Cyclic source prototype chain")
		seen[current] = true
		local explicit, parent = Records.getPrototype(current)
		if not explicit then break end
		current = parent
	end
	local meta: any = table.clone(getmetatable(record) :: any)
	meta[prototypeToken] = prototype
	setmetatable(record, meta)
end

function Records.begin(): Ledger
	local token = { order = {}, present = {} }
	constructions[token] = true
	return token
end
function Records.mark(token: Ledger, ...: any): any
	local state = construction(token)
	for position = 1, select("#", ...) do
		local rawKey = select(position, ...)
		local entry = append(state, normalize(rawKey))
		entry.captured, entry.value, entry.rawKey = false, nil, rawKey
		entry.getter = nil
	end
	return Empty
end
function Records.markMethod(token: Ledger, rawKey: any, _length: number?, _receiver: boolean?): any
	return Records.mark(token, rawKey)
end
function Records.key(token: Ledger, key: any): any
	local normalized = normalize(key)
	Records.mark(token, normalized)
	return normalized
end
function Records.keyMethod(token: Ledger, key: any, _length: number?, _receiver: boolean?): any
	return Records.key(token, key)
end
function Records.accessor(token: Ledger, key: any, getter: () -> any)
	local entry = append(construction(token), normalize(key))
	entry.captured, entry.value, entry.rawKey = true, nil, nil
	entry.getter = getter
end
function Records.spread(token: Ledger, source: any): any
	local state = construction(token)
	local snapshot = {}
	if
		source == nil
		or rawequal(source, Nulls.emptySpread)
		or Nulls.isNull(source)
		or type(source) == "boolean"
		or type(source) == "number"
	then
		return snapshot
	end
	assert(type(source) == "table", "Primitive string spreads need UTF-16 property values")
	for _, key in Records.keys(source) do
		local value = ownValue(source, key)
		local entry = append(state, key)
		entry.captured, entry.value, entry.rawKey = true, value, nil
		entry.getter = nil
		snapshot[key] = value
	end
	return snapshot
end
function Records.finish(token: Ledger, record: any): any
	local state = construction(token)
	assert(type(record) == "table" and getmetatable(record) == nil, "A record literal must be a fresh plain table")
	for _, entry in state.order do
		if not entry.captured then
			entry.value = rawget(record, entry.rawKey)
		end
	end
	table.clear(record)
	for _, entry in state.order do
		rawset(record, entry.key, entry.value)
		-- Metadata must not retain user values, including values pointing back
		-- at this record. Finished ledgers contain only keys and positions.
		entry.captured, entry.value, entry.rawKey = nil, nil, nil
	end
	constructions[token] = nil
	metadata[record] = state
	setmetatable(record, recordMetatable)
	for _, entry in state.order do
		local getter = entry.getter
		if getter then
			entry.getter = nil
			Records.defineDescriptor(record, entry.key, { kind = "accessor", get = getter, enumerable = true, configurable = true, nativeGetter = true })
		end
	end
	return record
end
function Records.adopt(record: any, keys: { any }): any
	assert(type(record) == "table" and getmetatable(record) == nil, "Only plain native records can be adopted")
	local state = Records.begin()
	for _, key in keys do
		local normalized = normalize(key)
		assert(not state.present[normalized], "Duplicate adopted record key")
		Records.mark(state, key)
	end
	local seen = {}
	for key in record do
		local normalized = normalize(key)
		local entry = state.present[normalized]
		assert(entry, "Adopted key order must cover every native property")
		assert(not seen[normalized], "Native properties collide after key normalization")
		seen[normalized] = true
		entry.rawKey = key
	end
	return Records.finish(state, record)
end
function Records.keys(record: any): { string }
	if Arrays.owns(record) then
		return Arrays.keys(record)
	end
	local result = {}
	for _, key in ordered(ledger(record)) do
		if Records.descriptor(record, key).enumerable then table.insert(result, key) end
	end
	return Arrays.adopt(result, #result)
end
function Records.ownKeys(record: any): any
	local result = ordered(ledger(record))
	for _, entry in ledger(record).order do
		if type(entry.key) ~= "string" then table.insert(result, entry.key) end
	end
	return Arrays.adopt(result, #result)
end
function Records.values(record: any): { any }
	local values = {}
	local keys = Records.keys(record)
	for position, key in keys do
		values[position] = ownValue(record, key)
	end
	return Arrays.adopt(values, #keys)
end
function Records.hasOwn(record: any, key: any): boolean
	if Arrays.owns(record) then
		local normalized = normalize(key)
		if normalized == "length" then
			return true
		end
		local position = index(normalized)
		return if position ~= nil then Arrays.has(record, position) else Arrays.hasProperty(record, normalized)
	end
	return ledger(record).present[normalize(key)] ~= nil
end
function Records.remove(record: any, key: any): boolean
	if Arrays.owns(record) then
		local normalized = normalize(key)
		assert(normalized ~= "length", "Array length is not configurable")
		local position = index(normalized)
		return if position ~= nil then Arrays.remove(record, position) else true
	end
	local state = ledger(record)
	local normalized = normalize(key)
	local entry = state.present[normalized]
	if entry then
		if not Records.descriptor(record, normalized).configurable then fault("Cannot delete a non-configurable property") end
		local special = (getmetatable(record) :: any)[descriptorsToken]
		if special then special[normalized] = nil end
		rawset(record, normalized, nil)
		state.present[normalized] = nil
		table.remove(state.order, entry.index)
		for position = entry.index, #state.order do
			state.order[position].index = position
		end
	end
	return true
end
function Records.rest(record: any, excluded: { any }): any
	local skip = {}
	for _, key in excluded do
		skip[normalize(key)] = true
	end
	local state, result = Records.begin(), {}
	for _, key in Records.keys(record) do
		if not skip[key] then
			Records.mark(state, key)
			result[key] = ownValue(record, key)
		end
	end
	return Records.finish(state, result)
end
function Records.copy(record: any): any
	return Records.rest(record, {})
end
function Records.enumerate(record: any): any
	local keys, cursor, owner = Records.keys(record), 0, record
	return {
		next = function(): { done: boolean, value: string? }
			if owner then
				while cursor < #keys do
					cursor += 1
					local key = keys[cursor]
					if Records.hasOwn(owner, key) then
						return { done = false, value = key }
					end
				end
				owner = nil
			end
			return { done = true }
		end,
	}
end

return Records
