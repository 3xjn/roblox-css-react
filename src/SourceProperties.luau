--!strict
-- Property existence is separate from value reads: `in` must never invoke a
-- getter. Native objects with functional __index expose an explicit __has.
local Arrays = require(script.Parent.Arrays)
local Records = require(script.Parent.Records)
local Nulls = require(script.Parent.Nulls)
local Functions = require(script.Parent.FunctionValues)
local Strings = require(script.Parent.Strings)
local Numbers = require(script.Parent.SourceNumbers)
local Errors = require(script.Parent.SourceErrors)
local SourceProperties = {}
local declared: { [any]: { [any]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

function SourceProperties.register(value: any, keys: { any }): any
	assert(type(value) == "table" or type(value) == "function", "Property schema requires an object")
	local schema = declared[value]
	if not schema then
		schema = {}
		declared[value] = schema
	end
	for _, key in keys do
		schema[key] = true
	end
	return value
end

function SourceProperties.has(key: any, value: any): boolean
	assert(not Nulls.isNullish(value), "The in operator requires an object")
	if type(key) == "number" then
		key = Records.keyString(key)
	end
	assert(type(key) == "string" or type(key) == "table", "Property keys require strings or native symbols")
	local seen: { [any]: boolean } = {}
	local function visit(target: any): boolean
		if seen[target] then
			return false
		end
		seen[target] = true
		local schema = declared[target]
		if schema and schema[key] then
			return true
		end
		if typeof(target) == "Instance" then
			local ok = pcall(function()
				return (target :: any)[key]
			end)
			return ok
		end
		if type(target) == "function" then
			-- Native source functions always carry these standard own fields.
			if key == "name" or key == "length" then
				return true
			end
			error("Function property existence requires its source metadata schema", 2)
		end
		assert(type(target) == "table", "The in operator requires an object")
		if Arrays.owns(target) then
			if key == "length" then
				return true
			end
			local index = if type(key) == "string" then tonumber(key) else nil
			if index and index >= 0 and index % 1 == 0 and tostring(index) == key then
				return Arrays.has(target, index)
			end
		end
		if Records.owns(target) and Records.hasOwn(target, key) then
			return true
		end
		if rawget(target, key) ~= nil then
			return true
		end
		local meta = getmetatable(target)
		if type(meta) ~= "table" then
			return false
		end
		local has = rawget(meta, "__has")
		if type(has) == "function" then
			return (has :: (any, any) -> boolean)(target, key)
		end
		local parent = rawget(meta, "__index")
		if type(parent) == "table" then
			return visit(parent)
		end
		assert(parent == nil, "Functional native property lookup needs an explicit __has schema")
		return false
	end
	return visit(value)
end

function SourceProperties.hasOwn(key: any, value: any): boolean
	assert(not Nulls.isNullish(value), "hasOwnProperty requires an object-coercible receiver")
	if type(key) == "number" then
		key = Records.keyString(key)
	end
	local schema = declared[value]
	if schema and schema[key] then
		return true
	end
	if type(value) == "table" then
		if Records.owns(value) or Arrays.owns(value) then
			return Records.hasOwn(value, key)
		end
		return rawget(value, key) ~= nil
	end
	if type(value) == "string" then
		if key == "length" then
			return true
		end
		local index = if type(key) == "string" then tonumber(key) else nil
		if not index or index < 0 or index % 1 ~= 0 or tostring(index) ~= key then
			return false
		end
		local length = 0
		for _, codepoint in utf8.codes(value) do
			length += if codepoint > 0xFFFF then 2 else 1
		end
		return index < length
	end
	if type(value) == "number" or type(value) == "boolean" then
		return false
	end
	if type(value) == "function" then
		if key == "name" or key == "length" then
			return true
		end
		error("Function own-property reflection requires a declared metadata schema", 2)
	end
	error("Native own-property reflection requires a declared source schema", 2)
end

local function prototypeHasOwn(self: any, key: any): boolean
	return SourceProperties.hasOwn(key, self)
end
Functions.named(prototypeHasOwn, "hasOwnProperty", 1, true)

function SourceProperties.hasOwnMethod(value: any): any
	assert(not Nulls.isNullish(value), "Cannot read hasOwnProperty from null or undefined")
	if type(value) == "table" and SourceProperties.has("hasOwnProperty", value) then
		return value.hasOwnProperty
	end
	return prototypeHasOwn
end

local arrayMethods: { [string]: number } = {
	map = 1, filter = 1, forEach = 1, some = 1, every = 1, find = 1, findIndex = 1,
	slice = 2, push = 1, pop = 0, shift = 0, unshift = 1, splice = 2, includes = 1,
	indexOf = 1, lastIndexOf = 1, flatMap = 1, concat = 1, reduce = 1, sort = 1, fill = 1,
	join = 1, at = 1,
}
local stringMethods: { [string]: number } = { startsWith = 1, includes = 1, endsWith = 1, slice = 2, charCodeAt = 1 }
local arrayPrototypes: { [string]: any } = {}
local stringPrototypes: { [string]: any } = {}
local numberToString = Functions.named(function(self: any, radix: number?): string
	assert(type(self) == "number", "Number.toString requires a number")
	return Numbers.toString(self, radix)
end, "toString", 1, true)
local booleanToString = Functions.named(function(self: any): string
	assert(type(self) == "boolean", "Boolean.toString requires a boolean")
	return if self then "true" else "false"
end, "toString", 0, true)
local function indexKey(key: any): number?
	if type(key) ~= "string" then return nil end
	local index = tonumber(key)
	return if index and index >= 0 and index < 4294967295 and index % 1 == 0 and Records.keyString(index) == key then index else nil
end

function SourceProperties.get(value: any, key: any): any
	if Nulls.isNullish(value) then error(Errors.TypeError.new("Cannot read properties of null or undefined"), 0) end
	if type(key) == "number" then key = Records.keyString(key) end
	assert(type(key) == "string" or type(key) == "table", "Property keys require strings or native symbols")
	local kind = type(value)
	if kind == "table" then
		if Arrays.owns(value) then
			if key == "length" then return Arrays.length(value) end
			local index = indexKey(key)
			if index then return rawget(value, index + 1) end
			if Arrays.isArray(value) and arrayMethods[key] ~= nil then
				local method = arrayPrototypes[key]
				if not method then
					method = Functions.named(function(self: any, ...: any): any
						return (Arrays :: any)[key](self, ...)
					end, key, arrayMethods[key], true)
					arrayPrototypes[key] = method
				end
				return method
			end
		end
		if key == "hasOwnProperty" then return SourceProperties.hasOwnMethod(value) end
		return value[key]
	elseif kind == "string" then
		if key == "length" then
			local length = 0
			for _, point in utf8.codes(value) do length += if point > 0xFFFF then 2 else 1 end
			return length
		end
		local index = indexKey(key)
		if index then
			local result = Strings.slice(value, index, index + 1)
			return if result == "" then nil else result
		end
		if stringMethods[key] ~= nil then
			local method = stringPrototypes[key]
			if not method then
				method = Functions.named(function(self: any, ...: any): any
					return (Strings :: any)[key](self, ...)
				end, key, stringMethods[key], true)
				stringPrototypes[key] = method
			end
			return method
		end
	elseif kind == "function" then
		if key == "name" then return Functions.name(value) end
		if key == "length" then return Functions.length(value) end
		if key == "displayName" then return Functions.displayName(value) end
	elseif kind == "number" then
		if key == "toString" then return numberToString end
	elseif kind == "boolean" then
		if key == "toString" then return booleanToString end
	elseif typeof(value) == "Instance" then
		return (value :: any)[key]
	else
		error("Native property lookup requires an object or supported primitive", 2)
	end
	if key == "hasOwnProperty" then return prototypeHasOwn end
	return nil
end

return SourceProperties
