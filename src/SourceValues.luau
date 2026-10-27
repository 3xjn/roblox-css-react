--!strict
-- Generic JavaScript primitive coercions, constructors and numeric operations.
local Arrays = require(script.Parent.Arrays)
local Nulls = require(script.Parent.Nulls)
local Collections = require(script.Parent.SourceCollections)
local Functions = require(script.Parent.FunctionValues)
local SourceType = require(script.Parent.SourceType)
local NumberStrings = require(script.Parent.NumberStrings)
local nan = 0 / 0
local function primitiveString(value: any): string
	if value == nil then
		return "undefined"
	end
	if Nulls.isNull(value) then
		return "null"
	end
	local kind = type(value)
	assert(
		kind == "string" or kind == "number" or kind == "boolean",
		"String conversion requires a primitive source value"
	)
	if kind == "number" then
		return NumberStrings.toString(value)
	end
	return tostring(value)
end
local function trimSpace(value: string, leadingOnly: boolean?): string
	local first: number? = nil
	local last = 0
	for index, code in utf8.codes(value) do
		local whitespace = (code >= 9 and code <= 13)
			or code == 32
			or code == 160
			or code == 5760
			or (code >= 8192 and code <= 8202)
			or code == 8232
			or code == 8233
			or code == 8239
			or code == 8287
			or code == 12288
			or code == 65279
		if not whitespace then
			first = first or index
			last = (utf8.offset(value, 2, index) or (#value + 1)) - 1
		end
	end
	return if first then string.sub(value, first, if leadingOnly then #value else last) else ""
end
local function primitiveNumber(value: any): number
	if value == nil then
		return nan
	end
	if Nulls.isNull(value) or value == false then
		return 0
	end
	if value == true then
		return 1
	end
	if type(value) == "number" then
		return value
	end
	assert(type(value) == "string", "Number conversion requires a primitive source value")
	local trimmed = trimSpace(value)
	if trimmed == "" then
		return 0
	end
	if trimmed == "Infinity" or trimmed == "+Infinity" then
		return math.huge
	end
	if trimmed == "-Infinity" then
		return -math.huge
	end
	if string.match(trimmed, "^0[xX][%da-fA-F]+$") then
		return tonumber(string.sub(trimmed, 3), 16) or nan
	end
	if string.match(trimmed, "^0[bB][01]+$") then
		return tonumber(string.sub(trimmed, 3), 2) or nan
	end
	if string.match(trimmed, "^0[oO][0-7]+$") then
		return tonumber(string.sub(trimmed, 3), 8) or nan
	end
	if
		string.match(trimmed, "^[+-]?%d+%.?%d*$")
		or string.match(trimmed, "^[+-]?%.%d+$")
		or string.match(trimmed, "^[+-]?%d+%.?%d*[eE][+-]?%d+$")
		or string.match(trimmed, "^[+-]?%.%d+[eE][+-]?%d+$")
	then
		return tonumber(trimmed) or nan
	end
	return nan
end
local function finite(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
local function integer(value: any): boolean
	return finite(value) and value % 1 == 0
end
local function parseInteger(value: any, radix: any?): number
	local text = trimSpace(primitiveString(value), true)
	local sign = 1
	local first = string.sub(text, 1, 1)
	if first == "+" or first == "-" then
		if first == "-" then
			sign = -1
		end
		text = string.sub(text, 2)
	end
	local base = if radix == nil then 0 else primitiveNumber(radix)
	if not finite(base) then
		base = 0
	end
	base = (if base < 0 then math.ceil(base) else math.floor(base)) % 4294967296
	if base >= 2147483648 then
		base -= 4294967296
	end
	if base ~= 0 and (base < 2 or base > 36) then
		return nan
	end
	local hex = string.sub(text, 1, 2):lower() == "0x"
	if base == 0 then
		base = if hex then 16 else 10
	end
	if base == 16 and hex then
		text = string.sub(text, 3)
	end
	local limbs: { number } = { 0 }
	local count = 0
	local overflow = false
	for index = 1, #text do
		local byte = string.byte(text, index)
		local digit = if byte >= 48 and byte <= 57
			then byte - 48
			elseif byte >= 65 and byte <= 90 then byte - 55
			elseif byte >= 97 and byte <= 122 then byte - 87
			else 36
		if digit >= base then
			break
		end
		if not overflow then
			local carry = digit
			for limb = 1, #limbs do
				local nextValue = limbs[limb] * base + carry
				limbs[limb] = nextValue % 16777216
				carry = math.floor(nextValue / 16777216)
			end
			if carry > 0 then
				table.insert(limbs, carry)
			end
			overflow = #limbs > 43
		end
		count += 1
	end
	if count == 0 then
		return nan
	end
	if overflow then
		return sign * math.huge
	end
	local top = limbs[#limbs]
	local topBits = 0
	while top > 0 do
		topBits += 1
		top = math.floor(top / 2)
	end
	local bits = (#limbs - 1) * 24 + topBits
	if bits > 1024 then
		return sign * math.huge
	end
	local function bitAt(index: number): number
		return math.floor(limbs[math.floor(index / 24) + 1] / 2 ^ (index % 24)) % 2
	end
	local shift = math.max(0, bits - 53)
	local significant = 0
	for index = bits - 1, shift, -1 do
		significant = significant * 2 + bitAt(index)
	end
	if shift > 0 and bitAt(shift - 1) == 1 then
		local sticky = false
		for index = 0, shift - 2 do
			if bitAt(index) == 1 then
				sticky = true
				break
			end
		end
		if sticky or significant % 2 == 1 then
			significant += 1
		end
	end
	return sign * significant * 2 ^ shift
end
local numbers = table.freeze(setmetatable({
	parseInt = parseInteger,
	isFinite = finite,
	isInteger = integer,
	isNaN = function(value: any): boolean
		return type(value) == "number" and value ~= value
	end,
	isSafeInteger = function(value: any): boolean
		return integer(value) and math.abs(value) <= 9007199254740991
	end,
	parseFloat = function(value: string): number
		local trimmed = trimSpace(value, true)
		if string.sub(trimmed, 1, 8) == "Infinity" or string.sub(trimmed, 1, 9) == "+Infinity" then
			return math.huge
		end
		if string.sub(trimmed, 1, 9) == "-Infinity" then
			return -math.huge
		end
		local prefix = string.match(trimmed, "^[+-]?%d+%.?%d*[eE][+-]?%d+")
			or string.match(trimmed, "^[+-]?%.%d+[eE][+-]?%d+")
			or string.match(trimmed, "^[+-]?%d+%.?%d*")
			or string.match(trimmed, "^[+-]?%.%d+")
		return if prefix then tonumber(prefix) or nan else nan
	end,
	EPSILON = 2 ^ -52,
	MAX_VALUE = 1.7976931348623157e308,
	MIN_VALUE = 5e-324,
	MAX_SAFE_INTEGER = 9007199254740991,
	MIN_SAFE_INTEGER = -9007199254740991,
	NaN = nan,
	POSITIVE_INFINITY = math.huge,
	NEGATIVE_INFINITY = -math.huge,
}, {
	__call = function(_self: any, ...: any): number
		return if select("#", ...) == 0 then 0 else primitiveNumber((...))
	end,
}))
local function extreme(largest: boolean, ...: number): number
	local result = if largest then -math.huge else math.huge
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if value ~= value then
			return nan
		end
		if result == 0 and value == 0 then
			if (largest and 1 / value == math.huge) or (not largest and 1 / value == -math.huge) then
				result = value
			end
		else
			result = if largest then math.max(result, value) else math.min(result, value)
		end
	end
	return result
end
local maths = table.freeze({
	abs = math.abs,
	ceil = math.ceil,
	floor = math.floor,
	sqrt = math.sqrt,
	round = function(value: number): number
		if not finite(value) or value % 1 == 0 then
			return value
		end
		if value < 0 and value >= -0.5 then
			return -0.0
		end
		local lower = math.floor(value)
		return if value - lower < 0.5 then lower else lower + 1
	end,
	trunc = function(value: number): number
		return if value < 0 then math.ceil(value) else math.floor(value)
	end,
	sign = function(value: number): number
		return if value == 0 or value ~= value then value elseif value < 0 then -1 else 1
	end,
	min = function(...: number): number
		return extreme(false, ...)
	end,
	max = function(...: number): number
		return extreme(true, ...)
	end,
	random = math.random,
	PI = math.pi,
	E = math.exp(1),
})
local function constructArray(...: any): any
	local count = select("#", ...)
	if count == 1 and type((...)) == "number" then
		return Arrays.adopt({}, (...), {})
	end
	return Arrays.adopt({ ... }, count)
end
local arrayValues = table.freeze(setmetatable({
	new = constructArray,
	isArray = Arrays.owns,
	from = function(value: any, map: ((any, number) -> any)?): any
		local callMap = if map then function(item: any, idx: number): any
			if type(map) == "function" and not Functions.isSource(map) then
				local paramCount, isVararg = debug.info(map, "a")
				local okLen, declaredLen = pcall(Functions.length, map)
				if not isVararg and (paramCount >= 3 or (okLen and paramCount == declaredLen + 1)) then
					return (map :: any)(nil, item, idx)
				end
			end
			return map(item, idx)
		end else nil
		if type(value) == "table" and not Arrays.owns(value) and not Collections.kind(value) and type(value.next) ~= "function" and type(value.length) == "number" then
			local len = math.max(0, math.floor(value.length))
			local result = Arrays.adopt({}, 0)
			for i = 0, len - 1 do
				local item = value[tostring(i)]
				if item == nil then item = value[i + 1] end
				Arrays.push(result, if callMap then callMap(item, i) else item)
			end
			return result
		end
		local iterator = Collections.iterator(value)
		local result = Arrays.adopt({}, 0)
		local i = 0
		while true do
			local step = iterator.next(iterator)
			if step.done then
				break
			end
			Arrays.push(result, if callMap then callMap(step.value, i) else step.value)
			i += 1
		end
		return result
	end,
}, {
	__call = function(_self, ...: any): any
		return constructArray(...)
	end,
}))


SourceType.register(arrayValues, "function")
SourceType.register(numbers, "function")
return table.freeze({ Array = arrayValues, Number = numbers, Math = maths, Boolean = Nulls.truthy, NaN = nan, Infinity = math.huge, parseFloat = numbers.parseFloat, parseInt = parseInteger, String = function(...: any): string return if select('#', ...) == 0 then '' else primitiveString((...)) end })
