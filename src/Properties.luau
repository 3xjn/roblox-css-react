--!strict
local Records = require(script.Parent.Records)
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local Properties = {}
local resolvers: { [any]: (any) -> boolean } = setmetatable({}, { __mode = "k" })
local objectPrototype = {
	constructor = true,
	__defineGetter__ = true,
	__defineSetter__ = true,
	hasOwnProperty = true,
	__lookupGetter__ = true,
	__lookupSetter__ = true,
	isPrototypeOf = true,
	propertyIsEnumerable = true,
	toString = true,
	valueOf = true,
	__proto__ = true,
	toLocaleString = true,
}
local function refProperty(key: any): boolean
	return key == "current" or objectPrototype[key] == true
end
function Properties.ref(receiver: any): any
	assert(type(receiver) == "table", "Native React refs must be objects")
	assert(
		resolvers[receiver] == nil or resolvers[receiver] == refProperty,
		"Native ref property resolver is already owned"
	)
	resolvers[receiver] = refProperty
	return receiver
end
function Properties.register(receiver: any, resolver: (any) -> boolean): () -> ()
	assert(
		(type(receiver) == "table" or type(receiver) == "function" or type(receiver) == "userdata")
			and not Nulls.isNull(receiver)
			and not resolvers[receiver],
		"Native property resolver already owned or invalid"
	)
	resolvers[receiver] = resolver
	return function()
		if resolvers[receiver] == resolver then
			resolvers[receiver] = nil
		end
	end
end
function Properties.has(key: any, receiver: any): boolean
	assert(
		(type(receiver) == "table" or type(receiver) == "function" or type(receiver) == "userdata")
			and not Nulls.isNull(receiver),
		"The right side of in must be an object"
	)
	local name = Records.propertyKey(key)
	if resolvers[receiver] then
		return resolvers[receiver](name)
	end
	assert(type(receiver) == "table", "Opaque native property lookup requires an explicit resolver")
	local current, seen = receiver, {}
	while current ~= nil and not Nulls.isNull(current) do
		assert(not seen[current], "Cyclic native property lookup requires an explicit resolver")
		seen[current] = true
		local resolver = resolvers[current]
		if resolver then
			return resolver(name)
		end
		if Arrays.owns(current) then
			if name == "length" or Records.hasOwn(current, key) then
				return true
			end
		elseif Records.owns(current) then
			if Records.hasOwn(current, name) or rawget(current, name) ~= nil then
				return true
			end
			local explicit, parent = Records.getPrototype(current)
			if explicit then
				current = parent
				continue
			end
			return objectPrototype[name] == true
		elseif rawget(current, name) ~= nil then
			return true
		end
		local metatable = getmetatable(current)
		if metatable == nil then
			return false
		end
		assert(type(metatable) == "table", "Protected native property lookup requires an explicit resolver")
		local inherited = rawget(metatable, "__index")
		assert(
			inherited == nil or type(inherited) == "table",
			"Native function-based property lookup requires an explicit resolver"
		)
		current = inherited
	end
	return false
end
return Properties
