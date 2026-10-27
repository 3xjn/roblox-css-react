--!strict
local FunctionValues = {}
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local Records = require(script.Parent.Records)
local Properties = require(script.Parent.Properties)
local SourceType = require(script.Parent.SourceType)
type Entry = { name: string?, displayName: string?, length: number?, receiver: boolean?, properties: any, sourceStore: any? }
local metadata: { [any]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local dispatchers: { [any]: (any, any) -> any } = setmetatable({}, { __mode = "kv" }) :: any
function FunctionValues.isSource(value: any): boolean return dispatchers[value] ~= nil end
local function properties(current: Entry): any
	return if current.sourceStore then assert(current.sourceStore.value, "Source callable property ownership was released") else current.properties
end
local function entry(value: any): Entry
	assert(type(value) == "function" or metadata[value] ~= nil, "Callable tables need explicit FunctionValues.callable registration")
	local current = metadata[value]
	if not current then
		local created: Entry = { properties = Records.adopt({}, {}) }
		metadata[value] = created
		Properties.register(value, function(key: any): boolean
			return key == "name" or key == "length" or Records.hasOwn(properties(created), key)
		end)
		return created
	end
	return current
end
-- An explicit callable-table gateway. Its owner must retain the store and
-- dispatcher; both registry edges remain weak to avoid self-rooting classes.
function FunctionValues.callable(value: any, store: any, dispatch: (any, any) -> any)
	assert(type(value) == "table" and SourceType.typeOf(value) == "function" and not metadata[value], "Invalid callable table metadata registration")
	assert(Records.owns(store), "Callable properties require an adopted descriptor store")
	metadata[value] = { sourceStore = setmetatable({ value = store }, { __mode = "v" }), properties = nil, receiver = false }
	dispatchers[value] = dispatch
end
-- The actual native closure retains its dispatch and property store. Weak
-- metadata must not root a recursive source closure through its own callback.
function FunctionValues.source(value: any, dispatch: (any, any) -> any, store: any)
	local current = entry(value)
	assert(Records.owns(store), "Source function properties require an adopted record")
	current.sourceStore = setmetatable({ value = store }, { __mode = "v" })
	current.properties = nil
	dispatchers[value] = dispatch
end
function FunctionValues.native(value: any, receiver: boolean, name: string?, length: number?): any
	local current = entry(value)
	assert(current.receiver == nil or current.receiver == receiver, "Conflicting native callable receiver ABI")
	current.receiver = receiver
	if name then current.name = name end
	if length then current.length = length end
	return value
end
function FunctionValues.named(value: any, name: string, length: number?, receiver: boolean?): any
	assert(type(name) == "string", "Function names require strings")
	local current = entry(value)
	current.name = name
	if length ~= nil then
		assert(length >= 0 and length % 1 == 0, "Source function length requires a non-negative integer")
		current.length = length
	end
	if receiver ~= nil then
		current.receiver = receiver
	end
	return value
end
function FunctionValues.length(value: any): number
	local current = entry(value)
	if current.sourceStore then return properties(current).length end
	assert(current.length ~= nil, "Function.length requires registered source arity, not native debug arity")
	return current.length :: number
end
function FunctionValues.name(value: any): string
	local current = metadata[value]
	if current and current.sourceStore then return properties(current).name end
	assert(type(value) == "function", "Callable table names require explicit metadata")
	return if current and current.name then current.name else debug.info(value :: (...any) -> ...any, "n")
end
function FunctionValues.displayName(value: any): string?
	entry(value)
	local current = metadata[value]
	if current and current.sourceStore then return properties(current).displayName end
	return if current then current.displayName else nil
end
function FunctionValues.setDisplayName(value: any, name: string?): string?
	assert(name == nil or type(name) == "string", "Display names require strings or nil")
	local current = entry(value)
	current.displayName = name
	properties(current).displayName = name
	return name
end
function FunctionValues.getProperty(value: any, key: any): any
	local name = Records.propertyKey(key)
	local current = entry(value)
	if current.sourceStore then return properties(current)[name] end
	if name == "name" then return FunctionValues.name(value) end
	if name == "length" then return FunctionValues.length(value) end
	if name == "displayName" then return FunctionValues.displayName(value) end
	return properties(entry(value))[name]
end
function FunctionValues.setProperty(value: any, key: any, item: any): any
	local name = Records.propertyKey(key)
	local source = entry(value)
	if source.sourceStore then properties(source)[name] = item; return item end
	assert(name ~= "name" and name ~= "length", "Cannot assign to read-only source function metadata")
	assert(name ~= "prototype" and name ~= "caller" and name ~= "arguments", "Function prototype/introspection needs an explicit capability")
	local current = entry(value)
	properties(current)[name] = item
	if name == "displayName" then current.displayName = item end
	return item
end
function FunctionValues.keys(value: any): any return Records.keys(properties(entry(value))) end
function FunctionValues.ownKeys(value: any): any return Records.ownKeys(properties(entry(value))) end
function FunctionValues.hasOwn(value: any, key: any): boolean
	local name = Records.propertyKey(key)
	local current = entry(value)
	if current.sourceStore then return Records.hasOwn(properties(current), name) end
	return name == "name" or name == "length" or Records.hasOwn(properties(entry(value)), name)
end
function FunctionValues.removeProperty(value: any, key: any): boolean
	local name = Records.propertyKey(key)
	local source = entry(value)
	if source.sourceStore then return Records.remove(properties(source), name) end
	assert(name ~= "name" and name ~= "length", "Source function metadata deletion is unsupported")
	local current = entry(value)
	if name == "displayName" then current.displayName = nil end
	return Records.remove(properties(current), name)
end
function FunctionValues.invoke(value: any, ...: any): any
	return value(...)
end

-- Preserve the receiver while capturing a native method before its arguments
-- are evaluated. Indexing also respects a native class's method lookup.
function FunctionValues.readMethod(owner: any, key: any): any
	return owner[key]
end

function FunctionValues.reference(owner: any, read: (any) -> any, mode: string, optionalOwner: boolean): any
	if optionalOwner and Nulls.isNullish(owner) then
		return nil
	end
	return { owner = owner, value = read(owner), mode = mode }
end

local function invokeReference(
	reference: any,
	arguments: () -> any,
	optionalCallee: boolean,
	count: number?,
	checked: boolean
): any
	if reference == nil then
		return nil
	end
	local callback = reference.value
	if optionalCallee and Nulls.isNullish(callback) then
		return nil
	end
	-- Ordinary calls evaluate arguments even when the resulting target is not
	-- callable. Only an optional short circuit skips argument evaluation.
	local packet = arguments()
	local current = metadata[callback]
	assert(type(callback) == "function" or current and dispatchers[callback], "Source call target is not callable")
	if checked and reference.owner ~= nil then
		assert(current and current.receiver ~= nil, "Dynamic call requires registered source callable ABI")
	end
	local receiver = if current and current.receiver ~= nil then current.receiver else reference.mode == "method"
	local length = if count ~= nil then count elseif Arrays.owns(packet) then #packet else nil
	assert(length ~= nil, "Source invocation needs an adopted argument array or explicit argument count")
	local dispatch = dispatchers[callback]
	if dispatch then
		assert(Arrays.owns(packet), "Source dispatch requires an adopted logical argument array")
		return dispatch(reference.owner, packet)
	end
	if receiver then
		return (callback :: any)(reference.owner, table.unpack(packet, 1, length :: number))
	end
	return (callback :: any)(table.unpack(packet, 1, length :: number))
end
function FunctionValues.invokeReference(
	reference: any,
	arguments: () -> any,
	optionalCallee: boolean,
	count: number?
): any
	return invokeReference(reference, arguments, optionalCallee, count, false)
end
function FunctionValues.invokeChecked(
	reference: any,
	arguments: () -> any,
	optionalCallee: boolean,
	count: number?
): any
	return invokeReference(reference, arguments, optionalCallee, count, true)
end
return FunctionValues
