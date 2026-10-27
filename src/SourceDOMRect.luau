--!strict
-- A small DOMRect/DOMRectReadOnly value model for source code that needs
-- geometry dictionaries. Numeric inputs are primitive numbers; WebIDL object,
-- string, boolean, and null coercion belongs to a separate conversion provider.
local Errors = require(script.Parent.SourceErrors)
local Functions = require(script.Parent.FunctionValues)
local Records = require(script.Parent.Records)
local Operations = require(script.Parent.SourceOperations)

local SourceDOMRect = {}
type Values = { x: number, y: number, width: number, height: number }
type Kind = "readonly" | "mutable"
local valuesByObject: { [any]: Values } = setmetatable({}, { __mode = "k" }) :: any
local kindByObject: { [any]: Kind } = setmetatable({}, { __mode = "k" }) :: any
local rectPrototype = Operations.object()
local rectSchema: Operations.NativeObject = {
	tag = "DOMRect",
	hasOwn = function(owner: any, key: any): boolean return rawget(owner, key) ~= nil end,
	get = function(owner: any, key: any): any return rawget(owner, key) end,
	ownKeys = function(owner: any): any local keys = {}; for key in owner do table.insert(keys, key) end; return keys end,
	enumerable = function(): boolean return true end,
	prototype = function(): any return rectPrototype end,
	set = function(owner: any, key: any, value: any) owner[key] = value end,
}
for _, key in { "x", "y", "width", "height", "top", "right", "bottom", "left" } do
	Operations.defineAccessor(rectPrototype, key, Operations.registerNative(function(owner: any): any return owner[key] end, "method", "get " .. key, 0),
		if key == "x" or key == "y" or key == "width" or key == "height" then Operations.registerNative(function(owner: any, value: any) owner[key] = value end, "method", "set " .. key, 1) else nil, true, true)
end

local function requireReceiver(value: any): Values
	local values = valuesByObject[value]
	if not values then
		error(Errors.TypeError("DOMRect method called with an incompatible receiver"), 3)
	end
	return values
end

local function checkNumber(value: any, name: string): number
	if type(value) ~= "number" then
		error(Errors.TypeError("DOMRect " .. name .. " must be a primitive number"), 3)
	end
	return value
end

local function numberOrDefault(value: any, name: string): number
	return if value == nil then 0 else checkNumber(value, name)
end

local function nanSafeMin(a: number, b: number): number
	if a ~= a or b ~= b then
		return 0 / 0
	end
	if a < b then
		return a
	end
	if b < a then
		return b
	end
	if a == 0 then
		-- ECMAScript Math.min preserves -0 if either equal zero is negative.
		return if 1 / a == -math.huge or 1 / b == -math.huge then -1 / math.huge else 0
	end
	return a
end

local function nanSafeMax(a: number, b: number): number
	if a ~= a or b ~= b then
		return 0 / 0
	end
	if a > b then
		return a
	end
	if b > a then
		return b
	end
	if a == 0 then
		-- ECMAScript Math.max preserves +0 if either equal zero is positive.
		return if 1 / a == math.huge or 1 / b == math.huge then 0 else -1 / math.huge
	end
	return a
end

local function toJSON(self: any): { [string]: number }
	local values = requireReceiver(self)
	local result = {
		x = values.x,
		y = values.y,
		width = values.width,
		height = values.height,
		top = nanSafeMin(values.y, values.y + values.height),
		right = nanSafeMax(values.x, values.x + values.width),
		bottom = nanSafeMax(values.y, values.y + values.height),
		left = nanSafeMin(values.x, values.x + values.width),
	}
	return Records.adopt(result, { "x", "y", "width", "height", "top", "right", "bottom", "left" })
end
Functions.named(toJSON, "toJSON", 0, true)
Operations.defineDataProperty(rectPrototype, "toJSON", Operations.registerNative(toJSON, "method", "toJSON", 0), true, true, true)

local readonlyConstructor: any
local mutableConstructor: any
local function staticArgument(first: any?, second: any?): any?
	if first == readonlyConstructor or first == mutableConstructor then
		return second
	end
	return first
end

local function new(kind: Kind, x: any?, y: any?, width: any?, height: any?): any
	local object = setmetatable(
		{},
		table.freeze({
			__index = function(self: any, key: any): any
				local values = requireReceiver(self)
				if key == "x" then
					return values.x
				end
				if key == "y" then
					return values.y
				end
				if key == "width" then
					return values.width
				end
				if key == "height" then
					return values.height
				end
				if key == "left" then
					return nanSafeMin(values.x, values.x + values.width)
				end
				if key == "right" then
					return nanSafeMax(values.x, values.x + values.width)
				end
				if key == "top" then
					return nanSafeMin(values.y, values.y + values.height)
				end
				if key == "bottom" then
					return nanSafeMax(values.y, values.y + values.height)
				end
				if key == "toJSON" then
					return toJSON
				end
				return nil
			end,
			__newindex = function(self, key, value)
				local values = requireReceiver(self)
				if key == "x" or key == "y" or key == "width" or key == "height" then
					if kind ~= "mutable" then
						error(Errors.TypeError("Cannot assign to read-only DOMRect property " .. key), 2)
					end
					local number = checkNumber(value, key)
					if key == "x" then
						values.x = number
					elseif key == "y" then
						values.y = number
					elseif key == "width" then
						values.width = number
					else
						values.height = number
					end
					return
				end
				if key == "left" or key == "right" or key == "top" or key == "bottom" then
					error(Errors.TypeError("Cannot assign to read-only DOMRect property " .. key), 2)
				end
				rawset(self, key, value)
			end,
			__has = function(self, key)
				return valuesByObject[self] ~= nil
					and (
						key == "x"
						or key == "y"
						or key == "width"
						or key == "height"
						or key == "top"
						or key == "right"
						or key == "bottom"
						or key == "left"
						or key == "toJSON"
					)
			end,
		})
	)
	valuesByObject[object] = {
		x = numberOrDefault(x, "x"),
		y = numberOrDefault(y, "y"),
		width = numberOrDefault(width, "width"),
		height = numberOrDefault(height, "height"),
	}
	kindByObject[object] = kind
	Operations.registerObject(object, rectSchema)
	return object
end

local function fromRect(kind: Kind, other: any?): any
	if other == nil then
		other = {}
	end
	if type(other) ~= "table" then
		error(Errors.TypeError("DOMRect.fromRect requires a dictionary object"), 2)
	end
	-- Web IDL converts members in lexicographical order. Validate each converted
	-- primitive before the next getter is observed so failures preserve ordering.
	local height = numberOrDefault(other.height, "height")
	local width = numberOrDefault(other.width, "width")
	local x = numberOrDefault(other.x, "x")
	local y = numberOrDefault(other.y, "y")
	return new(kind, x, y, width, height)
end

readonlyConstructor = {
	new = function(x: any?, y: any?, width: any?, height: any?)
		return new("readonly", x, y, width, height)
	end,
	fromRect = function(first: any?, second: any?)
		return fromRect("readonly", staticArgument(first, second))
	end,
	instanceof = function(first: any?, second: any?): boolean
		return valuesByObject[staticArgument(first, second)] ~= nil
	end,
}
mutableConstructor = {
	new = function(x: any?, y: any?, width: any?, height: any?)
		return new("mutable", x, y, width, height)
	end,
	fromRect = function(first: any?, second: any?)
		return fromRect("mutable", staticArgument(first, second))
	end,
	instanceof = function(first: any?, second: any?): boolean
		return kindByObject[staticArgument(first, second)] == "mutable"
	end,
}

SourceDOMRect.DOMRectReadOnly = readonlyConstructor
SourceDOMRect.DOMRect = mutableConstructor
return SourceDOMRect
